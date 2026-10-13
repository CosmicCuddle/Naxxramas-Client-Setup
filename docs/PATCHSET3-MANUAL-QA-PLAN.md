# Hypothetical Patchset-0003 — Manual Game QA Plan

**Status:** planning only. No proposed version has been created, approved, installed, or tested in WoW. All observations below are **NOT TESTED** until recorded by a human on a separately protected test client.

This builds on the strict [metadata proposal reviewer](PATCH-PROPOSAL-EVIDENCE.md), which itself checks only historical policy fingerprints, the caller's claimed before/after values and a supplied public GitHub release metadata snapshot. Matching a published hash does **not** authenticate the file, prove compatibility or authorise publishing it.

## Generate a synthetic example

In a trusted **source checkout**, using Python 3.12:

```powershell
python .\tools\plan_patchset3_manual_qa.py --proposal .\tests\fixtures\synthetic-patch-proposal-v3.json --release-snapshot .\tests\fixtures\public-release-metadata-v1.json
```

The hypothetical V hash in this test is **not** an actual new patch release. This command reads checked-in metadata only, creates no file and produces a JSON **plan** on the console. It does not access WoW, save screenshots, download any MPQ, generate a backup or run the listed tests.

For a future owner-supplied metadata proposal, the same two input flags can point at an existing private proposal and an existing separately captured release-metadata JSON. Neither should contain personal client paths or character data. An invalid/stale/missing-V-or-Z proposal is refused before any plan is generated.

## Mandatory test matrix

**V + Z must be present in every case** and all tests start NOT TESTED. J and C are **mutually exclusive** login replacements; U is independently selectable.

| Case ID | Required | Optional files selected | What a human must inspect | Status |
| --- | --- | --- | --- | --- |
| `base` | V, Z | None | Standard login, realm/character entry and gameplay | **NOT TESTED** |
| `u` | V, Z | U | Standard login plus Eastern Kingdoms/Kalimdor loading screens (normal/widescreen) | **NOT TESTED** |
| `j` | V, Z | J | Vanilla login art/buttons/music without U | **NOT TESTED** |
| `j-u` | V, Z | J and U | Vanilla login plus both overlapping loading texture paths and actual load screens | **NOT TESTED** |
| `c` | V, Z | C | Burning Crusade Dark Portal login art/buttons/music without U | **NOT TESTED** |
| `c-u` | V, Z | C and U | Burning Crusade login with independently enabled U loading screens | **NOT TESTED** |

In **every valid scenario**, use the intended WoW 3.3.5a build 12340 enUS test client; confirm both required patch references are present, that the client starts and enters the intended realm/character, and that no unexpected files or character settings were changed. Monitor game and server errors, with particular attention to modified DBC, spell, models or sound dependencies where relevant. Technical code checks or CI never substitute for actual in-game observations.

### Two mandatory negative tests

| Attempted optional combination | Required outcome | Status |
| --- | --- | --- |
| J and C | **Reject** selection; no file writes | **NOT TESTED** |
| J, C and U | **Reject** selection; no file writes | **NOT TESTED** |

These negative cases are **not** included in the six valid installation combinations. They test the read-only planner's mutual-exclusion logic, not a direction to copy conflicting MPQs into a client.

## Additional focus based on which patch changes

- **V or Z:** verify DBC IDs, spells, talents, textures, models, patch ordering and client/server compatibility. Confirm the required two-patch pair still works with *all six valid optional combinations*.
- **J or C:** inspect exact login art, animation, buttons and music plus the ability to return to the unmodified standard login. C must also be checked with and without U.
- **J or U:** inspect Eastern Kingdoms/Kalimdor loading art including both standard and widescreen BLPs; J+U overlaps two texture paths and must explicitly warn.
- **Any updated optional MPQ:** verify that disabling it leaves existing original client data intact and that no unknown local patch is overwritten.

The tool emits these focus categories only when relevant. For consistency it produces all six valid combinations for every nonempty change set (31 synthetic subsets tested in CI).

## Evidence required before even considering a future reviewed patchset

| Evidence | Required owner verification | Status |
| --- | --- | --- |
| Authentic originals and modified MPQs | Obtain source/rightsholder evidence and independently verify full actual SHA-256 + size against protected, reviewed metadata | **NOT VERIFIED** |
| Historical policy | Validate the prior immutable patchset and new separate proposal with trustworthy version history; do not edit version 1/2 | **NOT VERIFIED** |
| Copyright and GPL/source rights | Confirm allowed redistribution scope for every included MPQ asset/visual/music and relevant addon code | **NOT VERIFIED** |
| Original backup scope | Inventory and separately retain originals plus entire WTF, all accounts/realms/characters and custom addon data | **NOT VERIFIED** |
| Disaster recovery | Independent physical failure domain, crash-safe durability and a successful **disposable** restoration rehearsal | **NOT VERIFIED** |
| Owner consent | Genuine, authenticated, one-use approval with independently protected latest-state authority | **NOT VERIFIED** |
| Windows accessibility | Actual 100/125/150/200% DPI, keyboard, High Contrast and screen-reader results | **NOT TESTED** |
| In-game compatibility | Record outcomes of all six valid cases, two invalid selections and any patch-specific inspection | **NOT TESTED** |
| Approval | Separate owner review of provenance, game results, rights and recovery evidence | **NOT APPROVED** |

**Do not start applying optional combinations to your only working client.** Back up originals before any future authorised disposable game test; use a separate test client and verify the backup is actually restorable. Merely generating this plan does not grant the authority to modify the current client.

## What CI proves — and what it cannot

`tools/plan_patchset3_manual_qa.py` delegates validation to `review_patch_update_proposal.py`. The Windows/Linux suite tests all **31 nonempty subsets** of V/Z/J/C/U changed metadata, six legal combinations and the two forbidden combinations, rejected stale/private proposals, fixed output classifications, and no write/approval flags. It cannot perform Windows interactive game or human screen-reader tests, independently authenticate GitHub releases, inspect MPQ bytes, test real backups, or decide any rightsholder permission.

**A green result means only that the plan was generated correctly.** The output is always `MANUAL_PLAN_NO_TEST_EXECUTION_OR_APPROVAL`, with every case `NOT_TESTED`, every external evidence gate `NOT_VERIFIED`, and `patchset-0003_NOT_CREATED`. Installation, recovery, original backup writes and public distribution stay **BLOCKED**.

## Recording genuinely performed checks (self-report review, not approval)

The optional [manual QA record guide](PATCHSET3-MANUAL-QA-RECORD.md) now explains how to **print a blank local JSON template** and review human-entered statuses against all six valid scenarios and two forbidden J/C selections. The reviewer accepts only fixed status/check IDs, requires every check in a reported passing case to pass, binds records to the exact generated plan fingerprint, refuses free-text identifying data and never changes the test client. All such entries are self-reports, **not independently observed or authenticated**; no manual checks have been done through this milestone and there is still **no owner install/release permission**.

## Printable Windows worksheet for later owner-authorised physical testing

The [printable human Windows QA worksheet](HUMAN-WINDOWS-QA-WORKSHEET.md) combines all six valid patch selections, the two forbidden C/J selection-only cases, game/startup/client-file checks and physical DPI/High Contrast/keyboard/Narrator acceptance in an **unperformed** source-only document. It prints the prior read-only disposable test-client preflight command separately for each case. The current preflight compares to **patchset-0002**, not any genuine changed future patchset-0003 bytes, and must never be treated as v3 approval. Nothing is run on a real client and every checkbox starts blank.
