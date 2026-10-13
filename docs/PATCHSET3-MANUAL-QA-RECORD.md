# Patchset-0003 — Human QA Records (Self-Reported, Never Approval)

**Status: read-only source/developer tool. No genuine test results have been collected or verified.**

This workflow records only what a person **claims to have observed** when using an independently prepared, separately authorised test client. It cannot observe World of Warcraft, inspect MPQs, identify testers, authenticate their results, take backups or approve installation or distribution.

Use the existing [manual game QA matrix](PATCHSET3-MANUAL-QA-PLAN.md) for the six valid optional patch combinations (none, U, J, J+U, C, C+U) and the two negative C+J / C+J+U selection tests. Required V and Z are present in every valid case.

## Step 1 — Print a blank template

From a trusted **source repository** checkout with Python 3.12:

```powershell
python .\tools\review_patchset3_manual_record.py --proposal .\tests\fixtures\synthetic-patch-proposal-v3.json --release-snapshot .\tests\fixtures\public-release-metadata-v1.json --print-template
```

This prints a JSON template on screen. It is entirely **NOT_TESTED**, and contains a fingerprint tied to the exact unperformed test plan. The example proposal contains a deliberately **fake V checksum**, not a currently released patch or a real test environment.

If you choose to keep a local, blank JSON file, redirect the same command into a private working folder outside the WoW client or GitHub source checkout, after making your normal backups. Example, using a folder you have deliberately created yourself:

```powershell
python .\tools\review_patchset3_manual_record.py --proposal .\tests\fixtures\synthetic-patch-proposal-v3.json --release-snapshot .\tests\fixtures\public-release-metadata-v1.json --print-template > .\my-local-manual-qa-template.json
```

**The program itself writes nothing**; your shell redirects the console text if you explicitly request it. Do not put real game archives, personal paths, account names, character names, screenshots containing private data, or arbitrary notes in the record. Only edit a copy when you have genuinely completed independent manual checks on a disposable test environment and have separately authorised that test setup.

## Step 2 — Record the outcome of each check

Keep all **six valid** cases and **two negative** C/J-mutex cases, in their existing order. Valid cases contain the complete ordered list of check IDs from the planner; do not omit or rename any check.

| Status | Meaning | What must be recorded |
| --- | --- | --- |
| `NOT_TESTED` | Not attempted | Every individual check remains NOT_TESTED; no issue code |
| `PASS` | Human reports all steps were completed successfully | **Every** individual check must say PASS; no issue code |
| `FAIL` | Human observed an actual problem | At least one check FAIL; select a fixed applicable failure code |
| `BLOCKED` | Could not complete the check safely | At least one check NOT_TESTED/BLOCKED; no individual FAIL; select a fixed blocker code |

The two negative cases have a single overall outcome, not individual checks. They mean **the attempted selection of both C and J** was either correctly refused (self-reported PASS), incorrectly allowed (self-reported FAIL with `mutex_did_not_reject`), impossible to test (BLOCKED) or not attempted (NOT_TESTED). **Never deliberately install both J and C into a working client.**

Choose fixed issue codes only; personal/free-text notes are **not permitted**. Available failure codes are `client_startup_failure`, `realm_or_character_entry_failure`, `visual_audio_mismatch`, `loading_overlap_problem`, `unexpected_file_change`, `mutex_did_not_reject`, `other_observed_failure`. Available blockers are `no_test_environment`, `no_protected_backup`, `rights_unresolved`, `missing_required_patch`, `incomplete_checks`, `other_blocker`. `issue_codes` must be alphabetically sorted and contain no duplicate values.

Once **any** case has an outcome beyond NOT_TESTED, also supply the following **self-reported context**: `observed_client_build: 12340`, `observed_locale: "enUS"`, `reported_disposable_test_environment: true`, `reported_human_observation: true`, and a genuine ISO `reported_utc_date` in `YYYY-MM-DD`. Do not populate these in an untouched blank record. These fields are statements by the person completing the record, **not independent verification**.

## Step 3 — Review your local record (no writes)

```powershell
python .\tools\review_patchset3_manual_record.py --proposal .\tests\fixtures\synthetic-patch-proposal-v3.json --release-snapshot .\tests\fixtures\public-release-metadata-v1.json --record .\my-local-manual-qa-template.json
```

The tool rejects malformed/oversized records, duplicate JSON keys, unsafe links, unapproved fields, missing/reordered cases, invented check IDs, wrongly marked passes, contradictory failure states, invalid build/date declarations, and plans that no longer match the bound plan SHA-256. It returns only fixed case IDs, counts and fixed status labels; it does **not** print your record's date, checksum, paths or other private data. Exit `0` means **the self-report is internally consistent only**; exit `2` means blocked/invalid, not a failed game test.

The matching plan SHA-256 is a **locally reproducible fingerprint against accidental mismatches**, not a digital signature, independent timestamp, rightsholder licence, source authentication, trustworthy owner approval or monotonic anti-rollback protection. A malicious or mistaken reporter can submit coherent false results and cannot be detected by this reviewer.

## What does NOT change

- The six valid game tests and both C/J rejection tests are **not performed by this software**. CI only uses generated fake records.
- A complete self-reported eight-for-eight pass still says `UNTRUSTED_SELF_REPORT_ONLY_MANUAL_VERIFICATION_REQUIRED`; independent verification and owner decision are **not provided**.
- Physical Windows 100/125/150/200% DPI, High Contrast, keyboard and screen-reader results are separate and still **NOT TESTED**.
- Real MPQ source provenance, copyright/redistribution rights, original client plus all accounts' WTF backups, different storage failure domains, crash-safe recovery and authenticated one-use owner consent remain **BLOCKED**.
- No actual `patchset-0003`, user client, MPQ, installer, manifest, SavedVariables, recovery record or public release is created or changed.

**Do not upload private records to public GitHub issues or commit them to the repository.** A successfully parsed record is not permission to modify a real WoW client.
