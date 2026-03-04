# RawTransactionPull

**Grain:** One row per professional billing transaction (`TX_ID`)
**Role in Data Model:** Billing/financial fact table — joins to FACT_ENCOUNTER via CSN
**Source Query:** `SQL/RawTransactionPull.sql`

---

## Purpose

Produces one record per billing transaction within the configured encounter date range. This is the most complex raw query — it captures CPT codes, wRVU values, billed amounts, collection ratios, hospital account data, and denial information. Intended to replace or supplement the aggregated `AbridgeWRVULOSDenial` query with full transaction-level detail for BI tools.

---

## Key Tables

| Table | Description | Dictionary Page |
|---|---|---|
| `ARPB_TRANSACTIONS` | Professional billing transaction records; PKL: TX_ID; Chronicles INI: ETR | p.75 |
| `V_ARPB_RVU_DATA` | View providing RVU and CPT data per transaction; source: CLARITY_TDL_TRAN | p.226 |
| `V_PAT_ENC` | Encounter view; used for LOS_PROC_CODE | — |
| `ZC_SPECIALTY` | Specialty code/name lookup | — |
| `HSP_ACCOUNT` | Hospital account record; inpatient/facility-level data | — |
| `ARPB_TX_COLL_RATIO` | Collection ratio data per charge transaction; Chronicles INI: ETR | p.72 |
| `INVOICE` | Invoice linking professional billing to hospital account | — |
| `BDC_INFO` | Billing denial and claim data | — |

---

## Output Columns

| Column | Source | Notes |
|---|---|---|
| PAT_ENC_CSN_ID | ARPB_TRANSACTIONS | Encounter join key |
| LOS_PROC_CODE | V_PAT_ENC | Level of service procedure code |
| AMBIENT_FLAG | Derived | 'Y' / 'N' |
| TX_ID | ARPB_TRANSACTIONS | Primary key; unique billing transaction ID |
| CPT_CODE | V_ARPB_RVU_DATA | CPT procedure code |
| PROCEDURE_CODE | V_ARPB_RVU_DATA | Internal procedure code |
| PROCEDURE_NAME | V_ARPB_RVU_DATA | Procedure name |
| PROCEDURE_QUANTITY | V_ARPB_RVU_DATA | Units billed |
| billed_amount | V_ARPB_RVU_DATA | Amount billed (AMOUNT alias) |
| RVU_WORK | V_ARPB_RVU_DATA | Work RVU value |
| LOC_ID | ARPB_TRANSACTIONS | Location ID |
| SERVICE_AREA_ID | ARPB_TRANSACTIONS | Service area ID |
| PRIMARY_DX_ID | ARPB_TRANSACTIONS | Primary diagnosis ID on the transaction |
| prov_specialty_code | ARPB_TRANSACTIONS | Provider specialty code |
| prov_specialty_name | ZC_SPECIALTY | Provider specialty name |
| BILL_AREA_NAME | V_ARPB_RVU_DATA | Billing area name |
| HSP_ACCOUNT_ID | HSP_ACCOUNT | Hospital account ID |
| HSP_BASECLS_HA_C | HSP_ACCOUNT | Base class of the hospital account |
| ACCT_BILLED_DATE | HSP_ACCOUNT | Date the account was billed |
| ACCT_FIN_CLASS_C | HSP_ACCOUNT | Financial class of the account |
| ATTENDING_PROV_ID | HSP_ACCOUNT | Attending provider on the hospital account |
| HSP_ADM_DATE_TIME | HSP_ACCOUNT | Hospital admission datetime |
| DISCH_DATE_TIME | HSP_ACCOUNT | Hospital discharge datetime |
| ER_ADMIT_DATE_TIME | HSP_ACCOUNT | ER admission datetime |
| ER_DSCHG_DATE_TIME | HSP_ACCOUNT | ER discharge datetime |
| FINAL_DRG_ID | HSP_ACCOUNT | Final DRG assigned to the account |
| NET_COLL_RATIO | ARPB_TX_COLL_RATIO | Net collection ratio for the charge |
| ACTUAL_AR_COLLECTIONS | ARPB_TX_COLL_RATIO | Actual AR collected (numerator) |
| EXPECTED_AR_COLLECTIONS | ARPB_TX_COLL_RATIO | Expected AR to be collected (denominator) |
| BDC_NAME | BDC_INFO | Billing denial/claim name |
| BDC_RECORD_TYPE | BDC_INFO | Type of BDC record |
| BDC_CREATE_DATE | BDC_INFO | Date denial/claim was created |
| BDC_COMPLETE_VOID_DATE | BDC_INFO | Date denial/claim was resolved or voided |
| DENIAL_CATEGORY_C | BDC_INFO | Denial category code |
| IS_INITIAL_DENIAL_YN | BDC_INFO | Whether this is the initial denial |

---

## Join Keys

- **To FACT_ENCOUNTER:** `PAT_ENC_CSN_ID`
- **To DIM_FACILITY:** `LOC_ID` → `DEPARTMENT_ID`
- **To DIM_PROVIDER:** `ATTENDING_PROV_ID` → `PROV_ID`
- **Internal:** `TX_ID` links ARPB_TRANSACTIONS → V_ARPB_RVU_DATA → ARPB_TX_COLL_RATIO
- **Internal:** `HSP_ACCOUNT_ID` links to `INVOICE` → `BDC_INFO`

---

## Partner-Configurable Elements

| Element | Location | Default | Notes |
|---|---|---|---|
| Date range | `DATE_PARAMS` CTE | 2023-04-01 to yesterday | Filter via encounter date (CONTACT_DATE) |
| Encounter types | `date_filtered_enc` | 3, 76, 101 | Match with RawEncounterPull |

---

## Known Issues & Considerations

### ℹ️ Transaction Types in ARPB_TRANSACTIONS
`ARPB_TRANSACTIONS` contains all transaction types, not just charges:
- 1 = Charge (wRVU data only available here)
- 2 = Payment
- 3 = Adjustment
- 4–7 = Claim-related transactions

`V_ARPB_RVU_DATA` only joins meaningfully for charge transactions (TRAN_TYPE = 1). For non-charge rows, `CPT_CODE`, `RVU_WORK`, `billed_amount` will be NULL. **Consider filtering to `TRAN_TYPE = 1` if only analyzing charges and wRVUs.**

### ℹ️ ARPB_TX_COLL_RATIO — Charges Only
Per the data dictionary: *"These values are only applicable for charge transactions."* The NET_COLL_RATIO and collections columns will be NULL for payment and adjustment rows.

### ℹ️ Fan-Out Risk: INVOICE → BDC_INFO
An invoice can have multiple denial events. If `BDC_INFO` has multiple records per `INVOICE_ID`, each transaction will fan out into multiple rows — one per denial.

**Recommended approach:** If denial analysis is the goal, build a separate `FACT_DENIAL` table from `BDC_INFO` joined to `INVOICE`. Or filter to `IS_INITIAL_DENIAL_YN = 'Y'` to limit to one denial per invoice.

### ℹ️ Missing Service Date
The transaction date is not directly in the SELECT output — `CONTACT_DATE` is available via the `date_filtered_enc` join but is not included in the final SELECT. Consider adding `dfe.CONTACT_DATE` to the output for easier date-based analysis without requiring a join back to the encounter table.

### ℹ️ wRVU vs Total RVU
`RVU_WORK` is the work RVU only. Total RVU (work + practice expense + malpractice) is not in this query. For full RVU analysis, `V_ARPB_RVU_DATA` contains additional RVU components — check the view for additional columns if needed.
