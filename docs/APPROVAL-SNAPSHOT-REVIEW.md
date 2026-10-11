# Milestone 3 — Read-only frozen approval snapshot review

**Status:** fixture-only design and Windows PowerShell 5.1 tests. No installation approval UI, authentic receipt, cryptographic signing, installer, backup writer, rollback, uninstall or actual client changes are implemented.

## Why approval needs a frozen snapshot

A future guided Windows installer must not treat a click on an outdated preview as permanent permission to alter any files. A player's approval must cover exactly which legitimate WoW 3.3.5a client, backup location, locally supplied source files and proposed operations they chose. If any of those inputs changes, the old approval must expire and **a new readable preview and explicit consent** must be requested before any future transaction can even be considered.

The current utility, `tools/Review-Naxxramas-ApprovalFixture.ps1`, **only compares two caller-authored JSON test files**. It does not collect consent or validate a source, and never grants permission to write.

## What a future approval screen should show

The proposed user-facing approval screen should make all of the following clear before any destructive or replacement step:

1. **Client:** an existing, separately obtained WoW 3.3.5a client, build `12340`, locale `enUS`, the selected local folder and the operation's risks.
2. **Backup:** a separate selected local backup location, existing destination files that require exact byte-for-byte preservation, the available free-space estimate and retention policy.
3. **Required V and Z:** `Data/patch-V.mpq` and `Data/patch-Z.mpq` are **mandatory**, not checkboxes. Display the exact expected SHA-256 and size for the active `patchset-XXXX`. The future tool must *independently verify* this against committed manifests and the real bytes.
4. **Optional J and U:** independent explicit choices for `Data/Patch-J.mpq` (login visuals) and `Data/Patch-U.mpq` (loading visuals), including the documented overlapping visual assets when both are selected. Leaving one unselected must **not** remove, alter or claim ownership of the existing file.
5. **Realmlist:** show the proposed `Data/enUS/realmlist.wtf` change, current content or digest, intended server and the fact that the original must be preserved.
6. **Operations:** a per-file list of `no_change`, `install`, `replace_after_backup` or `not_selected`, with clear language identifying anything that will be replaced and what originals must be preserved.
7. **Source and rights:** patch source location, verified source hashes, provenance and usage rights. **A matching checksum is not legal permission to distribute copyrighted archives.** All four custom patch files are still marked `public_distribution_approved: false`.
8. **Confirmation:** an explicit, one-time approval associated with a newly generated preview, specific selected operations and a reviewed backup location. No prechecked destructive options or automatic re-approval from a past session.

A future writer would need to re-open/re-verify safe folder/file handles, exact source and destination hashes, available backup capacity, source provenance, permissions, and any running WoW process *immediately before every affected write*. A plan comparison alone cannot remove filesystem races.

## Synthetic positional input format

The current **test plan** is an eleven-element JSON array:

`[1, installation_id, client_folder_fingerprint, backup_folder_fingerprint, source_folder_fingerprint, patchset, 12340, "enUS", [select_J,select_U], [V_operation,Z_operation,J_operation,U_operation,realmlist_operation], provenance_claim]`

Each operation is exactly:

`[allowlisted_relative_path, action, approved_source_SHA256_or_dash, current_destination_SHA256_or_dash, backup_required_boolean]`

Paths are case-sensitive, ordered as `Data/patch-V.mpq`, `Data/patch-Z.mpq`, `Data/Patch-J.mpq`, `Data/Patch-U.mpq`, `Data/enUS/realmlist.wtf`. No additional file paths or operations are allowed.

- Both V and Z must be present in the operation list and **cannot** be `not_selected`.
- `install` requires a 64-character lowercase source digest, no previous destination hash and no previous-file backup.
- `replace_after_backup` requires source and existing-destination digests **plus** `backup_required=true`.
- `no_change` requires an existing destination digest, no new source and no backup action.
- `not_selected` is only available for J/U, and must exactly correspond to the independent optional choice; it preserves any pre-existing unselected files.
- Boolean fields must be actual JSON booleans; unknown fields, paths, types, build/locale and actions fail closed.
- The source-provenance claim must be one of `claimed_local_use_reviewed`, `unverified` or `redistribution_unapproved`. **All are untrusted labels.** An unreviewed or unapproved source always yields a blocker even when the two snapshots match.

The **approval receipt fixture** supports two purely synthetic versions:

`[1, approval_id, consent_claim, exact_prior_plan_snapshot]` (v1, legacy) or `[2, approval_id, consent_claim, exact_prior_plan_snapshot, declared_plan_sha256]` (v2, unkeyed digest). See [Plan Digest v2](APPROVAL-PLAN-DIGEST-V2.md) for the exact type-preserving encoding, mismatch rules, tests and trust limitations.

The allowed consent claims are `explicit_confirmed`, `pending`, `revoked` and `expired`. They are fabricated test labels, **not actual player signatures or consent**. Both files must be regular, nonlinked strict-UTF-8 JSON with a 16 KiB size limit per file.

## Mismatch policy

The inspector compares current and previously frozen **untrusted** input values and returns individual blockers for changes to:

- Installation ID; client, backup or patch-source folder fingerprint; patchset; WoW build/locale.
- J/U choices, the five file operations, source digests and original destination digests, including `Data/enUS/realmlist.wtf`.
- Source provenance claim.
- Missing, pending, revoked or expired approval record.

The tool reports `manual_review_approval_snapshot_mismatch` when a claim differs; if all input claims are internally consistent it reports `fixture_claims_match_NOT_authenticated`. No claim is accepted as proof of file ownership, actual consent or source rights.

**Every result**, including a perfect fixture match, returns:

- `review_required = true`
- `allow_file_writes = false`
- `allow_automatic_resume = false`
- `authorises_rollback = false`
- `records_real_consent = false`
- `public_distribution_authorised = false`

The report does not expose local paths, file hashes or an installation ID.

## Windows test coverage

From the repository checkout on Windows PowerShell 5.1:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-ApprovalFixture.ps1"`

The suite creates **synthetic JSON files only** and tests approvals that match, are absent, pending, revoked or expired; swapped folders; new patchset; toggled J/U; modified source and previous-file digests for V, Z and realmlist; unselected optional preservation; inconsistent action/backup claims; schema and path validation; malformed input; output privacy and byte-exact no-write checks. The independent `tests/Test-ApprovalDigestV2.ps1` suite additionally covers v2 hash canonicalization, consent revocation, modified snapshots, drift and forged-but-consistent receipts.

**Not tested:** the actual MPQ files, real Windows owner approval, cryptographic signatures, live directory/file identities, file locking, durability, API correctness of a future writer, authoritative patch provenance, real backup integrity or independent nonrollbackable latest-state storage.

## Future production gate

A separately reviewed approval mechanism must bind an **authentic and fresh** consent event to a canonical versioned plan digest, secure installation identity, independently verified patches and backups, a proven allowlist, source rights and durable transaction checkpoints. It must support cancelling/reviewing the plan and never turn previous consent into unconditional permission for updates or uninstall.

Even an authenticated per-user receipt does not by itself solve coordinated rollback of all local states. See [Trust Continuity](TRUST-CONTINUITY-REVIEW.md), [Journal Authority](JOURNAL-AUTHORITY.md), [Journal Durability](JOURNAL-DURABILITY.md), [Transaction Design](TRANSACTION-DESIGN.md) and [Project Handover](PROJECT-HANDOVER.md).

**This fixture never creates real consent or installs anything.**
