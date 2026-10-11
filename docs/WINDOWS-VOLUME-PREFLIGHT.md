# Windows volume identity and capacity preview

**Status:** read-only planner improvement, checked using Windows PowerShell 5.1 synthetic fixtures. This is **not** an installer or permission to modify a client.

## Why drive letters were insufficient

Two Windows paths may refer to the same logical filesystem volume even if the paths are mounted under different drive letters or folders. Conversely, a folder nested inside a drive may host a separate mounted volume. Comparing only `C:\` and `D:\` cannot classify those cases safely.

## How the read-only planner now works

When `-BackupRoot` is supplied:

1. Resolve the selected client and backup paths, rejecting missing paths, volume roots, unsafe nesting, linked/junction locations and source collisions.
2. Ask Windows `GetVolumePathNameW` for the containing volume mount point for each **selected directory**.
3. Ask Windows `GetVolumeNameForVolumeMountPointW` for that mount point's volume GUID path; compare these logical volume identities without showing local IDs in public JSON.
4. If they match, reserve **combined** client staging plus backup bytes on that logical volume. If they differ, reserve the client and backup budgets separately.
5. Ask Windows `GetDiskFreeSpaceExW` for **available bytes at the selected directory** (not just its drive-letter root). This method takes per-user quotas into account where reported.
6. If a local volume GUID or storage availability cannot be determined, return a **blocked** plan. An unknown volume ID is shown as `space_budget.mode = "unverified"`. Never silently fall back to an assumed different drive.
7. Keep all files and directories unchanged. This is planning only.

### JSON fields

`space_budget` contains the same fields as before:

- `mode`: `backup_not_selected`, `shared_volume`, `separate_volumes` or `unverified`.
- `client_volume_required_bytes`: estimated staging / replacement room.
- `backup_volume_required_bytes`: estimated space to preserve originals and journal allowance.
- `combined_volume_required_bytes`: provided when the directories are on the same logical volume.
- `approximation_only`: always `true`; disk-space checks and volumes can change before installation.

The output **does not disclose** the selected local directory paths or actual volume GUIDs.

## Test coverage

The synthetic planner suite verifies:

- The real volume query succeeds for temporary Windows directories.
- Separate folders on the same logical volume are classified as shared.
- A fake probe returns equal volume IDs (simulating aliases), causing a combined budget.
- A fake probe returns distinct IDs (simulating different volumes), causing independent budgets.
- Volume-ID lookup failure blocks the preview.
- Low or inaccessible client/backup disk capacity blocks a proposed change.
- The source, client and backup fixture snapshots remain unchanged.

Mocks are inserted into **temporary copies of the planner**, not exposed as a command-line bypass in production.

## Limitations that still block production writing

- A Windows volume GUID identifies a **logical** volume, **not** a physical drive. Two different logical volumes can share one physical disk, storage pool, thin-provisioned allocation or quota.
- A successful logical volume query does not prove file bytes are durable after a crash, or that an atomic replacement is safe in the actual destination.
- Directory reparse-point checks and subsequent writes are separate operations. A future writer needs handle-based checks to resist filesystem changes between planning and commit.
- A Windows network path or unsupported volume-management interface may fail GUID lookup. **Fail closed** rather than assuming separation; current support is for local Windows volumes.
- Volume mount points and assignments can change. A future installer must re-query and re-verify capacity and identity **immediately before every relevant write**.
- The present `64 MiB` reserves are estimates, not proofs that a future journal and metadata strategy will fit.
- The safe installation source and MPQ redistribution rights have not been approved. This prototype neither copies nor distributes any files.
- True game-client folder ownership, secure journal authority, crash-safe backups and rollback remain future work.

## Microsoft API references

- [GetVolumePathName](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getvolumepathnamew)
- [GetVolumeNameForVolumeMountPoint](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getvolumenameforvolumemountpointw)
- [GetDiskFreeSpaceEx](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getdiskfreespaceexw)

## Next engineering gate

Develop a trusted local installation-identity scheme, then review the feasibility of protecting a **latest committed journal anchor** against rollback of all associated records. DPAPI-encrypting a key alone does **not** make user-writable state monotonic or prevent a same-user attacker from replacing old records. Only after those questions and crash-boundary tests are reviewed should any fixture-only writer be considered. No real client should be modified.
