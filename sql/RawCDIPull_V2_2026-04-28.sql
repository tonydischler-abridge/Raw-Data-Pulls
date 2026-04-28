/*
================================================================================
  RawCDIPull_V2_2026-04-28.sql
  Grain:    1 row per CDI query (QUERY_IDENT)
  Purpose:  Clinical Documentation Integrity query fact — CDI/coding query outcomes

  V2 CHANGES:
    - Removed ambient detection CTEs (SDE, NAS, ATTR, DXR, ALL_AMBIENT)
      and AMBIENT_FLAG column. Ambient status is now derived by joining
      to RawEncounterPull on PAT_ENC_CSN_ID in the BI layer.

  ℹ️  Requires the CDI module to be active in the partner's Epic build. If CDI
      is not licensed or not used, this query will return 0 rows.
  ℹ️  V_CLIN_DOC_QUERY_INFO is a view — verify it is available in the partner's
      reporting database. Some older Clarity builds may not expose this view.
  ℹ️  TOTAL_TIME_ASSIGNED is in seconds. Convert to minutes/hours in reporting layer.

  CONFIGURE: Update START_DATE in DATE_PARAMS to partner's Abridge go-live date.
             Confirm CDI module is active before deploying to partner.
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
)

SELECT
    cdi.QUERY_IDENT,
    cdi.PAT_ENC_CSN_ID,
    cdi.CDI_QRY_TYPE_NAME              AS cdi_query_type,
    cdi.CODING_QRY_TYPE_NAME           AS coding_query_type,
    cdi.RECIPIENT_PROV_ID,
    ser.PROV_NAME,
    cdi.RESPONDING_PROV_ID,
    cdi.RECIPIENT_PROV_NPI_ID,
    cdi.RESPONDING_PROV_NPI_ID,
    cdi.QUERY_STATUS_NAME,
    cdi.NLP_STATUS_NAME,
    cdi.QUERY_OUTCOME_NAME,
    cdi.CREATION_DTTM,
    cdi.UPDATE_DTTM,
    cdi.TOTAL_TIME_ASSIGNED
FROM V_CLIN_DOC_QUERY_INFO cdi
INNER JOIN date_filtered_enc dfe
    ON dfe.PAT_ENC_CSN_ID = cdi.PAT_ENC_CSN_ID
LEFT JOIN CLARITY_SER ser
    ON ser.PROV_ID = cdi.RECIPIENT_PROV_ID

/* As a reminder, any information Abridge shares with you related to our internal processes,
including our Epic scripts and queries, is considered confidential information under the services agreement
between your health system and Abridge.
Accordingly, Abridge's information generally may not be shared with third parties. */
