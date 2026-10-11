# Read-only installation registration review — synthetic fixtures

**Status:** synthetic, developer-only, read-only Windows PowerShell 5.1 test tool. **NOT** a real installer registration, journal, rollback system or security authority.

## Goal

A future Naxxramas Client Setup must distinguish the owner's *approved* WoW client from a renamed folder, a newly copied folder, a replaced directory, lost installation registration, or an interrupted installation. The current module does **not** create or protect any registration. It compares deliberately **caller-controlled, unsigned, untrusted** fixture records with Windows' read-only directory identity observation.

The command is `tools/Review-Naxxramas-RegistrationFixture.ps1`. It internally invokes the existing `tools/Inspect-Naxxramas-DirectoryIdentity.ps1` and does not call any installer or recovery writer.

## Fixture schema

Both inputs are positional JSON arrays, not objects. Object/duplicate-field ambiguity is avoided, and unexpected fields are rejected.

- **Registration fixture:** `[1, installation_id, folder_fingerprint_sha256, patchset_id, last_committed_sequence]`
- **Session fixture:** `[1, installation_id, session_id, patchset_id, last_observed_sequence, checkpoint]`

IDs allow ASCII letters, numbers, underscores and hyphens, 8–80 characters. Fingerprints are lowercase 64-character SHA-256, patchsets follow `patchset-0001` numbering, and both sequences are JSON integers between 0 and 100,000,000. Fixture JSON is capped at 16 KiB per file.

The registration's `last_committed_sequence` is **only a fabricated test field**, not a protected monotonic counter. The tool does not verify a journal's actual signed event chain or validate genuine V/Z patch files; the `checkpoint` is an *asserted test value*, not independent evidence.

## Review behaviour

| Observed situation | Output status | Permits writes? |
| --- | --- | --- |
| Registration missing | `manual_review_registration_missing` | No |
| Session missing | `manual_review_session_missing` | No |
| Selected folder missing/unsafe or identity unavailable | `manual_review_folder_unavailable` | No |
| Copied/replaced folder (fingerprint differs) | `manual_review_folder_identity_changed` | No |
| Different installation ID | `manual_review_installation_mismatch` | No |
| Different patchset | `manual_review_patchset_mismatch` | No |
| Session sequence behind registered value | `manual_review_stale_session` | No |
| Session sequence ahead of registered value | `manual_review_uncommitted_sequence` | No |
| Session not completed or has zero events | `manual_review_interrupted_or_uncommitted` | No |
| Both untrusted fixture records appear consistent | `fixture_fields_consistent_NOT_trusted` | **No** |

Malformed, oversized, unsupported or unexpected fixture data throws a blocking error rather than producing a trusted status.

The output always contains `allow_file_writes: false` and `authorises_rollback: false`. It omits the game folder's absolute path and actual fingerprint. No permanent registration, Windows registry key, DPAPI secret, backup or journal is ever created.

## Test suite

Run from the repository checkout on **Windows PowerShell 5.1**:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-RegistrationFixture.ps1"`

The test suite generates a tiny fake client with text files, then checks copied vs renamed folders, changed/missing registration, mismatching installation IDs and patchsets, old and ahead-of-anchor sequences, every unfinished checkpoint, bad JSON/integers and read-only file snapshots. It includes two **intentional demonstrations of the missing security boundary**:

- When the caller changes registration data to match an entirely new copied directory, the fixture's fields can look *consistent*. The tool still permits no writes.
- When both user-controlled registration and session numbers are replayed backward together, their fields can also look *consistent*. Again, no writes.

These are expected **limitations of the fixture**, not claims that spoofing or replay has been prevented.

## How production registration must differ

The future writing installer would need an independently reviewed registration flow with explicit owner consent and a safeguarded client folder:

1. Record a separately protected local installation identity **only after** the user explicitly approves exact proposed operations and a safe, verified client copy.
2. Protect the latest committed journal state against accidental loss and unauthorised edits, with careful key lifecycle. **DPAPI and ordinary local HMAC files do not guarantee anti-rollback if all state can be replaced together.**
3. Treat registration loss, migration, copied clients, unknown filesystems, stale/wrong journal sequences, interrupted checkpoints and new player edits as **manual-review cases**, not opportunities to regenerate trust automatically.
4. Bind the approved target, patchset, backup locations, per-file hashes and all required V/Z invariants to a reviewed transaction journal. Current fixture flags are not source-of-truth.
5. Design interruption-safe backup and journal sequencing, with verified flush and atomic-replace semantics where genuinely supported; stop after any ambiguous crash boundary.
6. Reinspect safely opened Windows file/directory handles and the real on-disk files **immediately before** any future write. The read-only preview cannot eliminate path races.
7. Test rollback of a partially completed **disposable fixture** without touching the working client, and require a separate development approval gate before implementing even test-only writes.

For related designs see [Journal Authority](JOURNAL-AUTHORITY.md), [Journal Durability](JOURNAL-DURABILITY.md), [Directory Identity](WINDOWS-DIRECTORY-IDENTITY.md), and the [Project Handover](PROJECT-HANDOVER.md).

**Never interpret “consistent” as “approved.”** All current code remains strictly read-only.
