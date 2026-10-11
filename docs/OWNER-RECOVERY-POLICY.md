# Milestone 3 — Offline, migration, lost-key and owner recovery policy

**Status: design and read-only synthetic policy validation only.** No installer/updater, automatic restore, production registration, actual owner check, DPAPI key, signer, network service, trusted clock, durable monotonic storage, licensed patch distribution or backup writer exists.

## Goal and player experience

Players who already possess their own **World of Warcraft 3.3.5a build 12340 enUS** client should not lose the ability to launch their *existing* client simply because a setup tool is offline or its registration records cannot be read.

**Keep existing game files undisturbed.** If the future setup assistant cannot verify ownership or latest transaction state, it may display a read-only explanation, inspect allowlisted files, and explain how to conduct an explicit manual recovery. It must **not** silently re-register, rekey, install, uninstall, overwrite V/Z/J/U, update a realmlist or roll back.

Core `Data/patch-V.mpq` and `Data/patch-Z.mpq` remain mandatory for the selected Naxxramas core, with optional independent J/U visuals. Unselected existing files are preserved. No game files or custom MPQs may be redistributed merely because a checksum is known.

## Proposed trust architecture — decision not yet approved

There are three distinct notions, and none replaces the others:

1. **Owner consent:** a real Windows user sees exact per-file changes, original backup destination, installation ID, current plan digest and consequences; after a fresh preflight, an explicit user action creates a short-lived, single-use approval. A guessed label `explicit_claim` or a text file never proves a click.
2. **Signer and registration:** a protected per-user signing/registration key could bind a particular owner to a stable installation identity. Local Windows DPAPI (`CurrentUser`) may help protect secret key material, but it does **not** provide an unrollbackable history or prove asset rights. Key loss, new OS account, reinstall and migration require clear recovery decisions.
3. **Independently current transaction history:** a separately trusted authority must know at least the latest sequence/used-nonce if the installer claims to detect complete replay of all locally held state. An ordinary writable local file, two files in different directories, a hash, a Windows file ID or an encrypted historical DPAPI blob cannot provide this by itself.

| Approach | Benefit | Unresolved consequence |
| --- | --- | --- |
| Strictly local, offline only | Privacy and no account/service dependency; player can read existing game files | **Cannot guarantee detection of complete coherent rollback/replay** of registration, key and journal files. Must not advertise replay resistance or silently resume |
| **Optional independent latest-state service**, if separately reviewed and explicitly enabled | Could reject stale sequences and duplicate/consumed nonces using an independent durable record | Needs real account identity, authentication, privacy controls, availability, retention, operational security, migrations and offline behaviour. **Not implemented or approved** |
| TPM/other hardware-backed nonexportable key material | Could improve local private-key nonexportability on supported machines | Key continuity/migration is more complex, hardware support differs, and key protection alone is **not a monotonic record** of transaction history |

**Recommended direction for architecture review, not an implementation approval:** keep read-only preflight and playing an existing client available offline; require fresh explicit consent and suitably trusted latest-state evidence before any future *write-capable* transaction. Do not silently downgrade a future replay-resistant writer to a local-only authority when offline.

No online service endpoint, credential, public identifier, personal information handling or storage policy has been chosen. Designing such a service would require a separate explicit user decision about offline availability and privacy tradeoffs. The user's AzerothCore server and GitHub repository are **not** automatically an authority for local player installations.

## Explicit recovery decision policy

All these situations **preserve** existing game files, backups and transaction records:

| Situation | Safe behaviour | Never silently do |
| --- | --- | --- |
| Offline or independently trusted latest-state unavailable | Keep existing game client usable, permit read-only inspection; defer any proposed writes | Invent online freshness or accept stale local snapshots |
| Copied or moved client | Keep both copies; compare client/build and verified originals; request a separately authenticated owner/migration review | Adopt the old client's approval or blindly delete duplicate folders |
| New Windows account or different PC | Preserve current credentials and files, explain how to recover or re-approve | Interpret new DPAPI credentials as the former user |
| Missing or undecryptable key | Preserve registrations, backup files and failed state for manual review | Re-key, self-register or wipe an old journal |
| Key rotation | Require independently verifiable continuity and fresh consent | Rewrite owner ID using caller-provided labels |
| Expired or revoked approval | Obtain new explicit user review for the exact current plan | Reuse an earlier approval |
| Old/ahead/diverged journal | Preserve all versions and investigate latest-state conflict | Roll back counters or replay older completed transactions |
| Missing/damaged original backup | Block restoration and preserve current files | Reconstruct an “original” from an unknown/current patch |
| Player edited a file since installation | Preserve the player's current bytes and flag conflict | Overwrite or delete current data |
| Installation/resume/restore requested | Independent new consent, file-handle/backups/provenance review and durable authority all required | Automatically proceed based on locally consistent claims |

