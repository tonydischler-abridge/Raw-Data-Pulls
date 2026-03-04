# Abridge Raw Data Exports — Architecture Guide

> **Purpose:** This folder contains the raw-grain SQL extraction queries and documentation for Abridge's BI-ready data pipeline. Each query produces a one-row-per-grain output intended to be loaded into a reporting database and connected to a BI tool (Tableau, Power BI, Looker, etc.).

---

## Why Raw Queries?

The aggregated queries (e.g., `AbridgeTimeInNotes`, `AbridgeWRVULOSDenial`) produce daily-level summaries by provider and date — useful for Excel/pivot analysis but too coarse for flexible BI exploration. The raw queries produce **one row per atomic event** so that analysts can slice, filter, and re-aggregate any way they need downstream.

---

## Data Model Overview

The raw exports follow a **star schema** pattern. Two dimension tables provide stable reference data; five fact tables contain the event-level data, all joinable via `PAT_ENC_CSN_ID`.

```
                         ┌─────────────────────┐
                         │   DIM_PROVIDER       │
                         │  (RawProviderPull)   │
                         │   PK: PROV_ID        │
                         └──────────┬──────────┘
                                    │ PROV_ID
┌─────────────────────┐             │             ┌─────────────────────┐
│   DIM_FACILITY       │            │             │   FACT_TRANSACTION   │
│  (RawFacilityPull)  │            │             │  (RawTransactionPull)│
│   PK: DEPARTMENT_ID │            │             │   PK: TX_ID          │
└──────────┬──────────┘            │             │   FK: PAT_ENC_CSN_ID │
           │ DEPARTMENT_ID         │             └──────────┬──────────┘
           │              ┌────────┴──────────┐             │
           └──────────────►  FACT_ENCOUNTER    ◄────────────┘
                          │  (RawEncounterPull)│
                          │  PK: PAT_ENC_CSN_ID│◄──── FACT_DIAGNOSIS
                          └────────┬──────────┘      (RawDiagnosisPull)
                                   │                  PK: CSN + LINE
                                   │
                          ┌────────┴──────────┐◄──── FACT_NOTES
                          │   (CSN join key)  │      (RawNotesPull)
                          └────────┬──────────┘      PK: NOTE_ID
                                   │
                         ┌─────────┼──────────┐
                         │         │          │
                    FACT_SCHEDULE  FACT_ACTIVITY  FACT_CDI
                    (Schedule)     (Activity)     (CDI)
                    PK: CSN        PK: UAL_KEY    PK: QUERY_IDENT
```

### Join Key Summary

| From Table | Join Column | To Table | Join Column |
|---|---|---|---|
| FACT_ENCOUNTER | PAT_ENC_CSN_ID | FACT_TRANSACTION | PAT_ENC_CSN_ID |
| FACT_ENCOUNTER | PAT_ENC_CSN_ID | FACT_DIAGNOSIS | PAT_ENC_CSN_ID |
| FACT_ENCOUNTER | PAT_ENC_CSN_ID | FACT_NOTES | PAT_ENC_CSN_ID |
| FACT_ENCOUNTER | PAT_ENC_CSN_ID | FACT_SCHEDULE | PAT_ENC_CSN_ID |
| FACT_ENCOUNTER | PAT_ENC_CSN_ID | FACT_ACTIVITY | PAT_ENC_CSN_ID |
| FACT_ENCOUNTER | PAT_ENC_CSN_ID | FACT_CDI | PAT_ENC_CSN_ID |
| FACT_ENCOUNTER | DEPARTMENT_ID | DIM_FACILITY | DEPARTMENT_ID |
| FACT_ENCOUNTER | VISIT_PROV_ID | DIM_PROVIDER | PROV_ID |
| FACT_TRANSACTION | LOC_ID | DIM_FACILITY | DEPARTMENT_ID |
| FACT_TRANSACTION | ATTENDING_PROV_ID | DIM_PROVIDER | PROV_ID |
| FACT_NOTES | AUTHOR_LINKED_PROV_ID | DIM_PROVIDER | PROV_ID |

