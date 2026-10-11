# Milestone 3 — Trust continuity, key loss and client migration

**Status: threat-model review and synthetic, read-only Windows PowerShell tests.** There is **no production DPAPI registration, latest-state authority, client installer, backup writer, rollback or uninstall engine**.

## Scope and baseline decision

The proposed Naxxramas Client Setup will assist a user who already possesses a legitimate **WoW 3.3.5a, build 12340, enUS** installation. Its ultimate setup must keep mandatory V/Z patches together, preserve exact original bytes before any replacement, and protect user files.

The initial credible security target is:

- **Accidental corruption and operator mistakes:** detect missing, mismatched and interrupted records; stop rather than guessing; preserve backups.
- **Unexpected edits from another unprivileged Windows account:** future separately reviewed per-user secret and ACL boundaries could provide useful tamper resistance.
- **Same-user malicious changes, local administrator, full-disk snapshot rollback, all-record replacement:** **not solved** by current tools, DPAPI-encrypted key storage alone, ordinary HMAC files, directory fingerprints or a self-reported anchor. No component may claim monotonic anti-rollback until a genuinely independent trusted authority exists and its failure modes are reviewed.
- **Lost registration or key, computer/account migration:** never manufacture a new matching authority for old records. Instead preserve client and backups and require independent manual review before proposing a new registration.

A self-contained offline local installer without an external monotonic authority may only provide limited accidental-corruption safeguards, not an unconditional proof of the latest historical state. Product language and any future destructive operation must reflect that distinction.

## Synthetic inspector

The development-only script is `tools/Review-Naxxramas-TrustContinuity.ps1`. It reads a **caller-authored** positional JSON array and classifies whether the *claims* are consistent. It does not open the game client, real backup files, an actual Windows DPAPI key, installer registry entry, a signed journal, or a privileged service.

### Fixture schema v1

`[1, installation_id, folder_claim, registration_claim, key_claim, anchor_claim, anchor_seq, journal_seq, session_claim, original_backup_claim, source_provenance_claim, preview_consent_claim]`

The file must be strict UTF-8, maximum 8 KiB, positional JSON (not an object). Unknown fields and statuses are rejected. The integer sequences must be between 0 and 100,000,000.

Example, **not** proof of real-world installation:

`[1,"synthetic-install-123","same_object","claimed_registered","claimed_available","claimed_present",13,13,"claimed_completed","claimed_verified","claimed_verified_local","preview_acknowledged"]`

The words `claimed_available`, `claimed_present`, `claimed_verified` and `preview_acknowledged` are **fixture labels only**. They do **not** represent a successful cryptographic, source, backup or user-consent check.

### Manual-review outcomes

| Situation | Blocking observation |
| --- | --- |
| Copied/replaced folder, move across volumes, missing identity | `folder_identity_not_confirmed` |
| Missing, damaged, foreign, replayed or unverified registration | `registration_unavailable_or_disputed` |
| Missing/decryption-failed key, different Windows account or new computer | `key_unavailable_or_account_changed` |
| Missing, damaged, older or unverified independently claimed latest anchor | `independent_latest_anchor_not_confirmed` |
| Journal behind or ahead of claimed anchor | `journal_older_than_anchor` / `anchor_older_than_journal` |
| Missing, incomplete, invalid or zero-sequence completion | `session_not_confirmed_complete` |
| Missing, corrupt, foreign or unverified original backup | `original_backup_unverified` |
| Unverified local patch source or unapproved provenance | `patch_provenance_unverified` |
| No current preview acknowledgement | `user_preview_not_current` |

All independent blockers are returned together; an inaccessible key must never hide a damaged original backup or provenance issue.

**Every result requires manual review.** The report always sets `allow_file_writes=false`, `allow_automatic_resume=false`, `authorises_rollback=false`, `allow_silent_reregistration=false` and `preserve_existing_backups=true`.

