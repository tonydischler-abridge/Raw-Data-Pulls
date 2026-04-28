/*
================================================================================
  RawActivityPull_V2_2026-04-28.sql
  Grain:    1 row per user activity hour bucket per encounter (UAL_ACTIVITY_HOUR_KEY)
  Purpose:  EHR user activity / time-in-chart fact — seconds active per activity type

  V2 CHANGES:
    - Removed ambient detection CTEs (SDE, NAS, ATTR, DXR, ALL_AMBIENT)
      and AMBIENT_FLAG column. Ambient status is now derived by joining
      to RawEncounterPull on PAT_ENC_CSN_ID in the BI layer.

  ℹ️  UAL_ACTIVITY_HOURS uses APPEND load type — rows accumulate over time and are
      never replaced. Do not use incremental refresh logic; always union/append.
  ℹ️  TIME is bucketed by hour; _Q1–_Q4 columns split active seconds into 15-min
      quarters within that hour bucket.
  ⚠️  No PROV_ID on UAL_ACTIVITY_HOURS. To get provider, join USER_ID to
      CLARITY_EMP.USER_ID → CLARITY_EMP.PROV_ID, then to CLARITY_SER.
  ℹ️  NAVIGATOR_SECTIONS join only applies when HISTORY_POINT_INI = 'LVN'.
      For other INI values, SECTION_CAPTION/SECTION_NAME will be NULL.
  ℹ️  UAL data contains NO EHI (Electronic Health Information) — safe to load
      separately from PHI-sensitive tables.

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
    uah.USER_ID
    , uah.PAT_ENC_CSN_ID
    , uah.ACTIVITY_ID
    , uah.ACTIVITY_HOUR_DTTM
    , uah.ACTIVITY_HOUR_UTC_DTTM
    , uah.WORKSPACE_KIND
    , uah.WORKSPACE_SUBKIND
    , uah.HISTORY_POINT_INI
    , uah.HISTORY_POINT_ID
    , uah.HISTORY_POINT_ITEM
    , uah.NUMBER_OF_SECONDS_ACTIVE
    , uah.NUMBER_OF_SECONDS_ACTIVE_Q1
    , uah.NUMBER_OF_SECONDS_ACTIVE_Q2
    , uah.NUMBER_OF_SECONDS_ACTIVE_Q3
    , uah.NUMBER_OF_SECONDS_ACTIVE_Q4
    , da.ACTIVITY_NAME
    , da.DISPLAY_NAME
    , da.ACTIVITY_DESCRIPTOR
    , ns.SECTION_CAPTION
    , ns.SECTION_NAME
    , ns.SECTION_DESCRIPTOR
FROM UAL_ACTIVITY_HOURS uah
LEFT JOIN DESKTOP_ACTIVITY DA
    ON uah.ACTIVITY_ID = DA.ACTIVITY_ID
LEFT JOIN NAVIGATOR_SECTIONS ns
    on uah.HISTORY_POINT_ID = ns.NAVIGATOR_ID
    AND uah.HISTORY_POINT_INI = 'LVN'
WHERE uah.PAT_ENC_CSN_ID IN (
    SELECT PAT_ENC_CSN_ID FROM date_filtered_enc
)

/* As a reminder, any information Abridge shares with you related to our internal processes,
including our Epic scripts and queries, is considered confidential information under the services agreement
between your health system and Abridge.
Accordingly, Abridge's information generally may not be shared with third parties. */