> **Note:** `PAT_ENC_CSN_ID` (Contact Serial Number) is the universal encounter identifier across all Epic Clarity fact tables.

---

## Query Inventory

| File | Grain | Key Table | Rows Per Encounter | Dimension? | Docs |
|---|---|---|---|---|---|
| [`RawEncounterPull.sql`](sql/RawEncounterPull.sql) | 1 row / encounter | PAT_ENC | 1 | No | [docs](docs/RawEncounterPull.md) |
| [`RawTransactionPull.sql`](sql/RawTransactionPull.sql) | 1 row / billing transaction | ARPB_TRANSACTIONS | Many | No | [docs](docs/RawTransactionPull.md) |
| [`RawDiagnosisPull.sql`](sql/RawDiagnosisPull.sql) | 1 row / diagnosis | PAT_ENC_DX | Many | No | [docs](docs/RawDiagnosisPull.md) |
| [`RawNotesPull.sql`](sql/RawNotesPull.sql) | 1 row / note | HNO_INFO | Many | No | [docs](docs/RawNotesPull.md) |
| [`RawSchedulePull.sql`](sql/RawSchedulePull.sql) | 1 row / appointment | F_SCHED_APPT | 1 | No | [docs](docs/RawSchedulePull.md) |
| [`RawActivityPull.sql`](sql/RawActivityPull.sql) | 1 row / UAL activity-hour | UAL_ACTIVITY_HOURS | Many | No | [docs](docs/RawActivityPull.md) |
| [`RawCDIPull.sql`](sql/RawCDIPull.sql) | 1 row / CDI query | V_CLIN_DOC_QUERY_INFO | Many (if CDI active) | No | [docs](docs/RawCDIPull.md) |
| [`RawProviderPull.sql`](sql/RawProviderPull.sql) | 1 row / provider | CLARITY_SER | N/A | Yes | [docs](docs/RawProviderPull.md) |
| [`RawFacilityPull.sql`](sql/RawFacilityPull.sql) | 1 row / department | CLARITY_DEP | N/A | Yes | [docs](docs/RawFacilityPull.md) |

---

## Ambient Detection

Every time-filtered fact query (Encounter, Transaction, Diagnosis, Notes, Schedule, Activity, CDI) includes an `AMBIENT_FLAG` column (`'Y'` or `'N'`) to indicate whether Abridge was used during that encounter. This flag is derived from **four independent detection methods** that are UNIONed together — if any one method fires, the encounter is flagged.

See **[docs/AmbientDetectionLogic.md](docs/AmbientDetectionLogic.md)** for full documentation of each method, the tables used, and considerations for partner configuration.

---

## Date Range Configuration

All time-filtered queries use a common `DATE_PARAMS` CTE at the top:

```sql
DATE_PARAMS AS (
    SELECT
        CAST('2023-04-01' AS date) AS START_DATE,
        DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS END_DATE
)
```

**To configure:**
- `START_DATE`: Set to the partner's Abridge go-live date
- `END_DATE`: Defaults to yesterday; adjust as needed for historical pulls

The queries then filter `PAT_ENC.CONTACT_DATE` against these bounds via the `date_filtered_enc` CTE.

---

## Encounter Type Filter

The `date_filtered_enc` CTE also restricts to specific encounter types:

```sql
AND e.ENC_TYPE_C IN (3, 76, 101)  -- hospital, telemedicine, office visit
AND (e.APPT_STATUS_C IN (2, 6) OR e.APPT_STATUS_C IS NULL)
```

**`ENC_TYPE_C` values:** 3 = Hospital, 76 = Telemedicine, 101 = Office Visit
**`APPT_STATUS_C` values:** 2 = Completed, 6 = Arrived

