# RawNotesPull

**Grain:** One row per clinical note per encounter (`NOTE_ID`)
**Role in Data Model:** Notes fact table — joins to FACT_ENCOUNTER via CSN
**Source Query:** `SQL/RawNotesPull.sql`

---

## Purpose

Produces one record per clinical note for encounters within the configured date range. Captures note metadata including type, source, timing, length, voice recognition usage, and attribution by source type (ambient AI, manual, SmartText, etc.). This is the primary table for measuring note authoring behavior and Abridge's contribution to note content.

---

## Key Tables

| Table | Description | Dictionary Page |
|---|---|---|
| `HNO_INFO` | Clinical note header record; PK: NOTE_ID; Chronicles INI: HNO | p.29 |
| `PAT_ENC` | Encounter table; used to confirm encounter membership | p.5 |
| `ZC_NOTE_TYPE` | Note type code/name lookup | — |
| `ZC_NOTE_SOURCE` | Note source code/name lookup | — |
| `NOTE_WRITE_TIMING` | Editing session timing per note; PK: NOTE_ID + LINE; Rel 2017 | p.204 |
| `V_NOTE_CHARACTERISTICS` | View with note length, attribution sums, voice recognition; PK: NOTE_ID; Rel 2015 | p.157 |
| `NOTE_ATTRIBUTION` | Character-level attribution by source per note; PK: NOTE_ID + LINE | p.45 |
| `SER_MAP` | IntraConnect provider CID mapping | — |
| `ZC_NOTEATTR_SOURCE` | Attribution source code/name lookup | — |

---

## Output Columns

| Column | Source | Notes |
|---|---|---|
| NOTE_ID | HNO_INFO | Primary key; unique note identifier |
| PAT_ENC_CSN_ID | HNO_INFO | Encounter join key |
| AMBIENT_FLAG | Derived | 'Y' / 'N' |
| note_type_code | HNO_INFO | Note type category code |
| note_type_name | ZC_NOTE_TYPE | Note type name |
| note_source_code | HNO_INFO | Note source category code |
| note_source_name | ZC_NOTE_SOURCE | Note source name |
| ENTRY_USER_ID | HNO_INFO | User who created/entered the note |
| ENTRY_DATETIME | HNO_INFO | Datetime the note was entered |
| LENGTH_OF_EDIT | NOTE_WRITE_TIMING | Seconds spent in a given editing session |
| WRITE_USER_ID | NOTE_WRITE_TIMING | User for the given editing session |
| AUTHOR_SUM | V_NOTE_CHARACTERISTICS | Characters entered by the author of the note |
| TOTAL_NOTE_LENGTH | V_NOTE_CHARACTERISTICS | Total character count of the note |
| NOTE_FILE_DTTM | V_NOTE_CHARACTERISTICS | Last date/time note content was modified |
| DATE_OF_SERVICE_DTTM | V_NOTE_CHARACTERISTICS | Date of service from the note |
| AUTHOR_LINKED_PROV_ID | V_NOTE_CHARACTERISTICS | Provider linked to the note author |
| author_linked_prov_cid | SER_MAP | IntraConnect CID for the linked provider |
| AUTHOR_LOGIN_DEPARTMENT_ID | V_NOTE_CHARACTERISTICS | Department where the author was logged in |
| AUTHOR_LOGIN_DEPARTMENT_NAME | V_NOTE_CHARACTERISTICS | Department name |
| VOICE_RECOGNITION_SUM | V_NOTE_CHARACTERISTICS | Characters attributed to voice recognition |
| note_attribution_source_code | NOTE_ATTRIBUTION | Attribution source category code |
| note_attribution_source_name | ZC_NOTEATTR_SOURCE | Attribution source name |
| NOTEATTR_CHAR_COUNT | NOTE_ATTRIBUTION | Character count for this attribution source |

---

## Join Keys

- **To FACT_ENCOUNTER:** `PAT_ENC_CSN_ID`
- **To DIM_PROVIDER:** `AUTHOR_LINKED_PROV_ID` → `PROV_ID`
- **Internal:** `NOTE_ID` links all note subtables

---

## Attribution Source Codes (ZC_NOTEATTR_SOURCE)

Key values from `NOTEATTR_SOURCE_C` relevant to Abridge analysis:

| Code | Source |
|---|---|
| 1 | Manual (typed) |
| 12 | Voice Recognition |
| 25 | **Ambient Listening (Abridge)** |
| 7 | Copied |
| 3 | SmartText |
| 4 | SmartPhrase |

> Source 25 = Ambient Listening is the primary signal used in `AMBIENT_VIA_ATTR` detection and for measuring Abridge's character contribution to notes.

---

## Partner-Configurable Elements

| Element | Location | Default | Notes |
|---|---|---|---|
| Date range | `DATE_PARAMS` CTE | 2023-04-01 to yesterday | Match with RawEncounterPull |
| Encounter types | `date_filtered_enc` | 3, 76, 101 | Match across all fact pulls |
| IntraConnect CID | SER_MAP join | Included | Remove if not licensed |

---

## Known Issues & Considerations

### ⚠️ Fan-Out Risk: NOTE_ATTRIBUTION Join
`NOTE_ATTRIBUTION` has a composite PK of `(NOTE_ID, LINE)` — multiple rows per note (one per attribution source). If a single note has characters attributed to multiple sources (e.g., manual + ambient), this join will produce **multiple rows per note**.

**Impact:** If a user counts rows in this output to count notes, they will over-count when multiple attribution sources exist on the same note.

**Options to handle:**
1. **Separate table approach:** Remove the `NOTE_ATTRIBUTION` join from this query and create a separate `RawNoteAttributionPull` at the (NOTE_ID + LINE) grain. Join to RawNotesPull via NOTE_ID in BI.
2. **Aggregate approach:** Use `SUM(NOTEATTR_CHAR_COUNT)` grouped by attribution source in BI.
3. **Filter to ambient only:** Add `WHERE natr.NOTEATTR_SOURCE_C = 25` if only ambient attribution is needed.

### ⚠️ Fan-Out Risk: NOTE_WRITE_TIMING Join
`NOTE_WRITE_TIMING` also has a composite PK of `(NOTE_ID, LINE)` — multiple editing sessions per note. The current join filters to `nwt.WRITE_USER_ID = hno.ENTRY_USER_ID` which reduces but may not eliminate fan-out (a provider can open and edit a note multiple times, producing multiple LINE rows per WRITE_USER_ID).

**Recommendation:** If total time-in-notes per note is the goal, use `SUM(LENGTH_OF_EDIT)` grouped by NOTE_ID rather than pulling individual session rows.

### ℹ️ V_NOTE_CHARACTERISTICS — Not All Notes Covered
Per the data dictionary: *"Only notes written on valid patients and created after the most recent instant note attribution was enabled will be found in this view."* Notes from before note attribution was enabled at the partner site will have NULL values for all V_NOTE_CHARACTERISTICS columns.

### ℹ️ COPIED_SUM in V_NOTE_CHARACTERISTICS
The view has a `COPIED_SUM` column (not currently in the SELECT) that counts characters copied/pasted from previous contacts. This is useful for measuring documentation quality — high copied_sum relative to total_note_length may indicate copy-forward behavior.

### ℹ️ IntraConnect Dependency
The `SER_MAP` join for `author_linked_prov_cid` requires IntraConnect license. Remove if not applicable:
```sql
-- Remove this join:
LEFT JOIN SER_MAP map ON vnc.AUTHOR_LINKED_PROV_ID = map.INTERNAL_ID
-- And remove from SELECT:
, map.CID author_linked_prov_cid
```
