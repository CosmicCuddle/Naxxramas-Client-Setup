# N Addon Suite — Independent authority and crash-boundary gate

**Status: design and developer-only synthetic read-only tests, 12 October 2026.** This is not permission to install, copy, back up, restore, delete, migrate, repair, authenticate a user, or publish an addon. No real player files are opened or changed.

## What this milestone adds

The existing [synthetic journal](ADDON-EVIDENCE-AND-RECOVERY.md) detects missing event sequences, malformed records, untrusted latest-pointer disagreement, interrupted phases and changed original/WTF bytes. A **complete coherent replay** of all local records, including a local "authority" record, cannot be identified without a separate trusted source of monotonically advancing history.

Developer-only `tools/review_synthetic_addon_authority.py` takes a pre-existing, disposable fake fixture root with **three exact markers** (original/backup synthetic, journal synthetic, authority synthetic). It reads two more synthetic JSON fixtures (`authority-claim.json` and `crash-claim.json`) and invokes the existing read-only journal and full original/backup/after/current integrity inspectors. Only the unit-test harness creates or alters fake fixture files.

- **Authority claim:** narrow versioned fields bind transaction ID, scope digest, last event sequence/hash and a caller-asserted epoch to a consent status, consumed-through and revoked-through counters, and caller-asserted current/stale/missing/revoked/foreign state. The tool rejects missing, linked/hardlinked, too-large, malformed, duplicate-key, wrong-type and foreign/stale records, consumed/revoked claims, binding drift, and changes observed during the review.
- **Crash claim:** exact transaction/scope/phase, one enumerated fault window and four strictly boolean **claims**: same-volume staging, separate-original storage, checkpoint flush and parent metadata durability. Missing, false, contradictory or changed claims block even preliminary consistency classification. **True boolean claims are not hardware evidence or independently verified.**
- **No authority awarded:** even if these two files and the existing journal are self-consistent, output is only `claims_consistent_but_NOT_AUTHENTICATED` with all action/approval/security flags **false**. Neither local JSON, hashes, epoch numbers, Windows folder IDs, nor a fixture marker establishes genuine owner identity, durable state or monotonic replay protection.

### Synthetic crash windows and required classification

| Injected hypothetical window | Intended supported phase | Required result |
| --- | --- | --- |
| `backup_copy_torn` | `backup_started`, `backup_copied` | Manual review, retain full originals |
| `backup_claim_before_validation` | `backup_copied`, `backup_checked` | No verified original-copy assumption |
| `staged_file_torn` | `stage_started`, `stage_checked` | Disregard partial staged output |
| `rename_done_commit_missing` | `replace_started`, `replace_finished` | Destination/journal mismatch; no resume |
| `commit_record_file_missing` | `replace_finished`, `postcheck_finished` | Do not trust either completion claim |
| `recovery_copy_torn` | `recovery_started`, `recovery_checked` | Preserve current and original bytes |
| `power_loss_metadata_ambiguous` | Any phase | Power-loss durability not established |
| `none` | Any phase | Claims may be self-consistent, **never authorise action** |

The model checks whether a reported fault is possible in the reported phase. It does **not** simulate power loss or promise real Windows crash survivability. Full original/backup integrity still includes all five suite addons, both named legacy addons, and all simulated account/realm/character `WTF` trees including unknown settings files; unrelated third-party addon roots remain untouched.

## Actual future engineering requirements — not implemented

1. **Independent authority threat model:** establish an explicitly approved trusted operator / service / hardware-held state outside the client and outside the transaction backup, with confidentiality, authenticated monotonic counter, anti-rollback protection, access control and auditable revocation. Decide how an **offline** machine, cloned drive, account migration, authority loss and recovery without internet behave. No local JSON file alone is sufficient.
2. **Consent:** a real owner must review precise source, client directory identity, every affected folder, full settings protection and an independently held backup destination. Consent must be single-use, cryptographically tied to a fresh plan and session, expiring/revocable, and consumed in an independently recorded order before writes. A claimed counter or local SHA is never consent.
3. **Windows filesystem:** require a supported-filesystem policy, stable directory and file handles, reparse/hardlink/race protection, same-volume staging for atomic per-file rename, proper final-file verification, and *tested* flush/rename/metadata ordering. A single per-file rename does **not** make a multi-file suite transaction atomic; `FileStream.Flush(true)` does not prove metadata survives sudden power loss. Do not claim guarantee on arbitrary USB/removable/network/virtual volumes.
4. **Original preservation:** verify exact byte-for-byte contents and path/metadata inventory of all *affected* addon folders and **all** WTF profiles before any hypothetical write, in independent storage with secure retention and a tested manual restore plan. Unknown original files and legacy duplicates are never deleted as part of an inferred upgrade.
5. **Recovery:** after a restart, never automatically replay an incomplete journal. Reauthenticate the latest authority and original copies, obtain stable *current* file observations, identify external/player edits, and require fresh human review. Preserve conflict copies; a changed SavedVariables file is not overwritten by a prior session.
6. **Crash rehearsal:** once independently approved, use only sacrificial disposable volumes and hardware/VM-supported power-cut test plans for each write/flush/rename/checkpoint boundary. Distinguish application termination from actual power loss; observe both data and filesystem metadata after restart. **No writing prototype is approved today.**
7. **Release/legal/manual QA:** complete source and licence review, real in-game J/C/U and addon tests, and physical Windows 100/125/150/200% DPI, keyboard, High Contrast and screen-reader testing. Windows CI headless checks cannot replace a human acceptance record.

## Tested boundary and privacy contract

Run `python -m unittest discover -s tests -p test_synthetic_addon_authority.py -v` **as a developer/CI fixture**, never against a player WoW directory. Cross-platform CI also reruns the earlier synthetic journal and whole-tree integrity suites. Tests exercise every listed crash window, contradictory phase/window pairs, consumed/revoked/pending consent *claims*, foreign or stale authority, mismatched source binding, false claimed storage properties, backup corruption, changed account settings, missing/oversized/duplicate-key JSON, symlinks, missing markers, race injection, and deliberate coherent replay of all local claims.

The resulting JSON includes only known fixed-scope status/counters and safe blocker codes; it never emits real paths, transaction IDs, character names, account names or data hashes. The reviewer is excluded from the strict scripts-only player ZIP. **No synthetic matching report is evidence of recoverability or a permission decision.**
