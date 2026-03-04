# RawFacilityPull

**Grain:** One row per active department (`DEPARTMENT_ID`)
**Role in Data Model:** Facility/department dimension table — no date filter; static reference data
**Source Query:** `SQL/RawFacilityPull.sql`

---

## Purpose

Produces a department/facility dimension table containing one record per active department in the Epic system. Captures department name, abbreviation, specialty, location hierarchy (revenue location, ADT parent), service area, cost center, and facility type. Used to enrich fact table joins with location context for site-level and department-level analysis.

---

## Key Tables

| Table | Description | Dictionary Page |
|---|---|---|
| `CLARITY_DEP` | Department record; PK: DEPARTMENT_ID; Chronicles INI: DEP; Epic 2000 | p.65 |
| `CLARITY_LOC` | Location record; provides LOC_NAME for REV_LOC and ADT_PARENT | — |
| `CLARITY_SA` | Service area record; provides SERV_AREA_NAME and SERV_AREA_TYPE | — |
| `ZC_ADT_UNIT_TYPE` | ADT unit type code/name lookup | — |
| `CL_COST_CNTR` | Cost center record; provides COST_CENTER_NAME | — |

---

## Output Columns

| Column | Source | Notes |
|---|---|---|
| DEPARTMENT_ID | CLARITY_DEP | Primary key |
| DEPARTMENT_NAME | CLARITY_DEP | Full department name |
| DEPT_ABBREVIATION | CLARITY_DEP | Department abbreviation |
| SPECIALTY | CLARITY_DEP | Department specialty |
| REV_LOC_ID | CLARITY_DEP | Revenue location ID |
| REV_LOC_NAME | CLARITY_LOC | Revenue location name |
| ADT_PARENT_ID | CLARITY_DEP | ADT parent location ID (facility/hospital) |
| ADT_PARENT_NAME | CLARITY_LOC | ADT parent location name |
| SERV_AREA_ID | CLARITY_DEP | Service area ID |
| SERV_AREA_NAME | CLARITY_SA | Service area name |
| SERV_AREA_TYPE | CLARITY_SA | Service area type |
| LICENSED_BEDS | CLARITY_DEP | Number of licensed beds (inpatient depts) |
| ADT_UNIT_TYPE_C | CLARITY_DEP | ADT unit type code |
| ADT_UNIT_TYPE_NAME | ZC_ADT_UNIT_TYPE | ADT unit type name |
| COST_CENTER_ID | CLARITY_DEP | Cost center ID |
| COST_CENTER_NAME | CL_COST_CNTR | Cost center name |
| EXTERNAL_NAME | CLARITY_DEP | External-facing department name |
| FACILITY_C | CLARITY_DEP | Facility category code |

---

## Join Keys

- **From FACT_ENCOUNTER:** `DEPARTMENT_ID`
- **From FACT_TRANSACTION:** `LOC_ID` → `DEPARTMENT_ID`
- **From FACT_SCHEDULE:** `DEPARTMENT_ID`

---

## Partner-Configurable Elements

| Element | Location | Default | Notes |
|---|---|---|---|
| Active-only filter | `WHERE dep.RECORD_STATUS = 0` | Active departments only | `RECORD_STATUS = 0` = active in Epic |
| No date range | N/A | N/A | Full dimension pull; refresh periodically |

---

## Known Issues & Considerations

### ✅ CLARITTY_DEP Typo — Fixed in SQL Folder
The original source query referenced `CLARITTY_DEP` (with a double T), which would cause a SQL runtime error ("object not found"). **This has been corrected to `CLARITY_DEP` in the SQL folder version.** Always use the version in `SQL/RawFacilityPull.sql`.

### ℹ️ RECORD_STATUS = 0 Filters to Active Departments Only
The `WHERE dep.RECORD_STATUS = 0` filter keeps only currently active departments. Historical encounters may reference departments that have since been merged, renamed, or deactivated. If historical analysis requires deactivated department names, remove this filter and add a `RECORD_STATUS` column to the output.

### ℹ️ Location Hierarchy: REV_LOC vs ADT_PARENT
Epic uses two location hierarchies:
- **Revenue Location** (`REV_LOC_ID`) — used for professional billing purposes
- **ADT Parent** (`ADT_PARENT_ID`) — used for inpatient admission/discharge/transfer tracking

For outpatient analysis, `REV_LOC_NAME` is typically the relevant location. For inpatient analysis, `ADT_PARENT_NAME` identifies the hospital/facility. Some departments will have both; some will only have one.

### ℹ️ SPECIALTY Column
`CLARITY_DEP.SPECIALTY` is a freetext field, not a coded value. It may be inconsistently populated across departments (some may use abbreviations, full names, or be NULL). For consistent specialty reporting, consider joining to the provider specialty via `DIM_PROVIDER.provider_type_code` rather than relying on department specialty.

### ℹ️ No Date Filter — Full Dimension Pull
Like `RawProviderPull`, this query has no date range. Run on a periodic refresh schedule to keep the dimension current. Most departments are stable, but reorganizations, mergers, and new facility openings should be tracked.
