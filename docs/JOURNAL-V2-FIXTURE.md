# Synthetic signed journal v2 — read-only validation prototype

**Development status:** test-fixture format only, **not** a production trusted journal.  
**Code:** `tools/Inspect-Naxxramas-JournalV2.ps1`  
**Tests:** `tests/Test-JournalV2.ps1`

The purpose of this tool is to explore how an installation record could detect accidental modifications, missing events, reordered steps or a mismatched session anchor **before** we build any backup or rollback operations.

The validator does not copy, install, restore, delete or modify any WoW files. It reads **three deliberately supplied fixture files**: an envelope, an anchor and a generated 32-byte test key. The test runner creates these files inside a disposable temporary directory and removes them afterwards.

**Do not use it against real game clients, live backups or personal key files.** There is no production installation journal yet.

## Why an array envelope?

The prototype uses JSON arrays rather than JSON objects so duplicate property names cannot be interpreted differently by different JSON parsers.

- `envelope.json` is an array: `[2, [ [base64_event, lower_case_hmac_sha256], ... ] ]`.
- `anchor.json` is an array: `[2, session_id, installation_id, last_sequence, head_payload_sha256, lower_case_anchor_hmac_sha256]`.
- The test-only key file contains exactly 32 random bytes, **never committed**.

Each event is a base64 representation of a **single ASCII text record** with 15 strictly ordered pipe-separated fields, signed over the **exact decoded bytes** (not reserialized JSON). Version and field delimiters are fixed.

| Position | Value | Constraint |
| --- | --- | --- |
| 0 | `NXJ2` | Literal format marker |
| 1 | Session ID | ASCII letters/numbers, underscores or dashes, 8–80 characters |
| 2 | Installation ID | Same ID format |
| 3 | Sequence | Canonical positive integer; first is 1 |
| 4 | Patchset | `patchset-XXXX` |
| 5 | Event checkpoint | `planned`, `approved`, `backup_verified`, `write_started` or `verified` |
| 6 | Relative path | One of the exact five managed patch/realmlist paths |
| 7 | Action | `install` or `replace_after_backup` |
| 8 | Previous event payload SHA-256 | Sixty-four zeros for the first event |
| 9 | Original SHA-256 | Lowercase SHA-256, or `-` when newly created |
| 10 | Installed SHA-256 | Lowercase SHA-256 |
| 11 | Original byte length | Canonical non-negative integer, or `-` if created |
| 12 | Installed byte length | Canonical non-negative integer |
| 13 | Original backup path | `originals/0001.bin` format, or `-` if created |
| 14 | Target build | `12340` |

All values are confined to their specific syntax, avoiding ambiguous separators and hidden line breaks. The per-event signature is HMAC-SHA256 over the exact record bytes. Each event stores a digest of the previous event; the anchor signs the session ID, installation ID, final sequence and final event payload SHA-256.

## Test command (developers)

On Windows PowerShell 5.1, inside the checked-out repository:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-JournalV2.ps1"
```

The test script runs entirely on generated local fixtures and uses a newly generated key. The inspector itself accepts `-EnvelopePath`, `-AnchorPath`, `-FixtureKeyPath` and optional `-Json`, **only** for the synthetic development fixture. Do not provide secrets or logs from a real system.

The test suite checks event and anchor signature tampering, reordered steps, broken predecessor hashes even when re-signed with the fixture key, mismatched sequence/anchor, invalid paths or checkpoints, wrong key, malformed base64, invalid array structure and read-only filesystem snapshots.

## Security guarantees — what this prototype does **not** prove

- The **fixture key** is supplied by the caller, not securely installed or protected by DPAPI. An attacker who controls it can create perfectly valid fixture signatures.
- The **fixture anchor** is also supplied by the caller. If both a journal and its matching signed anchor are replayed together, this prototype cannot recognise the rollback. Its replay test only rejects an **older anchor paired with a newer chain**, not coordinated replay.
- Signed bytes cannot prove that the client was modified by our installer; there is no installed identity or pre-write consent evidence.
- The record format does not authenticate a real file or backup on disk. SHA-256 values here are signed **claims** and not independent file measurements.
- A valid signature does not establish patch distribution rights, malware safety, durability under power failure or in-game compatibility.
- The previous-hash chain is a synthetic event format; checkpoint state transitions, backups, retention, crash-safe storage and Windows authority are still unimplemented.
- This validator is **not connected** to the existing read-only recovery preview, and a successful fixture check must never permit restore/delete operations.

For the longer-term design, see [Journal Authority](JOURNAL-AUTHORITY.md), [Journal Durability](JOURNAL-DURABILITY.md) and [Transaction Design](TRANSACTION-DESIGN.md).

## Next milestone

Agree a production-grade protected trust anchor, local installation identity and crash-tolerant checkpoint protocol. Validate malformed/truncated records and replay scenarios on throwaway Windows fixtures before considering separately authorised fixture-only *write* experiments. No real WoW client should be used.
