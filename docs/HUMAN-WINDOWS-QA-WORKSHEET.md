# Human Windows QA Worksheet — How to use it

**Developer-only, read-only planning. No real tests have been performed.**

This creates a clear printable **NOT TESTED** checklist for the six legal patch combinations and two forbidden login selections for a potential `patchset-0003`. It never installs patches, starts the game, scans your computer, creates backups, contacts a server or publishes evidence.

It reuses:
- [The established six-plus-two manual QA plan](PATCHSET3-MANUAL-QA-PLAN.md).
- [The existing disposable test-copy patch preflight](DISPOSABLE-CLIENT-READONLY-PREFLIGHT.md).
- [The strict, private human self-report record](PATCHSET3-MANUAL-QA-RECORD.md).

## Step 1 — Generate the example checklist

In a **trusted source checkout** with Python 3.12:

```powershell
py -3.12 tools\print_windows_manual_qa_checklist.py --proposal tests\fixtures\synthetic-patch-proposal-v3.json --release-snapshot tests\fixtures\public-release-metadata-v1.json
```

The checklist prints to your console. **The bundled proposal is deliberately synthetic** and the release data is a frozen metadata snapshot: it is not a real newly released patch, a verified source, or an approved client. No real test data is supplied.

If you personally choose to retain a copy, use your own private location outside the WoW folder or Git checkout and ordinary shell redirection. The generator itself performs **no write**.

## Step 2 — Complete preconditions *before* human testing

Only with separately granted testing permission and a lawful, genuinely separate disposable game copy:

1. Protect the actual original client and **all** WTF account/realm/character settings, and independently verify the backups can be restored.
2. Verify the test game’s `Wow.exe` file properties show the expected 3.3.5a build 12340 and confirm against an independent trustworthy baseline. **Version metadata alone can be changed or spoofed.** Also check the actual enUS files and source legitimacy.
3. Confirm rights and privacy rules for any captured evidence; do not share screenshots containing account names, chat, realm addresses or personal information.
4. Prepare a separate clean test copy or independently verified reset snapshot **before each case**. Do not modify the primary client, and do not put the marker in your working client.

The checklist prints the exact `--selection` command for each case. Only the operator, after permission, may run that separate read-only preflight. It requires a caller-created, exact marker in the test copy. The **marker is not proof of separate storage or safety**.

**Important: the currently merged preflight checks frozen patchset-0002 V/Z/J/C/U SHA-256 and size. A future hypothetical changed patchset-0003 requires separately reviewed, independently obtained *new* actual byte references. Do not treat successful v2 preflight as authentication of changed v3 patch bytes.**

## Step 3 — Run the six cases separately

| Case | Required patches | Optional patches |
| --- | --- | --- |
| `base` | V + Z | None |
| `u` | V + Z | U |
| `j` | V + Z | J |
| `j-u` | V + Z | J + U |
| `c` | V + Z | C |
| `c-u` | V + Z | C + U |

The printed checklist gives each case its own **NOT TESTED** steps: test client baseline, required hashes, actual physical absence of unselected optional patches, game start/realm entry, character gameplay and no unexpected mutation of originals/WTF. It adds J or C login art/music/controls and U normal/widescreen loading screens when relevant. J+U includes the known **two overlapping loading texture paths** that need actual in-game observation.

If the preliminary read-only file check detects an extra optional patch, missing file or different bytes, **stop and record the issue**. Do not overwrite or delete the unexpected player file. The preflight does not launch WoW or test gameplay.

## Step 4 — Verify rejection, never force conflicting patches

The two negative cases are `j-c` and `j-c-u`. They should be tested only with an independently reviewed **selection-only or dry-run** user interface that rejects C+J **before** any file write. If no such safely authorised interface exists, report **BLOCKED / NOT TESTED**; do not install mutually exclusive login MPQs simply to demonstrate a conflict.

## Step 5 — Physically test Windows accessibility

Each test must be observed in a reviewed **non-writing interface**, not inferred from headless GitHub CI.

- Test **100%, 125%, 150%, 200% and 300%** display scaling. The 300% row was added after partial owner-reported visual observation, not a full accessibility PASS.
- Check clipped or overlapping controls, long labels/errors, keyboard Tab and Shift+Tab focus order, and reliable non-writing cancellation.
- Check High Contrast visibility and screen-reader/Narrator labels and feedback.

These are **still NOT TESTED** on actual Windows hardware.

## Step 6 — Record results privately and separately

Use the existing [manual QA record format](PATCHSET3-MANUAL-QA-RECORD.md) to classify actual checks as `NOT_TESTED`, `PASS`, `FAIL` or `BLOCKED` only when genuinely observed. The already implemented [two-report comparison](PATCHSET3-TWO-REPORT-REVIEW.md) detects disagreements but cannot prove two people actually performed tests.

A complete report still needs independently authenticated observer/custody, source and copyright review, true backup durability/restoration, independently protected freshness/anti-replay state and explicit owner approval. No checkbox generated by the new tool is completed automatically. **This is a preparation aid, not an installer or release gate.**

## CI limits

The Windows/Linux tests assert that all eight scenarios remain present, every check is initially uncompleted, privacy-sensitive input isn't echoed, fabricated PASS states are refused, J/C isn't offered as a legal selection, patchset-0002 versus proposed patchset-0003 is distinguished, and no current policy/history files change. They use only checked-in **fake proposal metadata**, never actual game assets or human test results.

**Existing WoW files, player addon settings, saved variables, immutable patch history, backup and public-release permissions are untouched.**