“Preserve” means **no mutation by the setup assistant**. The project cannot guarantee that another application or the player will not alter the filesystem.

## Synthetic read-only implementation

`tools/Review-Naxxramas-OwnerRecoveryPolicy.ps1` validates an existing caller-written **13-element positional JSON array**. The input is a model of decisions, not an authenticated event:

`[1, "synthetic-install-123", "same_folder", "same_user_claim", "available_claim", "current_claim", "matches_claim", "explicit_claim", "same_claim", "same_bytes_claim", "inspect", "online_claim", "rights_claimed"]`

Fields after the version and ID, in order:

| Field | Allowed synthetic values |
| --- | --- |
| Folder | `same_folder`, `copied`, `migrated`, `unknown` |
| Windows-user claim | `same_user_claim`, `different_user`, `unknown_user` |
| Credential claim | `available_claim`, `missing`, `undecryptable`, `foreign_user`, `rotated` |
| Independent latest-state claim | `current_claim`, `offline`, `timeout`, `missing`, `conflict` |
| Sequence claim | `matches_claim`, `stale`, `ahead`, `missing`, `divergent` |
| Consent claim | `explicit_claim`, `pending`, `revoked`, `expired`, `missing` |
| Planned files | `same_claim`, `changed`, `unknown` |
| Original backup claim | `same_bytes_claim`, `missing`, `mismatched`, `unverified` |
| Requested operation | `inspect`, `install`, `resume`, `restore`, `reregister`, `migrate`, `recover_key` |
| Network claim | `online_claim`, `offline` |
| Source rights claim | `rights_claimed`, `rights_unverified` |

The fixture uses exact case-sensitive strings, strictly encoded UTF-8, at most 4096 bytes, refuses junction/symlink path ancestors and any unrecognized schema or extra fields.

The tool produces concise **manual-review blockers** and an explanatory `recommended_manual_next_step`. The best result is **`fixture_claims_consistent_NOT_AUTHENTICATED`** (read-only inspection only). None of these states are a grant. Even “rights claimed” and “online claim” are **only caller labels**, not checked rights or a network response.

All reports unconditionally set:

`review_required=true`; `preserve_client_files=true`; `preserve_original_backups=true`; `allow_client_writes=false`; `allow_backup_writes=false`; `allow_automatic_resume=false`; `allow_automatic_rollback=false`; `allow_silent_reregistration=false`; `allow_silent_rekey=false`; `actual_windows_user_authenticated=false`; `actual_key_verified=false`; `independent_latest_state_verified=false`; `records_real_consent=false`; `public_patch_distribution_authorised=false`.

### Developer command and Windows CI

Run against a **synthetic fixture JSON file** on Windows PowerShell 5.1:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Review-Naxxramas-OwnerRecoveryPolicy.ps1" -FixturePath "C:\Temp\owner-policy-fixture.json" -Json`

Tests:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-OwnerRecoveryPolicy.ps1"`

The GitHub workflow `.github/workflows/owner-recovery-policy.yml` checks copied/migrated clients, different Windows users, missing/undecryptable/foreign/rotated keys, offline and timed-out authority, stale/diverged sequence, revoked/expired/pending approval, changed plans/backups, install/resume/restore/reregister/rekey attempts, source rights labels, simultaneous faults, malformed/case-altered inputs, no changed fixture bytes and private output.

**Negative trust test:** a coordinated fake historical state with every field matching is classified internally consistent, proving that this synthetic tool cannot detect full replay. It still sets every authorisation flag false.

## Next release gates — not implemented

1. Decide the desired *privacy versus offline install/update availability* tradeoff **before** choosing a third-party/remote latest-state authority. There is no silently created player account or server-side record.
2. Specify authentic Windows user identity and a human-friendly, accessible consent UI with explicit per-file backup and revert scope, keyboard navigation, clear wording and short-lived nonces.
3. Specify supported Windows per-user secret protection/rotation/recovery and foreign-account/migrated-folder handling without overwriting existing registrations.
4. Implement separately verified original-copy lineage with strong Windows file/directory handle continuity, tested flush/failure behaviour and non-destructive player edit conflict resolution, **first in disposable synthetic tests and only after a separate write-scope review**.
5. Verify patch-source rights independently. Custom V/Z and optional J/U are **not** approved for public hosting.

Related: [Trust Continuity](TRUST-CONTINUITY-REVIEW.md), [Recovery Ownership Claims](RECOVERY-OWNERSHIP-AUTHORITY.md), [Journal Authority](JOURNAL-AUTHORITY.md), [Project Handover](PROJECT-HANDOVER.md).

**No user consent, authentication, registration, key recovery, installation, backup or rollback has been performed by these tools.**
