# RawEncounterPull

**Grain:** One row per patient encounter (`PAT_ENC_CSN_ID`)
**Role in Data Model:** Central fact table — all other fact tables join back to this one via CSN
**Source Query:** `SQL/RawEncounterPull.sql`

---

## Purpose

Produces the encounter-level foundation record for every relevant patient visit within the configured date range. This is the spine of the raw data model — every other fact table should be able to join here via `PAT_ENC_CSN_ID`. Includes encounter metadata (type, timing, department, provider, financial class) and the `AMBIENT_FLAG` indicating whether Abridge was active.

---

## Key Tables

| Table | Description | Dictionary Page |
|---|---|---|
| `PAT_ENC` | Primary encounter record; Chronicles INI: EPT | p.5 |
| `PAT_ENC_2` | Extension of PAT_ENC; used for VISIT_POS_ID (Place of Service) | — |
| `HNO_INFO` | Clinical notes header; used only for NOTE_AMBIENT_SECTIONS join | p.29 |
| `NOTE_AMBIENT_SECTIONS` | Stores ambient session identifiers on notes | p.5 |
| `ZC_ENC_TYPE` | Code/name lookup for encounter type | — |
| `ZC_FIN_CLASS` | Code/name lookup for financial class | — |
| `V_PAT_ENC_CALCULATED_LOS` | View providing calculated length of stay | — |

---

## Output Columns

| Column | Source | Notes |
|---|---|---|
| PAT_ENC_CSN_ID | PAT_ENC | Universal encounter join key |
| AMBIENT_FLAG | Derived | 'Y' / 'N' — see AmbientDetectionLogic.md |
| AMBIENT_SESSION_IDENT | NOTE_AMBIENT_SECTIONS | Session ID from NAS method; NULL if not ambient or if NAS method didn't fire |
| ENC_TYPE_C | PAT_ENC | Encounter type code |
| encounter_type_name | ZC_ENC_TYPE | Encounter type name |
| FIN_CLASS_C | PAT_ENC | Financial class code |
| financial_class_name | ZC_FIN_CLASS | Financial class name |
| VISIT_PROV_ID | PAT_ENC | Scheduled/visit provider |
| DEPARTMENT_ID | PAT_ENC | Department where encounter occurred |
| PAT_ENC_DATE_REAL | PAT_ENC | Float representation of encounter date |
| ENC_CLOSE_DATE | PAT_ENC | Date the encounter was closed |
| ENC_CLOSE_TIME | PAT_ENC | Time the encounter was closed |
| APPT_TIME | PAT_ENC | Scheduled appointment time |
| APPT_LENGTH | PAT_ENC | Appointment duration in minutes |
| CHECKIN_TIME | PAT_ENC | Patient check-in time |
| CHECKOUT_TIME | PAT_ENC | Patient check-out time |
| HOSP_ADMSN_TIME | PAT_ENC | Hospital admission time (inpatient) |
| HOSP_DISCHRG_TIME | PAT_ENC | Hospital discharge time (inpatient) |
| HSP_ACCOUNT_ID | PAT_ENC | Hospital account ID; joins to HSP_ACCOUNT |
| CLAIM_ID | PAT_ENC | Associated claim ID |
| ATTND_PROV_ID | PAT_ENC | Attending provider ID |
| VISIT_POS_ID | PAT_ENC_2 | Place of service code |
| CALCULATED_LOS | V_PAT_ENC_CALCULATED_LOS | Length of stay (inpatient encounters) |

---

## Join Keys

- **To FACT_TRANSACTION:** `PAT_ENC_CSN_ID`
- **To FACT_DIAGNOSIS:** `PAT_ENC_CSN_ID`
- **To FACT_NOTES:** `PAT_ENC_CSN_ID`
- **To FACT_SCHEDULE:** `PAT_ENC_CSN_ID`
- **To FACT_ACTIVITY:** `PAT_ENC_CSN_ID`
- **To FACT_CDI:** `PAT_ENC_CSN_ID`
- **To DIM_FACILITY:** `DEPARTMENT_ID`
- **To DIM_PROVIDER:** `VISIT_PROV_ID` or `ATTND_PROV_ID`

---

## Partner-Configurable Elements

| Element | Location | Default | Notes |
|---|---|---|---|
| Date range | `DATE_PARAMS` CTE | 2023-04-01 to yesterday | Set START_DATE to Abridge go-live date |
| Encounter types | `date_filtered_enc` WHERE clause | 3, 76, 101 | Add/remove per partner's ENC_TYPE_C values |
| Appointment statuses | `date_filtered_enc` WHERE clause | 2, 6 or NULL | Completed and Arrived |

---

## Known Issues & Considerations

### ⚠️ Fan-Out Risk: HNO_INFO + NOTE_AMBIENT_SECTIONS Join
The query joins to `HNO_INFO` and `NOTE_AMBIENT_SECTIONS` in the SELECT clause (not just in the ambient detection CTE). If an encounter has multiple notes with ambient session identifiers, this join will return **multiple rows per encounter**.

**Impact:** Downstream counts (encounter counts, wRVU sums, etc.) will be inflated if users count rows from this table without deduplication.

**Recommended fix options:**
1. Remove `nas.AMBIENT_SESSION_IDENT` from the SELECT and rely solely on the `AMBIENT_FLAG` column — simplest approach
2. Add `TOP 1` logic or a `ROW_NUMBER()` window function to keep only one NAS record per CSN
3. Add an explicit `GROUP BY` or `DISTINCT` if `AMBIENT_SESSION_IDENT` is needed

### ℹ️ ZC_ENC_TYPE vs ZC_DISP_ENC_TYPE
This query uses `ZC_ENC_TYPE` for encounter type name lookup. The aggregated queries (`AbridgeTimeInNotes`, etc.) use `ZC_DISP_ENC_TYPE`. These two tables may return slightly different display names for the same code. Align with the aggregated queries if consistency is needed.

### ℹ️ Physician Filter Not Applied
No `PROVIDER_TYPE_C = '1'` filter is applied at this raw level. This is intentional — the raw export should include all encounters regardless of provider type so BI users can filter as needed. Apply the physician filter in BI views or aggregated downstream models.

### ℹ️ CONTACT_DATE vs PAT_ENC_DATE_REAL
`CONTACT_DATE` (datetime, from `date_filtered_enc`) and `PAT_ENC_DATE_REAL` (float representation) both represent the encounter date. `PAT_ENC_DATE_REAL` is the Epic-native format where the integer = date and decimal digits = multiple visits on the same day. `CONTACT_DATE` is more human-readable and should be used for date filtering/grouping in BI.
