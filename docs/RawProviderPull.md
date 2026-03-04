# RawProviderPull

**Grain:** One row per provider (`PROV_ID`)
**Role in Data Model:** Provider dimension table — no date filter; static reference data
**Source Query:** `SQL/RawProviderPull.sql`

---

## Purpose

Produces a provider dimension table containing one record per provider in the Epic system. This includes all provider types — physicians, APPs, nurses, resources, etc. — filtered only to exclude non-person resources (`PROV_TYPE <> 0`). Used to enrich fact table joins with provider name, specialty, employment status, practice affiliation, and NPI.

---

## Key Tables

| Table | Description | Dictionary Page |
|---|---|---|
| `CLARITY_SER` | Provider record; PK: PROV_ID; Chronicles INI: SER; Epic 2000 | p.94 |
| `CLARITY_SER_2` | Extension of CLARITY_SER; primarily used for NPI; Chronicles INI: SER | p.204 |
| `CLARITY_SER_3` | Extension of CLARITY_SER; used for DEPARTURE_DATE | — |
| `ZC_PRACTICE_NAME` | Practice name code/name lookup | — |
| `ZC_PROVIDER_TYPE` | Provider type code/name lookup | — |
| `SER_MAP` | IntraConnect CID mapping for providers | — |

---

## Output Columns

| Column | Source | Notes |
|---|---|---|
| provider_id | CLARITY_SER | Primary key (PROV_ID) |
| npi | CLARITY_SER_2 | National Provider Identifier |
| provider_type | CLARITY_SER | PROV_TYPE category number |
| is_resident | CLARITY_SER | Resident flag |
| user_id | CLARITY_SER | Associated USER_ID for login-based joins |
| upin | CLARITY_SER | Unique Physician Identification Number (legacy) |
| employment_status | CLARITY_SER | Employment status code |
| clinician_title | CLARITY_SER | Clinician title (MD, DO, NP, PA, etc.) |
| referral_source_type | CLARITY_SER | Referral source type |
| billing_provider_yn | CLARITY_SER | 'Y' if this is a billing provider |
| record_type | CLARITY_SER | Record type for the provider |
| email | CLARITY_SER | Provider email address |
| practice_name_code | CLARITY_SER | Practice name category code |
| practice_name | ZC_PRACTICE_NAME | Practice name |
| revenue_department_id | CLARITY_SER | Revenue department ID |
| provider_type_code | CLARITY_SER | Provider type category code |
| provider_type_name | ZC_PROVIDER_TYPE | Provider type name |
| primary_department_id | CLARITY_SER_2 | Primary department assignment |
| departure_date | CLARITY_SER_3 | Date provider left the organization |
| ser_cid | SER_MAP | IntraConnect CID (remove if not licensed) |

---

## Join Keys

- **From FACT_ENCOUNTER:** `VISIT_PROV_ID` or `ATTND_PROV_ID` → `provider_id`
- **From FACT_NOTES:** `AUTHOR_LINKED_PROV_ID` → `provider_id`
- **From FACT_TRANSACTION:** `ATTENDING_PROV_ID` → `provider_id`
- **From FACT_CDI:** `RECIPIENT_PROV_ID` or `RESPONDING_PROV_ID` → `provider_id`
- **From FACT_SCHEDULE:** `PROV_ID` → `provider_id`

---

## Partner-Configurable Elements

| Element | Location | Default | Notes |
|---|---|---|---|
| Resource exclusion | `WHERE ser.PROV_TYPE <> 0` | Excludes resources | PROV_TYPE = 0 is non-person resource |
| Physician-only filter | Not applied | Not filtered | See notes below |
| IntraConnect join | `SER_MAP` join | Included | Remove if not licensed |

---

## Known Issues & Considerations

### ⚠️ Missing PROV_NAME
The query is currently missing the provider name (`PROV_NAME`) from `CLARITY_SER`. This is one of the most critical fields for human-readable reporting.

**Add to SELECT:**
```sql
, ser.PROV_NAME as provider_name
```

`PROV_NAME` is stored directly in `CLARITY_SER` (Chronicles INI: SER, item 2).

### ℹ️ PROV_TYPE vs PROVIDER_TYPE_C — Two Different Fields
These are frequently confused:
- `PROV_TYPE` (`ser.PROV_TYPE`) — Epic's internal provider type classification. Value `0` = resource (rooms, equipment), non-zero = people/entities. The query filters `PROV_TYPE <> 0` to exclude resources.
- `PROVIDER_TYPE_C` (`ser.PROVIDER_TYPE_C`) — A separate category representing the clinical/administrative type of the provider. `PROVIDER_TYPE_C = '1'` is used in the aggregated queries to filter to physicians only.

**The current query does NOT filter to physicians only** — it returns all non-resource providers (physicians, APPs, nurses, CDI specialists, etc.). This is appropriate for a full dimension table. Apply `PROVIDER_TYPE_C = '1'` filtering in BI views when physician-only analysis is needed.

### ℹ️ All Active and Inactive Providers Are Returned
There is no filter on `departure_date` or provider active status. This means terminated providers are included. In BI, filter to `departure_date IS NULL OR departure_date >= [analysis start date]` to limit to active providers during a given period.

### ℹ️ NPI in CLARITY_SER_2
Per the data dictionary annotation: *"Really only ever used to pull NPI."* The NPI is stored in `CLARITY_SER_2.NPI` — the join to this table is correct and standard practice.

### ℹ️ No Date Filter — Full Dimension Pull
Unlike the fact queries, this query has no date range filter. It should be run periodically (e.g., monthly or on a refresh schedule) to keep the dimension table current with provider additions, changes, and departures.
