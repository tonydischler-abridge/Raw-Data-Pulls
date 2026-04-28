/*
================================================================================
  RawTransactionPull_V2_2026-04-28.sql
  Grain:    1 row per professional billing transaction (TX_ID)
  Purpose:  Billing/financial fact table — CPT codes, wRVUs, collections, denials

  V2 CHANGES:
    - Removed ambient detection CTEs (SDE, NAS, ATTR, DXR, ALL_AMBIENT)
      and AMBIENT_FLAG column. Ambient status is now derived by joining
      to RawEncounterPull on PAT_ENC_CSN_ID in the BI layer.

  ⚠️  INVOICE → BDC_INFO can fan-out if multiple denial records exist per invoice.
      Consider filtering to IS_INITIAL_DENIAL_YN = 'Y' or building a separate
      denial table downstream.
  ℹ️  V_ARPB_RVU_DATA and ARPB_TX_COLL_RATIO only populate for charge transactions
      (TRAN_TYPE = 1). Other transaction types (payments, adjustments, etc.) will
      have NULLs in those columns.

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
    arpb.PAT_ENC_CSN_ID,
    penc.LOS_PROC_CODE,
    arpb.TX_ID,
    rvu.CPT_CODE,
    rvu.PROCEDURE_CODE,
    rvu.PROCEDURE_NAME,
    rvu.PROCEDURE_QUANTITY,
    rvu.AMOUNT billed_amount,
    rvu.RVU_WORK,
    arpb.LOC_ID,
    arpb.SERVICE_AREA_ID,
    arpb.PRIMARY_DX_ID,
    arpb.PROV_SPECIALTY_C prov_specialty_code,
    zsp.NAME prov_specialty_name,
    rvu.BILL_AREA_NAME,
    ha.HSP_ACCOUNT_ID,
    ha.HSP_BASECLS_HA_C,
    ha.ACCT_BILLED_DATE,
    ha.ACCT_FIN_CLASS_C,
    ha.ATTENDING_PROV_ID,
    ha.HSP_ADM_DATE_TIME,
    ha.DISCH_DATE_TIME,
    ha.ER_ADMIT_DATE_TIME,
    ha.ER_DSCHG_DATE_TIME,
    ha.FINAL_DRG_ID,
    atcr.NET_COLL_RATIO,
    atcr.ACTUAL_AR_COLLECTIONS,
    atcr.EXPECTED_AR_COLLECTIONS,
    bdc.BDC_NAME,
    bdc.RECORD_TYPE_C AS BDC_RECORD_TYPE,
    bdc.BDC_CREATE_DATE,
    bdc.BDC_COMPLETE_VOID_DATE,
    bdc.DENIAL_CATEGORY_C,
    bdc.IS_INITIAL_DENIAL_YN
FROM ARPB_TRANSACTIONS arpb
INNER JOIN date_filtered_enc dfe
    ON arpb.PAT_ENC_CSN_ID = dfe.PAT_ENC_CSN_ID
LEFT JOIN V_ARPB_RVU_DATA rvu
    ON arpb.TX_ID = rvu.TRANSACTION_ID
LEFT JOIN V_PAT_ENC penc
    ON arpb.PAT_ENC_CSN_ID = penc.PAT_ENC_CSN_ID
LEFT JOIN ZC_SPECIALTY zsp
    ON arpb.PROV_SPECIALTY_C = zsp.SPECIALTY_C
LEFT JOIN HSP_ACCOUNT ha
    ON penc.HSP_ACCOUNT_ID = ha.HSP_ACCOUNT_ID
LEFT JOIN ARPB_TX_COLL_RATIO atcr
    ON arpb.TX_ID = atcr.TX_ID
LEFT JOIN INVOICE inv
    ON ha.HSP_ACCOUNT_ID = inv.PB_HOSP_ACT_ID
LEFT JOIN BDC_INFO bdc
    ON inv.INVOICE_ID = bdc.PB_INVOICE_ID

/* As a reminder, any information Abridge shares with you related to our internal processes,
including our Epic scripts and queries, is considered confidential information under the services agreement
between your health system and Abridge.
Accordingly, Abridge's information generally may not be shared with third parties. */
