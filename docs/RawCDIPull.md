# RawCDIPull

**Grain:** One row per CDI query (`QUERY_IDENT`)
**Role in Data Model:** CDI fact table — joins to FACT_ENCOUNTER via CSN
**Source Query:** `SQL/RawCDIPull.sql`

---

## Purpose

Produces one record per clinical documentation improvement (CDI) query associated with encounters in the configured date range. Captures query details including type, recipient and responding providers, NPI, status, outcome, creation timing, and total time assigned. Intended to replace the aggregated `AbridgeCDIQuery` query with full query-level detail for BI tools.

---

## Key Tables

| Table | Description | Dictionary Page |
|---|---|---|
| `V_CLIN_DOC_QUERY_INFO` | View providing CDI query details; one row per CDI query; Chronicles INI: CDQ | p.230 |

---

## Output Columns

| Column | Source | Notes |
|---|---|---|
| QUERY_IDENT | V_CLIN_DOC_QUERY_INFO | Unique CDI query identifier (primary key) |
| PAT_ENC_CSN_ID | V_CLIN_DOC_QUERY_INFO | Encounter join key |
| AMBIENT_FLAG | Derived | 'Y' / 'N' |
| cdi_query_type | V_CLIN_DOC_QUERY_INFO | Type of CDI query |
| coding_query_type | V_CLIN_DOC_QUERY_INFO | Coding-specific query type |
| RECIPIENT_PROV_ID | V_CLIN_DOC_QUERY_INFO | Provider who received the query |
| PROV_NAME | V_CLIN_DOC_QUERY_INFO | Name of the recipient provider |
| RESPONDING_PROV_ID | V_CLIN_DOC_QUERY_INFO | Provider who responded to the query |
| npi_recipient | V_CLIN_DOC_QUERY_INFO | NPI of the recipient provider |
| npi_responding | V_CLIN_DOC_QUERY_INFO | NPI of the responding provider |
| QUERY_STATUS_NAME | V_CLIN_DOC_QUERY_INFO | Status of the CDI query (e.g., Open, Answered) |
| NLP_STATUS_NAME | V_CLIN_DOC_QUERY_INFO | NLP-assisted query status name |
| QUERY_OUTCOME_NAME | V_CLIN_DOC_QUERY_INFO | Outcome of the query (e.g., Agree, Disagree) |
| CREATION_DTTM | V_CLIN_DOC_QUERY_INFO | Datetime the query was created |
| UPDATE_DTTM | V_CLIN_DOC_QUERY_INFO | Datetime the query was last updated |
| TOTAL_TIME_ASSIGNED | V_CLIN_DOC_QUERY_INFO | Total time the query has been assigned |

> **Note:** Column names prefixed with `npi_` are aliases — verify the actual column names in the view match what's defined in your partner's Clarity environment.

---

## Join Keys

- **To FACT_ENCOUNTER:** `PAT_ENC_CSN_ID`
- **To DIM_PROVIDER:** `RECIPIENT_PROV_ID` or `RESPONDING_PROV_ID` → `PROV_ID`

---

## Partner-Configurable Elements

| Element | Location | Default | Notes |
|---|---|---|---|
| Date range | `DATE_PARAMS` CTE | 2023-04-01 to yesterday | Filter is on encounter CONTACT_DATE |
| Encounter types | `date_filtered_enc` | 3, 76, 101 | Match across pulls |

---

## Known Issues & Considerations

### ℹ️ CDI Module Dependency
This query returns meaningful data only at partners where the Epic CDI (Clinical Documentation Improvement) module is actively used. Partners without CDI queries in their workflow will return zero rows. Confirm CDI adoption with the partner before including this table in their reporting database.

### ℹ️ Many CDI Queries per Encounter Are Normal
Unlike Encounter or Schedule (1 row expected per CSN), CDI queries can have multiple records per encounter — each query event is its own row. This is expected behavior; join carefully to avoid double-counting encounters when combining with other fact tables.

### ℹ️ V_CLIN_DOC_QUERY_INFO is a View
This is a view (not a base Clarity extract table), meaning it may join multiple underlying tables. Performance can vary across environments. If query runtime is an issue, check whether the underlying CDQ tables can be queried directly.

### ℹ️ NLP Status
The `NLP_STATUS_NAME` column reflects AI-assisted query suggestions (Epic's NLP layer, not Abridge). This can be useful for understanding how CDI workflows are being assisted by both Epic's native NLP and Abridge's ambient capabilities.

### ℹ️ TOTAL_TIME_ASSIGNED
This field represents total time the query has been in an assigned state. It is a measure of query workflow efficiency — shorter times generally indicate faster physician response to CDI queries.
