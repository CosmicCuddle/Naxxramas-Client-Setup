# Milestone 3: disk budget and suite ZIP verification

**Status: test-only. All installation writes remain locked to disposable fixtures.**

## 1. Disk-space budget (implemented)

Before creating a transaction session, Setup-Prototype.ps1 calculates:

- Sum of every new file that must be staged (patches, realmlist, selected addon files).
- Sum of existing files needing a verified backup.
- One additional buffer equal to the largest backed-up file (for temporary restoration).
- 128 MiB safety margin.

The estimated requirement is compared with the Windows target drive's reported available free bytes. The plan displays both values. Test installation **stops before any journal, backup or game file is changed** when available space is insufficient.

A synthetic low-disk test uses `-SimulateFreeBytes 0` and is accepted only when an exact disposable-fixture marker exists. Real-client installation stays disabled; this parameter is not for end users. Real-world storage quotas, permissions, antivirus interference, disk faults and multi-user free-space changes are not completely covered by this estimate.

## 2. Verifying the N Addon Suite v2.0.0 ZIP

The project's official [GitHub release](https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0) supplies the reference archive:

- Asset: `N-Addon-Collection-v2.0.0.zip`
- Size: **26,762,217 bytes**
- SHA-256: `07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324`

The values are recorded in [config/addon-suite.json](../config/addon-suite.json). They were read from the release asset's published metadata, not a separately signed authenticity certificate.

**Read-only checker:**

1. Obtain the suite ZIP from the project's official v2.0.0 release.
2. Drag the ZIP onto `tools/Verify-Addon-Release.bat`.
3. The tool compares file size and SHA-256 with the pinned reference and checks for the five expected addon TOC filenames inside the archive.
4. If anything differs, it fails without extracting or changing files.

The checker validates the supplied ZIP against that recorded reference. **It does not verify an arbitrary previously extracted addon folder**, and the test-only installer still reads a local folder without cryptographically linking it to the archive. This limitation must be fixed before any production addon setup. N Talent Calculator is excluded from v2.0.0. NCore must always be installed when the suite is selected.

## 3. Current automated tests

The Windows GitHub Actions workflow runs preflight, reversible-installation fixture tests and synthetic ZIP tests. Those tests verify:

- Low-disk installation refusal without generating setup state.
- Stage/backup/rollback file handling with dummy data.
- Incorrect ZIP digest rejection.
- Matching fingerprint but missing addon TOCs rejected.
- No real game, account or addon release content is used by the test fixtures.

## Remaining before player release

- Verify user-downloaded real v2.0.0 ZIP in a controlled manual test and safely extract directly from that verified archive.
- Harden post-crash journal handling and recovery around Windows ACL errors and disk-full conditions.
- Confirm source/target filesystem constraints and rollback behavior with a non-sensitive test installation containing representative sizes.
- Review redistribution rights and provenance of all custom MPQ files.
- Build an accessible Windows GUI with a preview, approval, progress details and an explicit undo path.
- Keep mandatory V/Z verification for every update; preserve older patch-set records.

Do **not** remove the disposable fixture guard based only on synthetic automated test success.