> **Partner Note:** Review these values with each partner. Some may use additional or different encounter type codes. Some partners may want to add 4 (Telephone) or 50 (Nurse Only) for broader coverage.

---

## Recommended Database Loading Order

When loading to a relational database, load in this order to respect foreign key dependencies:

1. **DIM_PROVIDER** (RawProviderPull) — no FK dependencies
2. **DIM_FACILITY** (RawFacilityPull) — no FK dependencies
3. **FACT_ENCOUNTER** (RawEncounterPull) — central fact table; FK → DIM_PROVIDER, DIM_FACILITY
4. **FACT_SCHEDULE** (RawSchedulePull) — FK → FACT_ENCOUNTER
5. **FACT_DIAGNOSIS** (RawDiagnosisPull) — FK → FACT_ENCOUNTER
6. **FACT_NOTES** (RawNotesPull) — FK → FACT_ENCOUNTER
7. **FACT_ACTIVITY** (RawActivityPull) — FK → FACT_ENCOUNTER
8. **FACT_TRANSACTION** (RawTransactionPull) — FK → FACT_ENCOUNTER
9. **FACT_CDI** (RawCDIPull) — FK → FACT_ENCOUNTER

---

## IntraConnect / Cogito Cloud Notes

Several queries include an optional `CID` (Community ID) column that requires the IntraConnect license:

```sql
LEFT JOIN SER_MAP map -- remove if not licensed for Interconnect
    ON map.PROV_ID = ser.PROV_ID
```

> If the partner is **not** licensed for IntraConnect, remove all `SER_MAP` joins and the `map.CID` select columns. Affected queries: `RawProviderPull`, `RawNotesPull`.

---

## Known Issues / Open Items

| Query | Issue | Status |
|---|---|---|
| RawFacilityPull | Source query had typo `CLARITTY_DEP` (double T) — **fixed in SQL folder** | ✅ Fixed |
| RawEncounterPull | LEFT JOIN to HNO_INFO + NOTE_AMBIENT_SECTIONS in SELECT clause risks fan-out if multiple notes exist per encounter | ⚠️ Review |
| RawEncounterPull | Uses `ZC_ENC_TYPE` but aggregated queries use `ZC_DISP_ENC_TYPE` — may return slightly different names | ⚠️ Review |
| RawProviderPull | Was missing `PROV_NAME` column — **added in this version** | ✅ Fixed |
| RawNotesPull | NOTE_ATTRIBUTION join could fan-out if multiple attribution records exist per note (need LINE handling) | ⚠️ Review |
| All fact queries | No explicit physician-only filter (`PROVIDER_TYPE_C = '1'`) at the raw level — filtering may need to happen in BI layer | ℹ️ By design |

---

## Repository Structure

```
Raw-Data-Pulls/
├── README.md                          ← This file
├── sql/
│   ├── RawEncounterPull.sql           ← Core encounter fact
│   ├── RawTransactionPull.sql         ← Billing/financial fact
│   ├── RawDiagnosisPull.sql           ← Encounter diagnosis fact
│   ├── RawNotesPull.sql               ← Clinical note metadata fact
│   ├── RawSchedulePull.sql            ← Appointment scheduling fact
│   ├── RawActivityPull.sql            ← EHR user activity fact
│   ├── RawCDIPull.sql                 ← CDI query fact
│   ├── RawProviderPull.sql            ← Provider dimension
│   └── RawFacilityPull.sql            ← Facility/department dimension
└── docs/
    ├── AmbientDetectionLogic.md       ← Shared ambient detection documentation
    ├── RawEncounterPull.md
    ├── RawTransactionPull.md
    ├── RawDiagnosisPull.md
    ├── RawNotesPull.md
    ├── RawSchedulePull.md
    ├── RawActivityPull.md
    ├── RawCDIPull.md
    ├── RawProviderPull.md
    └── RawFacilityPull.md
```

---

*Last updated: 2026-03-04 | EHR Data Lead, Abridge Partner Experience*
