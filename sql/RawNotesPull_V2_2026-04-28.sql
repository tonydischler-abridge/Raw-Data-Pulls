/*
================================================================================
  RawNotesPull_V2_2026-04-28.sql
  Grain:    1 row per note attribution per note (NOTE_ID + NOTEATTR_SOURCE_C)
  Purpose:  Clinical note metadata — authorship, timing, ambient attribution

  V2 CHANGES:
    - Removed ambient detection CTEs (SDE, NAS, ATTR, DXR, ALL_AMBIENT)
      and AMBIENT_FLAG column. Ambient status is now derived by joining
      to RawEncounterPull on PAT_ENC_CSN_ID in the BI layer.

  ⚠️  NOTE_ATTRIBUTION is LINE-level (PK: NOTE_ID + LINE). A note with multiple
      attribution sources will produce multiple rows per NOTE_ID. Filter to
      NOTEATTR_SOURCE_C = 25 to isolate ambient-attributed notes.
  ⚠️  NOTE_WRITE_TIMING is also LINE-level. The join on WRITE_USER_ID = ENTRY_USER_ID
      reduces fan-out to the most relevant edit session, but verify per partner.
  ℹ️  V_NOTE_CHARACTERISTICS only populates for notes AFTER ambient attribution
      was enabled. Older notes will have NULLs in AUTHOR_SUM, TOTAL_NOTE_LENGTH, etc.
  ℹ️  SER_MAP (author_linked_prov_cid) requires IntraConnect license — remove if
      partner is not licensed.

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

select
    hno.NOTE_ID
    , hno.PAT_ENC_CSN_ID
    , hno.NOTE_TYPE_NOADD_C note_type_code
    , znt.NAME note_type_name
    , hno.NOTE_SOURCE_C note_source_code
    , zns.NAME note_source_name
    , hno.ENTRY_USER_ID
    , hno.ENTRY_DATETIME
    , nwt.LENGTH_OF_EDIT --note_length_of_edit_seconds
    , nwt.WRITE_USER_ID --User for given editing sessions
    , vnc.AUTHOR_SUM
    , vnc.TOTAL_NOTE_LENGTH
    , vnc.NOTE_FILE_DTTM
    , vnc.DATE_OF_SERVICE_DTTM
    , vnc.AUTHOR_LINKED_PROV_ID
    , map.CID author_linked_prov_cid
    , vnc.AUTHOR_LOGIN_DEPARTMENT_ID
    , vnc.AUTHOR_LOGIN_DEPARTMENT_NAME
    , vnc.VOICE_RECOGNITION_SUM
    , natr.NOTEATTR_SOURCE_C note_attribution_source_code
    , znsr.NAME note_attribution_source_name
    , natr.NOTEATTR_CHAR_COUNT
from HNO_INFO hno
LEFT JOIN PAT_ENC penc
    ON hno.PAT_ENC_CSN_ID = penc.PAT_ENC_CSN_ID
left join ZC_NOTE_TYPE znt
    on hno.NOTE_TYPE_NOADD_C = znt.NOTE_TYPE_C
left join ZC_NOTE_SOURCE zns
    on hno.NOTE_SOURCE_C = zns.NOTE_SOURCE_C
LEFT JOIN NOTE_WRITE_TIMING nwt
    ON nwt.NOTE_ID = hno.NOTE_ID and nwt.WRITE_USER_ID = hno.ENTRY_USER_ID
LEFT JOIN V_NOTE_CHARACTERISTICS vnc
    ON vnc.NOTE_ID = hno.NOTE_ID
LEFT JOIN NOTE_ATTRIBUTION natr
    ON natr.NOTE_ID = hno.NOTE_ID
LEFT JOIN SER_MAP map
    ON vnc.AUTHOR_LINKED_PROV_ID = map.INTERNAL_ID
LEFT JOIN ZC_NOTEATTR_SOURCE znsr
    ON natr.NOTEATTR_SOURCE_C = znsr.NOTEATTR_SOURCE_C
WHERE hno.PAT_ENC_CSN_ID IN (
    SELECT PAT_ENC_CSN_ID FROM date_filtered_enc
)

/* As a reminder, any information Abridge shares with you related to our internal processes,
including our Epic scripts and queries, is considered confidential information under the services agreement
between your health system and Abridge.
Accordingly, Abridge's information generally may not be shared with third parties. */