If all labels match, the only possible result is `fixture_claims_consistent_NOT_authenticated`. A copied and fully replayed old registration, key *claim*, journal and anchor can still appear consistent. **Never turn the "consistent" classification into installation authority.**

## Windows PowerShell 5.1 synthetic tests

From the repository checkout:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-TrustContinuity.ps1"`

Tests create a disposable, tiny JSON file in a fresh TEMP directory. They test folder renames, copies, volume changes, missing registrations, account and computer migration, all key-loss cases, anchor/journal disagreement, incomplete sessions, damaged backups, source provenance, missing preview acknowledgment, multi-fault reporting and **full coordinated replay**.

They additionally assert that the classifier does not modify fixture bytes, make a backup, create registration files, authorise changes, or disclose paths/installation identities. This **does not** simulate actual key loss or prove a filesystem persists correctly through a power failure.

## Proposed manual recovery policy (for later product development)

1. **Preserve first:** make a separately stored, owner-controlled byte-for-byte backup of the selected client and preserve existing session backups and snapshots. Do not overwrite either while identity or trust is uncertain.
2. **Diagnose without writes:** identify the actual folder and WoW build, check safe paths and current V/Z fingerprints, record potential user edits, and compare originals only when they are available and provably intact.
3. **Different computer or Windows account:** the old local registration is not automatically portable. Treat an inaccessible DPAPI key, missing trusted identity and moved folder as needing a **new owner-approved plan**, never as proof that old session records can be used to uninstall/rollback.
4. **Re-registration is a new act:** if a future trusted installation scheme allows it, require fresh explicit consent, independent verification of the client/source and a new scope of managed files. Do not backfill false ownership for files that predated the new registration.
5. **Conflicting or edited player files:** never replace or delete them silently. Offer only non-destructive, step-by-step manual comparison and restoration options.
6. **Unable to verify an original backup:** block automatic revert permanently for that file. Do not fabricate an original from a template or another build.
7. **Restore older system snapshot:** a self-consistent old local journal and anchor may still be historical. Without an independent latest-state authority, stop and request manual review; do not infer this is the latest committed session.
8. **No destructive operation from a preview:** even a future authenticated record should require user confirmation of specific intended replacements, retention/uninstall effects, and available original backups.

## Windows DPAPI research and limitations

Microsoft's `CryptProtectData` documentation describes default protection that generally depends on matching user credentials and the original computer, with documented exceptions such as roaming profiles. The optional `CRYPTPROTECT_LOCAL_MACHINE` scope can allow **other users on the same computer** to unprotect the data and is not an appropriate default substitute for per-user trust. `CryptUnprotectData` performs a decryption/integrity check, not a verified nonrollbackable timeline.

An attacker capable of restoring *all* validly protected historical files can present a matching old journal and anchor. DPAPI does **not** provide the independent monotonic counter or trustworthy latest historical state needed to detect that full rollback. Using an external service/hardware/administrative authority to provide this property would introduce additional privacy, offline-use, recovery and operational tradeoffs; **no architecture has yet been approved**.

Microsoft references:
- [CryptProtectData](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata)
- [CryptUnprotectData](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptunprotectdata)

## Next engineering gate

Review a concrete future architecture (per-user protected registration, signer identity, key recovery, optional independent latest-state source, stable folder handle checks, backup retention, consent format and offline/migration strategy). Explicitly state which threats it **can** and **cannot** prevent. Then extend **read-only** error classification and checkpoint-state models. Any disposable-fixture writer needs separate approval and real safety tests before use. No working game client should be modified, and no patch is authorised for public redistribution by this document.

Related: [Journal Authority](JOURNAL-AUTHORITY.md), [Journal Durability](JOURNAL-DURABILITY.md), [Checkpoint Ordering](CHECKPOINT-ORDER-REVIEW.md), [Registration Fixture Review](REGISTRATION-FIXTURE-REVIEW.md), [Roadmap](ROADMAP.md).
