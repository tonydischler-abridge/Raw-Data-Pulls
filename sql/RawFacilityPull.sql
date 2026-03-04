/*
================================================================================
  RawFacilityPull.sql
  Grain:    1 row per active department (DEPARTMENT_ID)
  Purpose:  Facility/department dimension — location hierarchy, service area, beds
  Doc:      ../docs/RawFacilityPull.md

  ✅  Fixed typo: was CLARITTY_DEP (double T) in original — corrected to CLARITY_DEP.
  ℹ️  REV_LOC_ID is the billing/revenue location (used for financial reporting).
      ADT_PARENT_ID is the physical/ADT location (used for census and bed management).
      These are often different — use REV_LOC for billing joins, ADT_PARENT for
      inpatient/hospital department joins.
  ℹ️  RECORD_STATUS = 0 filter returns only active departments. Remove filter to
      include retired/inactive departments for historical analysis.
  ℹ️  LICENSED_BEDS is only populated for inpatient/hospital departments.
      Outpatient clinic departments will have NULL.

  CONFIGURE: No date parameters — this is a full dimension table snapshot.
================================================================================
*/
SELECT
    dep.DEPARTMENT_ID
    , dep.DEPARTMENT_NAME
    , dep.DEPT_ABBREVIATION
    , dep.SPECIALTY
    , dep.REV_LOC_ID
    , revloc.LOC_NAME AS REV_LOC_NAME
    , dep.ADT_PARENT_ID
    , adtloc.LOC_NAME AS ADT_PARENT_NAME
    , dep.SERV_AREA_ID
    , csa.SERV_AREA_NAME
    , csa.SERV_AREA_TYPE 
    , dep.LICENSED_BEDS
    , dep.ADT_UNIT_TYPE_C
    , zaut.NAME AS ADT_UNIT_TYPE_NAME
    , dep.COST_CENTER_ID
    , ccc.COST_CENTER_NAME
    , dep.EXTERNAL_NAME
    , dep.FACILITY_C
FROM CLARITY_DEP dep  -- ✅ Fixed: was CLARITTY_DEP (double T) in original
LEFT JOIN CLARITY_LOC revloc
    ON dep.REV_LOC_ID = revloc.LOC_ID
LEFT JOIN CLARITY_LOC adtloc
    ON dep.ADT_PARENT_ID = adtloc.LOC_ID
LEFT JOIN CLARITY_SA csa
    on dep.SERV_AREA_ID = csa.SERV_AREA_ID
LEFT JOIN ZC_ADT_UNIT_TYPE zaut
    ON dep.ADT_UNIT_TYPE_C = zaut.ADT_UNIT_TYPE_C
LEFT JOIN CL_COST_CNTR ccc
    ON dep.COST_CENTER_ID = ccc.COST_CNTR_ID
where dep.RECORD_STATUS = 0
