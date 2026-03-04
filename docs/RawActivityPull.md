# RawActivityPull

**Grain:** One row per user activity per hour-of-day per encounter
**Role in Data Model:** UAL (User Activity Log) fact table — joins to FACT_ENCOUNTER via CSN
**Source Query:** `SQL/RawActivityPull.sql`

---

## Purpose

Produces one record per user activity log entry associated with encounters in the configured date range. Captures time-in-chart data at the activity level — how many seconds a user spent on specific Hyperspace activities (chart review, note writing, order entry, etc.) during each quarter-hour of the encounter day. This is the raw-level equivalent of the aggregated `AbridgeTimeInNotes` query, providing full activity and navigator section detail.

---

## Key Tables

| Table | Description | Dictionary Page |
|---|---|---|
| `UAL_ACTIVITY_HOURS` | User action log data; one row per activity per user per hour; PK: UAL_ACTIVITY_HOUR_KEY; Rel Feb 2019 | p.84 |
| `DESKTOP_ACTIVITY` | Activity reference table; provides ACTIVITY_NAME, DISPLAY_NAME, ACTIVITY_DESCRIPTOR; Chronicles INI: E2N | p.229 |
| `NAVIGATOR_SECTIONS` | Navigator section reference; SECTION_CAPTION, SECTION_NAME, SECTION_DESCRIPTOR; Chronicles INI: LVN | p.230 |

---

## Output Columns

| Column | Source | Notes |
|---|---|---|
| PAT_ENC_CSN_ID | UAL_ACTIVITY_HOURS | Encounter join key |
| AMBIENT_FLAG | Derived | 'Y' / 'N' |
| ACTIVITY_ID | UAL_ACTIVITY_HOURS | Activity record ID; joins to DESKTOP_ACTIVITY |
| ACTIVITY_NAME | DESKTOP_ACTIVITY | Internal name of the activity |
| DISPLAY_NAME | DESKTOP_ACTIVITY | User-facing display name of the activity |
| ACTIVITY_DESCRIPTOR | DESKTOP_ACTIVITY | Descriptor for the activity record |
| HISTORY_POINT_ID | UAL_ACTIVITY_HOURS | Navigator section ID; joins to NAVIGATOR_SECTIONS |
| SECTION_CAPTION | NAVIGATOR_SECTIONS | Display caption for the navigator section |
| SECTION_NAME | NAVIGATOR_SECTIONS | Name of the navigator section record |
| SECTION_DESCRIPTOR | NAVIGATOR_SECTIONS | Descriptor for the navigator section |
| USER_ID | UAL_ACTIVITY_HOURS | User who performed the activity |
| CONTACT_DATE | UAL_ACTIVITY_HOURS | Date of the encounter/activity |
| HOUR_OF_DAY | UAL_ACTIVITY_HOURS | Hour of day the activity occurred (0–23) |
| Q1_SECONDS | UAL_ACTIVITY_HOURS | Seconds active in first 15 min of the hour |
| Q2_SECONDS | UAL_ACTIVITY_HOURS | Seconds active in second 15 min of the hour |
| Q3_SECONDS | UAL_ACTIVITY_HOURS | Seconds active in third 15 min of the hour |
| Q4_SECONDS | UAL_ACTIVITY_HOURS | Seconds active in fourth 15 min of the hour |
| NUMBER_OF_SECONDS_ACTIVE | UAL_ACTIVITY_HOURS | Total seconds active for this activity-hour row |

> **Column names:** The exact Q1–Q4 column names and UAL_ACTIVITY_HOUR_KEY should be verified against the partner's Epic Clarity extract — UAL column naming conventions have varied across Epic versions.

---

## Join Keys

- **To FACT_ENCOUNTER:** `PAT_ENC_CSN_ID`
- **Internal:** `ACTIVITY_ID` links to `DESKTOP_ACTIVITY`
- **Internal:** `HISTORY_POINT_ID` + `'LVN'` links to `NAVIGATOR_SECTIONS`

---

## Partner-Configurable Elements

| Element | Location | Default | Notes |
|---|---|---|---|
| Date range | `DATE_PARAMS` CTE | 2023-04-01 to yesterday | Set to go-live date |
| Encounter types | `date_filtered_enc` | 3, 76, 101 | Match across pulls |

---

## Known Issues & Considerations

### ⚠️ Missing Provider Linkage
The current query pulls `USER_ID` from `UAL_ACTIVITY_HOURS` but does not join to `CLARITY_EMP` to retrieve the associated `PROV_ID`. This makes it harder to join UAL activity to provider-level analysis without a separate USER_ID → PROV_ID mapping.

**Recommended addition:**
```sql
LEFT JOIN CLARITY_EMP emp
    ON ual.USER_ID = emp.USER_ID
```
Then add `emp.PROV_ID` to the SELECT. This allows joining to `DIM_PROVIDER` on `PROV_ID` rather than `USER_ID`.

### ℹ️ UAL Data Availability
`UAL_ACTIVITY_HOURS` has a load type of `APPEND` (not incremental replace), meaning it accumulates over time. Some older Epic environments may have limited UAL history or may not have UAL enabled for all workstation types. Confirm with the partner that UAL data is being captured for their clinical workstations.

### ℹ️ Quarter-Hour Granularity
The four Q columns split each hour into 15-minute buckets. `NUMBER_OF_SECONDS_ACTIVE` is the sum of Q1+Q2+Q3+Q4 but may also capture partial-minute rounding. For total time calculations, use `NUMBER_OF_SECONDS_ACTIVE` rather than summing the Q columns manually.

### ℹ️ NAVIGATOR_SECTIONS Join Filter
The join uses `WORKSPACE_KIND = 'LVN'` (or similar) to match the NAVIGATOR_SECTIONS table, since `HISTORY_POINT_ID` could refer to different workspace types. Per the dictionary, NAVIGATOR_SECTIONS only includes records where `LVN 100 = 3` (section type). Confirm the join predicate matches the partner's data structure.

### ℹ️ Desktop Activity vs Navigator Activity
Not all UAL rows have both an ACTIVITY_ID and a HISTORY_POINT_ID. Some rows are purely desktop activity (no navigator context), others are purely within a navigator. The LEFT JOINs to both tables handle this correctly — NULL on one doesn't exclude the row.
