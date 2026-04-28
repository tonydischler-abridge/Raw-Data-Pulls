/*
================================================================================
  RawEncounterPull_V2_2026-04-28.sql
  Grain:    1 row per patient encounter (PAT_ENC_CSN_ID)
  Purpose:  Core encounter fact table — foundation for all raw data joins

  V2 CHANGES:
    - Removed LEFT JOIN to HNO_INFO + NOTE_AMBIENT_SECTIONS from final SELECT
      to fix fan-out when multiple ambient notes exist per encounter
    - Removed AMBIENT_SESSION_IDENT column (belongs in RawNotesPull)
    - Removed ALL_AMBIENT CTE (no longer needed)
    - Added LEFT JOINs to individual ambient CTEs in final SELECT
    - AMBIENT_FLAG now derived from individual ambient CTE joins
    - Added AMBIENT_DETECTION_METHODS column showing which detection
      methods flagged the encounter (e.g. 'SDE, NAS, ATTR')

  CONFIGURE: Update START_DATE in DATE_PARAMS to partner's Abridge go-live date.
             Review ENC_TYPE_C values for partner-specific encounter types.
================================================================================
*/
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
)

SELECT
    penc.PAT_ENC_CSN_ID,
    CASE
        WHEN sde.PAT_ENC_CSN_ID IS NOT NULL
          OR nas.PAT_ENC_CSN_ID IS NOT NULL
          OR attr.PAT_ENC_CSN_ID IS NOT NULL
          OR dxr.PAT_ENC_CSN_ID IS NOT NULL
        THEN 'Y' ELSE 'N'
    END AS AMBIENT_FLAG,
    STUFF(
        COALESCE(', ' + CASE WHEN sde.PAT_ENC_CSN_ID IS NOT NULL THEN 'SDE' END, '') +
        COALESCE(', ' + CASE WHEN nas.PAT_ENC_CSN_ID IS NOT NULL THEN 'NAS' END, '') +
        COALESCE(', ' + CASE WHEN attr.PAT_ENC_CSN_ID IS NOT NULL THEN 'ATTR' END, '') +
        COALESCE(', ' + CASE WHEN dxr.PAT_ENC_CSN_ID IS NOT NULL THEN 'DXR' END, ''),
        1, 2, ''
    ) AS AMBIENT_DETECTION_METHODS,
    penc.ENC_TYPE_C encounter_type_code,
    zenc.NAME encounter_type_name,
    penc.FIN_CLASS_C financial_class_code,
    zfin.NAME financial_class_name,
    penc.VISIT_PROV_ID,
    penc.DEPARTMENT_ID,
    penc.PAT_ENC_DATE_REAL,
    penc.ENC_CLOSE_DATE,
    penc.ENC_CLOSE_TIME,
    penc.APPT_TIME,
    penc.APPT_LENGTH,
    penc.CHECKIN_TIME,
    penc.CHECKOUT_TIME,
    penc.HOSP_ADMSN_TIME,
    penc.HOSP_DISCHRG_TIME,
    penc.HSP_ACCOUNT_ID,
    penc.CLAIM_ID,
    penc.ATTND_PROV_ID,
    penc2.VISIT_POS_ID,
    vlos.CALCULATED_LOS
FROM PAT_ENC penc
LEFT JOIN AMBIENT_VIA_SDE sde
    ON penc.PAT_ENC_CSN_ID = sde.PAT_ENC_CSN_ID
LEFT JOIN AMBIENT_VIA_NAS nas
    ON penc.PAT_ENC_CSN_ID = nas.PAT_ENC_CSN_ID
LEFT JOIN AMBIENT_VIA_ATTR attr
    ON penc.PAT_ENC_CSN_ID = attr.PAT_ENC_CSN_ID
LEFT JOIN AMBIENT_VIA_DXR dxr
    ON penc.PAT_ENC_CSN_ID = dxr.PAT_ENC_CSN_ID
LEFT JOIN ZC_ENC_TYPE zenc
    ON penc.ENC_TYPE_C = zenc.ENC_TYPE_C
LEFT JOIN ZC_FIN_CLASS zfin
    ON penc.FIN_CLASS_C = zfin.FIN_CLASS_C
LEFT JOIN PAT_ENC_2 penc2
    ON penc.PAT_ENC_CSN_ID = penc2.PAT_ENC_CSN_ID
LEFT JOIN V_PAT_ENC_CALCULATED_LOS vlos
    ON penc.PAT_ENC_CSN_ID = vlos.PAT_ENC_CSN_ID
WHERE penc.PAT_ENC_CSN_ID IN (
    SELECT PAT_ENC_CSN_ID FROM date_filtered_enc
)

/* As a reminder, any information Abridge shares with you related to our internal processes,
including our Epic scripts and queries, is considered confidential information under the services agreement
between your health system and Abridge.
Accordingly, Abridge's information generally may not be shared with third parties. */
