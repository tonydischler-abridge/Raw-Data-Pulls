WITH
DATE_PARAMS AS (
    SELECT
            CAST('2023-04-01' AS date) AS START_DATE,
            DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS END_DATE
),

date_filtered_enc AS (
    SELECT 
        e.PAT_ENC_CSN_ID, 
        e.CONTACT_DATE
    FROM PAT_ENC e
    CROSS JOIN DATE_PARAMS dp
    WHERE e.CONTACT_DATE >= dp.START_DATE
        AND e.CONTACT_DATE <= dp.END_DATE
        AND e.ENC_TYPE_C IN (3,76,101) -- hospital, telemedicine, and office visit -- update as needed
        AND (e.APPT_STATUS_C IN (2,6) OR e.APPT_STATUS_C IS NULL)
),

AMBIENT_VIA_SDE AS (
    SELECT DISTINCT e.PAT_ENC_CSN_ID
    FROM date_filtered_enc e
    WHERE EXISTS (
        SELECT 1
        FROM SMRTDTA_ELEM_DATA  sde
        INNER JOIN SMRTDTA_ELEM_VALUE sev
            ON sev.HLV_ID = sde.HLV_ID
        WHERE sde.CONTACT_SERIAL_NUM = e.PAT_ENC_CSN_ID
            AND sde.ELEMENT_ID IN (
                'EPIC#31000231848','EPIC#31000231852','EPIC#31000231850','EPIC#31000231851','EPIC#31000231856'
            )
    )
),

AMBIENT_VIA_NAS AS (
    SELECT DISTINCT e.PAT_ENC_CSN_ID
    FROM date_filtered_enc e
    WHERE EXISTS (
        SELECT 1
        FROM HNO_INFO hno
        INNER JOIN NOTE_AMBIENT_SECTIONS nas
            ON nas.NOTE_ID = hno.NOTE_ID
        WHERE hno.PAT_ENC_CSN_ID = e.PAT_ENC_CSN_ID
            AND nas.AMBIENT_SESSION_IDENT IS NOT NULL
    )
),

AMBIENT_VIA_ATTR AS (
    SELECT DISTINCT e.PAT_ENC_CSN_ID
    FROM date_filtered_enc e
    WHERE EXISTS (
        SELECT 1
        FROM HNO_INFO hno
        INNER JOIN NOTE_ATTRIBUTION na
            ON na.NOTE_ID = hno.NOTE_ID
        WHERE hno.PAT_ENC_CSN_ID = e.PAT_ENC_CSN_ID
            AND na.NOTEATTR_SOURCE_C = 25
    )
),

AMBIENT_VIA_DXR AS (
    SELECT DISTINCT e.PAT_ENC_CSN_ID
    FROM date_filtered_enc e
    WHERE EXISTS (
        SELECT 1
        FROM DOCS_RCVD_DETAILS d
        INNER JOIN DOCS_RCVD_NOTE_SECTIONS n
            ON n.DOCUMENT_ID = d.DOCUMENT_ID
        WHERE d.DOCUMENT_RQST_CSN = e.PAT_ENC_CSN_ID
            AND d.DOCUMENT_RQST_CSN IS NOT NULL
    )
),

ALL_AMBIENT AS (
    SELECT PAT_ENC_CSN_ID FROM AMBIENT_VIA_SDE
    UNION
    SELECT PAT_ENC_CSN_ID FROM AMBIENT_VIA_NAS
    UNION
    SELECT PAT_ENC_CSN_ID FROM AMBIENT_VIA_ATTR
    UNION
    SELECT PAT_ENC_CSN_ID FROM AMBIENT_VIA_DXR
)

SELECT 
      penc.PAT_ENC_CSN_ID
    , CASE WHEN penc.PAT_ENC_CSN_ID IN (SELECT PAT_ENC_CSN_ID FROM ALL_AMBIENT) THEN 'Y' ELSE 'N' END AS AMBIENT_FLAG
    , penc.PAT_ID
    , nas.AMBIENT_SESSION_IDENT,
    , penc.ENC_TYPE_C encounter_type_code
    , zenc.NAME encounter_type_name
    , penc.FIN_CLASS_C financial_class_code
    , zfin.NAME financial_class_name
    , penc.VISIT_PROV_ID
    , map.CID visit_prov_cid,
    , penc.VISIT_PROV_TITLE
    , penc.DEPARTMENT_ID
    , dep.DEPARTMENT_NAME
    , penc.PAT_ENC_DATE_REAL
    , penc.ENC_CLOSE_DATE
    , penc.ENC_CLOSE_TIME
    , penc.APPT_TIME
    , penc.APPT_LENGTH
    , penc.CHECKIN_TIME
    , penc.CHECKOUT_TIME
    , penc.HOSP_ADMSN_TIME
    , penc.HOSP_DISCHRG_TIME
    , penc.HSP_ACCOUNT_ID
    , penc.CLAIM_ID
    , penc.ATTND_PROV_ID
    , penc2.VISIT_POS_ID
    , vlos.CALCULATED_LOS
    , rvu.CPT_CODE
    , rvu.PROCEDURE_CODE
    , rvu.PROCEDURE_NAME
    , rvu.PROCEDURE_QUANTITY
    , rvu.AMOUNT billed_amount
    , rvu.RVU_WORK
    , arpb.LOC_ID
    , arpb.SERVICE_AREA_ID
    , arpb.PRIMARY_DX_ID
    , arpb.PROV_SPECIALTY_C prov_specialty_code
    , zsp.NAME prov_specialty_name
    , rvu.BILL_AREA_NAME
FROM PAT_ENC penc
LEFT JOIN HNO_INFO hno 
    ON penc.PAT_ENC_CSN_ID = hno.PAT_ENC_CSN_ID
LEFT JOIN NOTE_AMBIENT_SECTIONS nas 
    ON hno.NOTE_ID = nas.NOTE_ID
LEFT JOIN ZC_ENC_TYPE zenc 
    ON penc.ENC_TYPE_C = zenc.ENC_TYPE_C
LEFT JOIN ZC_FIN_CLASS zfin 
    ON penc.FIN_CLASS_C = zfin.FIN_CLASS_C
LEFT JOIN CLARITY_DEP dep 
    ON penc.DEPARTMENT_ID = dep.DEPARTMENT_ID
LEFT JOIN PAT_ENC_2 penc2 
    ON penc.PAT_ENC_CSN_ID = penc2.PAT_ENC_CSN_ID
LEFT JOIN V_PAT_ENC_CALCULATED_LOS vlos 
    ON penc.PAT_ENC_CSN_ID = vlos.PAT_ENC_CSN_ID
LEFT JOIN ARPB_TRANSACTIONS arpb 
    ON penc.PAT_ENC_CSN_ID = arpb.PAT_ENC_CSN_ID
LEFT JOIN V_ARPB_RVU_DATA rvu 
    on arpb.TX_ID = rvu.TRANSACTION_ID
LEFT JOIN ZC_SPECIALTY zsp 
    ON arpb.PROV_SPECIALTY_C = zsp.SPECIALTY_C
LEFT JOIN SER_MAP map
    on penc.VISIT_PROV_ID = map.INTERNAL_ID
WHERE penc.PAT_ENC_CSN_ID IN (
    SELECT PAT_ENC_CSN_ID FROM date_filtered_enc
)
