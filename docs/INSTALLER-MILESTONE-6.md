# Milestone 6 — Atomic journaling and read-only recovery inspection

**Status: synthetic Windows test fixtures only. No production installation or real-client writes are enabled.**

## What changed

The backup-first installer has two persistent records inside `.naxxramas-setup`:

- `active.json` points to the session being installed or recovered.
- `sessions/<session-id>/manifest.json` records the original hashes, intended hashes, and recovery status.

If Windows or the computer stops unexpectedly during a journal update, incomplete `.writing` files may be left behind.

We now write a JSON record to a **same-directory temporary file**, flush its content, then use an atomic filesystem replacement for an existing record (or a move for a new one). This avoids intentionally truncating an earlier valid journal before writing the next state.

This does **not** guarantee protection from drive or OS failure, external interference, an invalid disk, or all possible sudden power-loss conditions. It substantially reduces a common partial-write window in normal Windows filesystem operation.

## Read-only inspection

Run the test tool in `-Action Inspect` mode, or drag the client folder onto **`tools/Inspect-Naxxramas-State.bat`**.

The inspection only reads: it reports whether a session is absent, prepared, applying, restoring or installed; warns about orphan sessions and unreadable journals; and identifies incomplete `.writing` files.

It does **not** delete, rewrite, repair, back up, roll back or install files.

## Conservative recovery

If any journal `.writing` residue is detected, the program refuses all installation and recovery write commands. This is deliberate: it cannot know whether the temporary record represents newer state than the current journal without further analysis.

**Never delete that file or change the journal by guessing.** Preserve the state directory and request an expert review.

When the main transaction journal itself is damaged, inspection reports it, and guarded recovery is refused.

## Automated tests

The synthetic Windows tests now cover:

- Inspect with no state, with an interrupted application and with corrupt JSON.
- A simulated interrupted write leaving `manifest.json.writing`.
- Refusal to recover while incomplete journal files exist.
- Refusal to recover when the committed journal is invalid.
- Confirmation that those diagnostic and refusal paths leave existing client bytes unchanged.
- Existing end-to-end tests for ordinary staging, backup, interrupted installation and rollback.

## Still required before production

- Verify Windows ACL/access-denied errors and file locking with controlled full-sized fixtures.
- Audit symlink/junction, TOCTOU, rollback journal authenticity and on-disk permission boundaries.
- Design an explicit, reviewed recovery procedure for orphan sessions and incomplete journal writes.
- Confirm custom patch redistribution permissions and finish verified update packaging.
- Build a friendly Windows GUI and conduct manual end-to-end testing on disposable clients.

Do not remove the fixture guard yet.
