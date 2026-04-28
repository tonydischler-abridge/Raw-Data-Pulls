/*
================================================================================
  RawProviderPull_V2_2026-04-28.sql
  Grain:    1 row per provider (PROV_ID)
  Purpose:  Provider dimension — NPI, type, specialty, employment status, CID,
            employee/user details

  V2 CHANGES:
    - Added LEFT JOIN to CLARITY_EMP on USER_ID
    - Added columns: system_login, emp_name, user_status_code,
      user_status_name, emp_primary_department_id

  ℹ️  PROV_TYPE <> 0 filter excludes resources (rooms, equipment, etc.) and
      retains all human providers. To restrict to physicians only, add
      PROVIDER_TYPE_C = '1' in your BI/reporting layer (not here at raw level).
  ℹ️  SER_MAP (ser_cid) requires IntraConnect license. Remove that column and
      the LEFT JOIN to SER_MAP if the partner is not licensed for Interconnect.
  ℹ️  CLARITY_EMP join is LEFT — not all providers have an associated user
      account (e.g. external referring providers). EMP columns will be NULL
      for those records.

  CONFIGURE: Remove ser_cid / SER_MAP join if IntraConnect is not licensed.
================================================================================
*/
SELECT
    ser.PROV_ID as provider_id
    , ser.PROV_NAME as provider_name
    , ser2.NPI as npi
    , ser.PROV_TYPE as provider_type
    , ser.IS_RESIDENT as is_resident
    , ser.USER_ID as user_id
    , ser.UPIN as upin
    , ser.EMP_STATUS as employment_status
    , ser.CLINICIAN_TITLE as clinician_title
    , ser.REFERRAL_SOURCE_TYPE as referral_source_type
    , ser.BILL_PROV_YN as billing_provider_yn
    , ser.RECORD_TYPE as record_type
    , ser.EMAIL  as email
    , ser.PRACTICE_NAME_C as practice_name_code
    , zpn.NAME as practice_name
    , ser.REVENUE_DEPT_ID as revenue_department_id
    , ser.PROVIDER_TYPE_C as provider_type_code
    , zpt.NAME as provider_type_name
    , ser2.PRIMARY_DEPT_ID as primary_department_id
    , ser3.DEPARTURE_DATE as departure_date
    , map.CID as ser_cid -- remove if not licensed for Interconnect
    , emp.SYSTEM_LOGIN as system_login
    , emp.NAME as emp_name
    , emp.USER_STATUS_C as user_status_code
    , zus.NAME as user_status_name
    , emp.PRIMARY_DEPT_ID as emp_primary_department_id
FROM CLARITY_SER ser
LEFT JOIN CLARITY_SER_2 ser2
    on ser2.PROV_ID = ser.PROV_ID
LEFT JOIN ZC_PRACTICE_NAME zpn
    on zpn.PRACTICE_NAME_C = ser.PRACTICE_NAME_C
LEFT JOIN ZC_PROVIDER_TYPE zpt
    on zpt.PROVIDER_TYPE_C = ser.PROVIDER_TYPE_C
LEFT JOIN CLARITY_SER_3 ser3
    on ser3.PROV_ID = ser.PROV_ID
LEFT JOIN SER_MAP map -- remove if not licensed for Interconnect
    on map.PROV_ID = ser.PROV_ID
LEFT JOIN CLARITY_EMP emp
    on emp.USER_ID = ser.USER_ID
LEFT JOIN ZC_USER_STATUS zus
    on zus.USER_STATUS_C = emp.USER_STATUS_C
WHERE ser.PROV_TYPE <> 0 -- include all non-resources

/* As a reminder, any information Abridge shares with you related to our internal processes,
including our Epic scripts and queries, is considered confidential information under the services agreement
between your health system and Abridge.
Accordingly, Abridge's information generally may not be shared with third parties. */
