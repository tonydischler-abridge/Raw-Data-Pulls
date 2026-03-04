# RawSchedulePull

**Grain:** One row per scheduled appointment (`PAT_ENC_CSN_ID`)
**Role in Data Model:** Schedule fact table — joins to FACT_ENCOUNTER via CSN
**Source Query:** `SQL/RawSchedulePull.sql`

---

## Purpose

Produces one record per scheduled appointment for encounters within the configured date range. Derived from `F_SCHED_APPT`, which is Epic's reporting-optimized scheduling view built on top of `PAT_ENC`. Captures appointment timing, provider, department, visit type, and same-day flag. Useful for analyzing scheduling patterns, no-show rates, and ambient adoption relative to appointment volume.

---

## Key Tables

| Table | Description | Dictionary Page |
|---|---|---|
| `F_SCHED_APPT` | Derived scheduling view from PAT_ENC; one row per appointment; PK: PAT_ENC_CSN_ID | p.105 |

---

## Output Columns

| Column | Source | Notes |
|---|---|---|
| PAT_ENC_CSN_ID | F_SCHED_APPT | Encounter join key and primary key |
| AMBIENT_FLAG | Derived | 'Y' / 'N' |
| CONTACT_DATE | F_SCHED_APPT | Date of the appointment (same as APPT_DTTM at midnight) |
| PROV_ID | F_SCHED_APPT | Appointment provider (primary provider for joint appts) |
| APPT_STATUS_C | F_SCHED_APPT | Appointment status code (see below) |
| PRC_ID | F_SCHED_APPT | Visit type ID |
| DEPARTMENT_ID | F_SCHED_APPT | Department for the appointment |
| APPT_DTTM | F_SCHED_APPT | Appointment date and time |
| APPT_LENGTH | F_SCHED_APPT | Appointment length in minutes |
| SAME_DAY_YN | F_SCHED_APPT | 'Y' if same-day appointment |

---

## APPT_STATUS_C Reference Values

| Code | Status |
|---|---|
| 1 | Scheduled |
| 2 | Completed |
| 3 | Canceled |
| 4 | No Show |
| 5 | Left without seen |
| 6 | Arrived |

> The `date_filtered_enc` CTE pre-filters to `APPT_STATUS_C IN (2, 6)` (Completed and Arrived) — so this output will only contain completed/arrived appointments unless the filter is modified.

---

## Join Keys

- **To FACT_ENCOUNTER:** `PAT_ENC_CSN_ID`
- **To DIM_PROVIDER:** `PROV_ID`
- **To DIM_FACILITY:** `DEPARTMENT_ID`

---

## Partner-Configurable Elements

| Element | Location | Default | Notes |
|---|---|---|---|
| Date range | `DATE_PARAMS` CTE | 2023-04-01 to yesterday | Set START_DATE to go-live date |
| Encounter types | `date_filtered_enc` | 3, 76, 101 | Match across all fact pulls |
| Appointment statuses | `date_filtered_enc` | 2, 6 | Completed and Arrived; add others if needed |

---

## Known Issues & Considerations

### ℹ️ Pre-filtered to Completed/Arrived Appointments
Because the query joins to `date_filtered_enc` (which filters `APPT_STATUS_C IN (2, 6)`), this output does not include canceled, no-show, or scheduled-but-not-yet-occurred appointments. If analysis requires all appointment dispositions (e.g., no-show rate analysis), the date filter CTE would need to be relaxed.

### ℹ️ F_SCHED_APPT is Derived — Not a Base Extract
`F_SCHED_APPT` is a derived table (script: `ESP_F_SCHED_APPT`) built on top of PAT_ENC. Per the dictionary: *"It contains columns simplifying common reporting needs."* It may lag slightly behind PAT_ENC in some ETL configurations. For real-time or near-real-time needs, query PAT_ENC directly.

### ℹ️ Joint Appointment Handling
Per the data dictionary: *"For joint appointments, this contains the ID of the primary provider on the appointment."* If a patient has a joint appointment with multiple providers, `PROV_ID` will only reflect the primary provider. Secondary providers are not represented in `F_SCHED_APPT`.

### ℹ️ APPT_LENGTH Interpretation
`APPT_LENGTH` is in minutes. This is the scheduled duration, not the actual visit duration. For actual time, compare `CHECKIN_TIME` and `CHECKOUT_TIME` from `RawEncounterPull`.

### ℹ️ No Visit Type Name
`PRC_ID` (visit type) is included but the corresponding name is not joined. To get the visit type name, join `PRC_ID` to `CLARITY_PRC.PRC_ID` and pull `CLARITY_PRC.NAME` or `PRC_NAME` in the BI layer.
