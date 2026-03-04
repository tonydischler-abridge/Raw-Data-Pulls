# RawDiagnosisPull

**Grain:** One row per diagnosis per encounter (`PAT_ENC_CSN_ID` + `LINE`)
**Role in Data Model:** Diagnosis fact table — joins to FACT_ENCOUNTER via CSN
**Source Query:** `SQL/RawDiagnosisPull.sql`

---

## Purpose

Produces one record per diagnosis associated with each encounter. Captures diagnosis codes (ICD-10), chronic/HCC flags, and primary diagnosis designation. Intended to support analysis of diagnosis documentation completeness, HCC capture rates, and chronic disease management — supplementing and replacing the aggregated `AbridgeDiagnosisHCCCount` query with full diagnosis-level detail.

---

## Key Tables

| Table | Description | Dictionary Page |
|---|---|---|
| `PAT_ENC_DX` | Encounter diagnosis table; one record per diagnosis per encounter; PK: PAT_ENC_CSN_ID + LINE | p.47 |
| `CLARITY_EDG` | Diagnosis master record; contains ICD codes and diagnosis names; Chronicles INI: EDG | p.176 |

---

## Output Columns

| Column | Source | Notes |
|---|---|---|
| PAT_ENC_CSN_ID | PAT_ENC_DX | Encounter join key |
| AMBIENT_FLAG | Derived | 'Y' / 'N' |
| CONTACT_DATE | PAT_ENC_DX | Date of the encounter for this diagnosis |
| DX_ID | PAT_ENC_DX | Internal diagnosis record ID; PK of CLARITY_EDG |
| PRIMARY_DX_YN | PAT_ENC_DX | 'Y' if this is the primary diagnosis; 'N' otherwise |
| DX_CHRONIC_YN | PAT_ENC_DX | 'Y' if diagnosis is flagged as chronic |
| DX_HCC_C | PAT_ENC_DX | HCC (Hierarchical Condition Category) code |
| DX_NAME | CLARITY_EDG | Name of the diagnosis |
| ICD9_CODE | CLARITY_EDG | ⚠️ Deprecated — see notes |
| CURRENT_ICD10_LIST | CLARITY_EDG | Current ICD-10 code list |

> **Note:** The exact column names for ICD codes come from CLARITY_EDG. The dictionary confirms `ICD9_CODE` (EDG 2000) is deprecated. The query uses `CURRENT_ICD9_LIST` and `CURRENT_ICD10_LIST` — verify the exact column names available in the partner's Epic version.

---

## Join Keys

- **To FACT_ENCOUNTER:** `PAT_ENC_CSN_ID`
- **Internal:** `DX_ID` links `PAT_ENC_DX` → `CLARITY_EDG`

---

## Partner-Configurable Elements

| Element | Location | Default | Notes |
|---|---|---|---|
| Date range | `DATE_PARAMS` CTE | 2023-04-01 to yesterday | Match with RawEncounterPull |
| Encounter types | `date_filtered_enc` | 3, 76, 101 | Match across all fact pulls |

---

## Known Issues & Considerations

### ⚠️ ICD9_CODE Deprecated in CLARITY_EDG
Per the data dictionary: *"ICD9_CODE (EDG 2000) has been deprecated. Refer to the Diagnosis and ICD Procedure Updates section of https://galaxy.epic.com to determine the correct column to use."*

The query should use `CURRENT_ICD10_LIST` (or the partner's current ICD code column). Confirm the correct column name is being used in the SQL — `ICD9_CODE` in `PAT_ENC_DX` is also deprecated and pulls from the EDG 40 item which may be empty in modern Epic builds.

**Recommended:** Use `DX_ID` to join to `CLARITY_EDG` and pull `CURRENT_ICD10_LIST` for ICD-10 codes.

### ℹ️ LINE Column is Key for Grain
`PAT_ENC_DX` has a composite primary key of `PAT_ENC_CSN_ID + LINE`. The `LINE` column is the line number of the diagnosis within the encounter. An encounter can have many diagnosis lines. Including `LINE` in the output or as a sort key helps distinguish them.

### ℹ️ PRIMARY_DX_YN vs DX_QUALIFIER_C
`PRIMARY_DX_YN = 'Y'` identifies the primary diagnosis. `DX_QUALIFIER_C` provides additional qualifier detail (Admitting, Working, Final, etc.) but is not included in the current query output. Add it if needed for inpatient analysis.

### ℹ️ HCC Codes and Chronic Flags
`DX_CHRONIC_YN` and `DX_HCC_C` are populated based on Epic's master diagnosis file, not per-encounter data entry. These are attributes of the diagnosis itself, not of how the provider documented it. They are reliable for population health analysis.

### ℹ️ Diagnosis Scope — Order Summary Only
Per the data dictionary description: *"This table will contain all diagnoses specified on the Order Summary screen."* This means diagnoses on hospital problem lists or problem-level documentation may not appear here — only encounter-level diagnosis entries.
