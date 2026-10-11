# Milestone 3 — Live read-only plan recheck

**Status:** Windows PowerShell 5.1 read-only inspection; this is **not** an installer, approval UI, backup/rollback engine, signed receipt or authentication service.

## Why this is different from previous synthetic fixture models

The existing [Installer Plan](INSTALLER-PLAN.md) actually reads a selected **local** WoW client, optional independently held patch source, and separate backup directory; checks allowed paths, known patch SHA-256 and sizes, existing realmlist, client build, volume IDs and capacity; and prints a *read-only* plan. The [Windows Directory Identity](WINDOWS-DIRECTORY-IDENTITY.md) inspector observes each selected directory's current Win32 file ID.

This milestone integrates **those existing live read-only inspections**. A baseline snapshot can be printed from the currently observed plan and directory IDs. A later run rehashes the actual supplied local files through the planner and compares exact semantic fields to the snapshot, while independently re-observing each local directory ID.

The baseline is an unsigned **user-controlled record**. There are no secret keys, real consent, independent previous session, verified patch rights or latest-state authority. Its value is in detecting accidental **plan drift**, **not** authorising a modification.

## Basic workflow (read-only)

Use an independently obtained WoW **3.3.5a build 12340 enUS** client or a **separate test copy**. For a future installation experiment, never select your sole working client. Keep existing backups outside the client and source.

Open Windows PowerShell from your extracted Naxxramas-Client-Setup repository.

**1. Print an observed snapshot:**

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Review-Naxxramas-LivePlan.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Local-Naxx-Patches" -BackupRoot "F:\Naxx-Backup" -Snapshot`

This prints a JSON array to the console. The **inspector never writes the snapshot to disk**; a developer may explicitly save the output for later comparison if they choose. The array is not consent or an approval record.

**2. Recheck later against your explicitly saved baseline file:**

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Review-Naxxramas-LivePlan.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Local-Naxx-Patches" -BackupRoot "F:\Naxx-Backup" -BaselineSnapshotPath "C:\Local-Review\previous-snapshot.json" -Json`

Repeat any `-VanillaLogin`, `-VanillaLoading` or `-RealmHost` choices from the original capture. Changing the choices should deliberately trigger a drift warning, never automatic approval. These examples are placeholders, not paths we verified exist.

## Snapshot version 1

An exact five-field positional JSON array:

`[1, plan_fingerprint_sha256, observed_client_directory_sha256, observed_source_directory_sha256_or_none, observed_backup_directory_sha256_or_none]`

- The plan fingerprint is domain-separated SHA-256 of a **typed, ordered** subset of the current planner result: active patchset, build/locale, J/U selection, realm host, preflight status, storage mode/budgets and all **five** V/Z/J/U/realmlist records.
- Every file record includes path, required/selected/action, existing file state/digest/size, expected digest/size, source state and backup requirement. The tool reuses planner policy instead of inventing rules for each operation.
- The three directory fingerprints come from Win32 `FILE_ID_INFO` read-only directory handles, using the existing directory identity tool. `none` is recorded when a source or backup directory was not selected.
- Snapshot JSON is a small, strict UTF-8 array with exactly five fields. Other keys, case-changed digests, junction-backed snapshot paths and oversized inputs are refused.
- Snapshot output omits actual local paths but includes pseudonymous fingerprints which should **not** be published as if they were anonymous/secret.

A snapshot comparison report names *categories only*: `file_plan_or_options_changed`, `client_folder_identity_changed`, `source_folder_identity_changed`, `backup_folder_identity_changed`, `fresh_planner_preflight_blocked` or `separate_backup_not_selected`. It does not print local folder names, input hashes or the fingerprint itself.

## What it detects

- Changed installed or locally supplied V/Z/J/U bytes that alter the real planner's classification.
- Changes to optional J and U choices or the selected realmlist host, and modifications to existing realmlist bytes.
- Copying/replacing any of the three selected folders, even if its visible contents happen to match.
- Current planner blockers: unsupported build, unknown patch, missing source, unsafe path, low/unverifiable capacity, invalid backup isolation and other existing preflight restrictions.
- Choosing no separate backup directory is always a manual-review blocker in comparison mode.

Even a match with no preflight blockers returns **`live_plan_matches_NOT_APPROVED`**, which is deliberately **not** installation authorisation.

## What it cannot guarantee

- **Not secure ownership:** a caller may edit the snapshot and calculate their own hashes. Directory file IDs can be reused and do not authenticate the owner.
- **Not protected from races:** files, mounts, folders or free space can change after they were inspected; no stable open handles remain locked throughout the run and no write-time identity recheck is implemented.
- **Not an approved backup:** a backup *folder* may be observed, but no exact original backup has been created, verified or restored.
- **Not source rights:** expected patch checksums do not grant a license to share MPQs. The patch manifest still marks **public distribution unapproved**.
- **Not a complete transaction:** no journaling, signing, actual token consumption, DPAPI protection, crash durability, installer/uninstaller or rollback exists.
- **Not full source enumeration:** the existing planner focuses on the pinned allowed patches and realm config; unrelated files are not part of the fingerprint. Unselected optional files are tracked in the plan but preserved.

Never treat a matching snapshot, no-blockers preflight or a previously displayed user prompt as sufficient for any future write.

## Windows integration tests

Run:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-LivePlanDrift.ps1"`

The GitHub Windows suite builds disposable source/client/backup directories with *fake non-WoW patch bytes*, a versioned harmless fixture executable and a fixture manifest. It invokes the **real planner and real Win32 directory identity tool** and verifies exact-matching snapshots, optional/realm drift, edits to V and the realmlist, same-byte copied source and replaced backup folder, missing backup selection, malformed baselines, no leaked paths and unchanged fixture bytes during inspection.

The fixture creation/cleanup code writes solely inside its own freshly generated temporary test root. **The new review tool remains read-only.** No actual game assets are needed or distributed.

## What comes next

A future production approval flow must bind user consent to a freshly verified plan and **stable actual installation identity**, with an independently protected one-time receipt and latest-used/anchored sequence. Changes to either plan or input files must cancel any earlier approval. Original backups, source provenance, scope and owner permissions still require separate verification, and Windows write-time races remain unresolved.

Related: [Frozen Approval](APPROVAL-SNAPSHOT-REVIEW.md), [Plan Digest v2](APPROVAL-PLAN-DIGEST-V2.md), [Consent Lifecycle](CONSENT-LIFECYCLE-REVIEW.md), [Project Handover](PROJECT-HANDOVER.md), [Roadmap](ROADMAP.md).

**No installed game file, source archive, personal backup or client configuration is changed by the reviewer.**
