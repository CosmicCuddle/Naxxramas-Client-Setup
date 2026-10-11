# Milestone 3 — Recovery ownership and claimed approval authority

**Status:** Windows PowerShell 5.1 **read-only** inspection of a real local recovery-session file, observed Windows directory identities and **two deliberately unauthenticated JSON fixtures**. There is no login, signer, per-user secret, consent dialog, protected counter, installer, backup writer, restore, deletion, rollback or true replay prevention.

## Purpose

A future Naxxramas setup must never apply one installation's permission to a different client's folder, different transaction, different current files or an approval that was cancelled, expired or previously consumed.

Previous milestones established [single-use consent lifecycle fixtures](CONSENT-LIFECYCLE-REVIEW.md) and a [recovery conflict safeguard](RECOVERY-CONFLICT-SAFEGUARD.md) that protects changed player files. This milestone connects them conceptually to **actual observed** Windows recovery session bytes and selected directory identities, while preserving a crucial distinction: a **caller-authored owner or latest-state claim is not genuine owner identity or independently trusted history**.

## Tool and inputs

Read-only tool:

`tools/Review-Naxxramas-RecoveryAuthority.ps1`

All of these inputs are **required**:

- `-ClientPath` — an existing, local test client folder
- `-SessionDirectory` — separately held existing recovery session with `session.json`
- `-ReceiptFixturePath` — existing synthetic approval claim JSON
- `-AuthorityFixturePath` — existing synthetic latest-state claim JSON

The two fixtures may be in different files but are **not independently protected**. The reviewer does not create them or attempt to decrypt/sign them. Input arrays are strict, positional, UTF-8, at most 4096 bytes per file. Reparse/junction ancestry and unexpected schemas are rejected.

## Versioned fixture schemas

The receipt has **11 fields**:

`[1, receipt_id, session_id, session_json_sha256, client_dir_sha256, session_dir_sha256, nonce, sequence, issued_unix, expires_unix, consent_status]`

The latest-state claim has **8 fields**:

`[1, session_id, client_dir_sha256, session_dir_sha256, latest_issued_sequence, consumed_through_sequence, latest_nonce, authority_status]`

Fields are restricted to bounded JSON integers, 8–80-character ASCII identifiers, lowercase 64-digit SHA-256 strings, and enum labels. Consent labels are `explicit_confirmed`, `pending`, `revoked`, `expired`. Authority labels are `claimed_current`, `missing`, `stale`, `foreign_owner`, `unverified`.

The synthetic receipt expiry must be strictly later than issuance and at most one hour later. The inspector also reads the Windows local UTC clock to flag a claimed future or expired receipt. **The local clock is not an independently authenticated clock.**

## What is checked against live read-only observations?

The tool:

1. Reads the actual `session.json` digest before doing other inspections.
2. Runs the existing [Windows directory identity inspector](WINDOWS-DIRECTORY-IDENTITY.md) on both the client and recovery-session folders.
3. Runs the existing [Recovery Conflict Safeguard](RECOVERY-CONFLICT-SAFEGUARD.md), which compares synthetic before/installed values against actual existing client/backup contents, detects conflicts and preserves player edits.
4. Rechecks the actual session file digest after the scans and reads the current session ID.
5. Compares the **claimed** receipt and authority values to the session ID, current session bytes and observed directory fingerprints.
6. Flags wrong nonce, older receipt sequence, contradictory consumed-through counters, revoked/expired claims, and absent/stale/foreign authority claims.
7. Returns only human-review labels. It never exposes the receipt's nonce, target absolute paths, original file hashes, or file contents.

### Selected report blockers

| Condition | Blocker |
| --- | --- |
| Receipt or local authority points to a different transaction | `transaction_session_binding_mismatch` |
| Session bytes differ from the receipt's claimed hash | `session_bytes_changed_since_receipt` |
| Client or session folder no longer matches | `client_directory_binding_mismatch` / `session_directory_binding_mismatch` |
| Receipt nonce differs from latest-state claim | `receipt_nonce_not_latest_claim` |
| Claimed sequence no longer latest | `receipt_sequence_not_latest_claim` |
| Used/consumed-through sequence includes this receipt | `receipt_reported_as_already_consumed` |
| Revoked/pending/expired receipt | `consent_not_current` |
| Missing/stale/foreign/unverified authority claim | `independent_latest_state_not_proven` |
| Claimed expiry has elapsed on local machine | `receipt_expired_according_to_local_clock` |
| Actual recovery inspection reports player edits or unsafe operations | `recovery_requires_independent_manual_review` |
| Session modified between first and second digest readings | `session_changed_during_authority_review` |

All outputs unconditionally set `real_owner_authenticated=false`, `independent_latest_state_verified=false`, `approval_receipt_authenticated=false`, `nonce_replay_prevented=false`, `records_real_consent=false`, `allow_file_writes=false`, `allow_automatic_resume=false`, `authorises_rollback=false`, `authorises_file_deletion=false` and `public_distribution_authorised=false`.

The best possible output is **`caller_claims_consistent_NOT_AUTHENTICATED`**. It is *not* approval for installation or restoration and is only reachable when existing recovery inspection proposes no file changes.

## Security limitation: full coherent replay is invisible

Imagine a previous receipt and latest-state file legitimately claimed issuance of token sequence 3. Later the token was used, and the current sequence became 7. If someone restores **both** old files, including their correct nonce and previous consumed-through value, they can look locally consistent again. If the session data and folder identity also match, a read-only inspector cannot tell that a newer state ever existed.

**This test intentionally demonstrates such a coherent forgery/replay.** Two differently named files, an unkeyed hash, a Windows file ID, or DPAPI encryption alone are **not a monotonic, independently protected latest-state authority**. Offline use, migration, backup/restore and lost-key recovery require an explicit risk decision before genuine receipts can be introduced.

Even if independent authority were eventually provided, a production writer would still need genuine *human* consent, separately verified patch provenance, stable Windows file/directory handles, original backups, crash-safe commit semantics and preservation of player edits. None is implemented in this milestone.

## Windows synthetic tests

From a checked-out repository on Windows PowerShell 5.1:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-RecoveryAuthority.ps1"`

The GitHub workflow `.github/workflows/recovery-authority-fixtures.yml` creates disposable **fake** client, session, original backup and local fixture files. It checks correct-but-untrusted claims; wrong nonce, sequence, consumed claim, revoked/expired consent, missing authority, changed folder identity, foreign session, changed journal bytes, player-edited file, malformed data, coherent forged old state and report privacy.

**No real World of Warcraft content, MPQs or genuine player files are required or modified.** The runtime tool itself is read-only, and the fixture writer exists in the isolated test harness only.

Related: [Trust Continuity Review](TRUST-CONTINUITY-REVIEW.md), [Journal Authority](JOURNAL-AUTHORITY.md), [Recovery Conflict Safeguard](RECOVERY-CONFLICT-SAFEGUARD.md), [Roadmap](ROADMAP.md), [Project Handover](PROJECT-HANDOVER.md).
