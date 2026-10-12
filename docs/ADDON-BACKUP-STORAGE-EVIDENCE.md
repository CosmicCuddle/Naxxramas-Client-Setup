# N Addon Suite — Synthetic backup storage and failure-domain evidence

**Status:** developer-only, read-only **synthetic** review. No installer, backup writer, real-client scanner, restore tool, durable backup certification or public distribution approval.

## Why it is necessary

The existing four-snapshot addon/WTF inspector compares `original` and `backup` bytes, path structure and all character-level settings. Matching SHA-256 data **does not** establish that the backup is a faithful earlier original, physically independent, on a separate failure domain, or recoverable after a storage failure. In particular, the generated temporary fixtures store their fake `original` and `backup` directories under one temporary root; they **must not** be described as independently held player backups.

A logical volume GUID or `st_dev` identity is not an independent physical disk identifier. Two distinct volumes may share a physical disk, controller, storage array, host or power source. A matching file SHA-256 does not prove backup retention, immutability, media durability, filesystem metadata correctness or the ability to restore without overwriting later player changes.

## Synthetic-only read-only reviewer

`tools/review_synthetic_addon_backup_storage.py` requires a throwaway fake-client fixture with both `.naxx-recovery-synthetic-only` and `.naxx-synthetic-storage-only` markers, plus the original four pre-existing `original`, `backup`, `claimed_after` and `current` trees. Only the separate unit tests create or modify these fake files.

The reviewer reads a strictly bounded `backup-storage-claim.json` containing two synthetic volume-label strings and four strictly Boolean *claims*: physical independence, different failure domain, backup retention and a restoration rehearsal. **They are untrusted caller-controlled claims and never become verified evidence.** It compares observed logical filesystem identifiers for the fake original and fake copy directories and invokes the existing read-only full-byte scope inspector over exactly five addon roots, two legacy roots and **all fake WTF accounts, realms, characters, unknown settings and custom addon files**.

| Observation | Required preserve-first interpretation |
| --- | --- |
| Fake original and copy in the same observed logical filesystem | `same_logical_volume_not_independent`; not independent disaster recovery |
| Different claimed volume labels but same observed logical filesystem | Flag `claimed_different_volume_but_observed_same_logical_volume` |
| Distinct observed logical filesystem identities | Still **not proof** of different physical storage or a separate power/failure domain |
| Same relative files and SHA-256 digests | `scope_bytes_match_untrusted`, not a verified retained original |
| Missing, extra, corrupted, linked or hardlinked copied files | Preserve originals; `unusable_or_incomplete_original_copy` |
| A current player addon or WTF SavedVariables differs from original | Manual conflict; no overwrite of newer edits |
| Entire fake original and backup changed together to new matching bytes | No authentic earlier-state provenance or recovery permission |
| Disappearing directory, changed record, oversized/linked/duplicate JSON keys | Refuse or require manual review |

Output includes only hardcoded known scope categories, aggregate counts, fixed blockers and the coarse *logical* relation. It emits **no private filenames, local paths, account names, file digests, storage tokens or raw device IDs**. `status=manual_review_required` always; `different_physical_storage_verified`, `durable_backup_bytes_verified`, `independent_original_backup_or_restore_verified`, `restore_or_install_authorised`, `backup_created_or_deleted` and `public_release_authorised` remain false for all outcomes.

### Developer/CI tests

Run only against disposable generated fake trees via `python -m unittest discover -s tests -p test_synthetic_addon_backup_storage.py -v`. Windows and Linux Python 3.12 CI also reruns the earlier four-snapshot integrity suite. Tests cover complete multi-account settings, custom and legacy addons, identical bytes on shared logical storage, false separate-volume claims, coherently modified original+copy, missed or corrupted originals, changed current character settings, unsafe hardlinks and symlinks, malformed record, missing marker, mid-scan record changes, directory swaps and no-write/privacy invariants.

## Future real backup and crash-recovery requirements — not implemented

Before any *separately approved* write-capable work, design a strict destination selector, verify client and backup directory handle identity and non-overlap, decide explicit physical failure-domain policy, record a frozen full inventory with all original bytes and necessary filesystem metadata, and independently re-read the copied bytes. A second copy must be held and protected outside the original transaction/client and include every affected addon folder plus the complete WTF tree. Budget real storage use with concurrent changes, access controls, ACLs, hardlinks, symlinks, case normalization, disk/metadata error and full/partial copy handling; verify recoverability on disposable machines. Require authenticated owner consent and a trusted monotonic external latest-state authority before any journal action. True storage isolation, power-loss survival, full hardware disk identity and crash-durable recovery have **not** been established.

Also outstanding: physical 100/125/150/200% DPI, High Contrast, keyboard and screen-reader acceptance on Windows, source licence/rights review and separate in-game addon/Patch-C/J/U tests. No write engine or public release is authorised.
