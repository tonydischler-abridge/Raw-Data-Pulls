/*
================================================================================
  RawSchedulePull_V2_2026-04-28.sql
  Grain:    1 row per scheduled appointment (PAT_ENC_CSN_ID)
  Purpose:  Appointment scheduling fact — status, provider, slot length, same-day

  V2 CHANGES:
    - Removed ambient detection CTEs (SDE, NAS, ATTR, DXR, ALL_AMBIENT)
      and AMBIENT_FLAG column. Ambient status is now derived by joining
      to RawEncounterPull on PAT_ENC_CSN_ID in the BI layer.

  ℹ️  F_SCHED_APPT is a derived/aggregate table. It may not contain all historical
      appointments depending on partner's reporting database refresh schedule.
  ℹ️  APPT_STATUS_C values: 1=Scheduled, 2=Arrived, 3=No Show, 4=Left w/o Seen,
      5=Canceled, 6=Completed. The date_filtered_enc CTE pre-filters to 2 and 6.
  ℹ️  Joint (multi-provider) appointments will appear as separate rows, one per
      provider. Use PAT_ENC_CSN_ID to collapse back to encounter level if needed.

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
)

SELECT
    fsa.PAT_ENC_CSN_ID,
    fsa.CONTACT_DATE,
    fsa.PROV_ID,
    fsa.APPT_STATUS_C,
    fsa.PRC_ID,
    fsa.DEPARTMENT_ID,
    fsa.APPT_DTTM,
    fsa.APPT_LENGTH,
    fsa.SAME_DAY_YN
FROM F_SCHED_APPT fsa
INNER JOIN date_filtered_enc dfe
    ON fsa.PAT_ENC_CSN_ID = dfe.PAT_ENC_CSN_ID

/* As a reminder, any information Abridge shares with you related to our internal processes,
including our Epic scripts and queries, is considered confidential information under the services agreement
between your health system and Abridge.
Accordingly, Abridge's information generally may not be shared with third parties. */
