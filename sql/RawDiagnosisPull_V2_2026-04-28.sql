/*
================================================================================
  RawDiagnosisPull_V2_2026-04-28.sql
  Grain:    1 row per diagnosis per encounter (PAT_ENC_CSN_ID + DX_ID + LINE)
  Purpose:  Encounter diagnosis fact — ICD-10 codes, chronic flags, HCC categories

  V2 CHANGES:
    - Removed ambient detection CTEs (SDE, NAS, ATTR, DXR, ALL_AMBIENT)
      and AMBIENT_FLAG column. Ambient status is now derived by joining
      to RawEncounterPull on PAT_ENC_CSN_ID in the BI layer.

  ℹ️  PAT_ENC_DX PK is composite (PAT_ENC_CSN_ID + LINE). A single encounter can
      have multiple diagnoses; LINE differentiates them (LINE 1 = primary).
  ⚠️  CURRENT_ICD9_LIST is deprecated — most partners will have NULL values.
      Use CURRENT_ICD10_LIST for all active coding.

  CONFIGURE: Update START_DATE in DATE_PARAMS to partner's Abridge go-live date.
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
    pedx.PAT_ENC_CSN_ID,
    pedx.CONTACT_DATE,
    pedx.DX_ID,
    pedx.PRIMARY_DX_YN,
    pedx.DX_CHRONIC_YN,
    ercd.DX_HCC_C,
    edg.DX_NAME,
    edg.RECORD_STATE_C,
    edg.REF_BILL_CODE_SET_C,
    edg.RECORD_TYPE_C,
    edg.CURRENT_ICD9_LIST,
    edg.CURRENT_ICD10_LIST
FROM PAT_ENC_DX pedx
INNER JOIN date_filtered_enc dfe
    ON pedx.PAT_ENC_CSN_ID = dfe.PAT_ENC_CSN_ID
LEFT JOIN EDG_RISK_CATEGORY_DATA ercd
    ON pedx.DX_ID = ercd.DX_ID
LEFT JOIN CLARITY_EDG edg
    ON pedx.DX_ID = edg.DX_ID

/* As a reminder, any information Abridge shares with you related to our internal processes,
including our Epic scripts and queries, is considered confidential information under the services agreement
between your health system and Abridge.
Accordingly, Abridge's information generally may not be shared with third parties. */
