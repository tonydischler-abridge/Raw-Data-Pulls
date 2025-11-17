SELECT
    ser.PROV_ID as provider_id
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
WHERE ser.PROV_TYPE <> 0 -- include all non-resources
