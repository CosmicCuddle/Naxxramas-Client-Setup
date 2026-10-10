# Installer Milestone 2 — Read-only plan preview

**Status:** development prototype, **not** an installer. No game files, custom MPQs, addon folders, or realmlist settings are changed.

This first planner creates a preview for WoW 3.3.5a build 12340 (enUS) using `config/client-patches.json` and `config/realm.json`. It cannot download patches, install a client, update addons, or roll back changes.

## Basic Windows instructions

1. Make a backup of your working client. For later installation experiments, use **only a separate copy**.
2. Download the latest repository ZIP and extract it **outside** the WoW client folder.
3. Open `tools` and drag the **folder containing `Wow.exe`** onto **`Plan-Naxxramas-Install.bat`**.
4. Read the displayed proposed actions. This first click-and-drag mode checks the existing client files; it does **not** automatically select an external patch source or either optional visual theme.
5. **Do not copy or delete anything based on the preview alone.** The write-capable installer has not been built.

The tool reads patch files to calculate SHA-256, so larger patches may take time to check. It never writes its output to the WoW folder or uploads data.

## Advanced option: preview a separate local patch source

Open PowerShell in your extracted repository folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Plan-Naxxramas-Install.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Naxxramas-Local-Source" -VanillaLogin -VanillaLoading
```

- `-ClientPath`: existing **destination** client to inspect.
- `-PatchSourcePath`: **optional, separate, non-nested local folder** containing verified patch files in `Data`; never a download URL.
- `-VanillaLogin`: select optional J for the future setup plan.
- `-VanillaLoading`: select optional U for the future setup plan.
- `-RealmHost`: optionally preview a different *plain host or IPv4 address* without changing the repository.
- `-Json`: return the machine-readable preview to the console instead of the friendly summary.

The two mandatory patches V and Z are **always selected**. Without an external source, the planner can check existing correct files but cannot propose supplying missing ones. An optional patch that already exists but was **not** selected will be left alone; it is not a removal command.

The script expects the same current patch SHA-256 and byte size that are recorded in `patchset-0001`. If the local file differs unexpectedly, the planner blocks or warns rather than silently replacing it.

## How to read the results

| Action | Meaning |
| --- | --- |
| `no_change` | File already matches the reviewed requirement; leave it as-is. |
| `install` | A selected file is missing and its reviewed source is present, or a missing realmlist can be generated. **Preview only.** |
| `replace_after_backup` | A known older patch or different realm address is present. Any eventual installer must back up exact original bytes and obtain approval. |
| `blocked` | Missing verified source, unknown patch contents, unrecognised configuration or other safety issue. Do not proceed automatically. |
| `not_selected` | Optional feature absent and not requested. |
| `leave_existing` | Optional patch not selected but already present, or a valid realm address has additional user content. Preserve it. |

Each patch entry includes `required`, `selected`, `destination_state`, `source_state`, SHA-256, size, `backup_required` and a reason. The plan also contains warnings, blockers and an estimate of the space needed for a *future* staged copy and backup.

**The result `review_only_no_blockers` does not mean 'safe to install' or 'licence approved'.** Executable metadata, source integrity, free space, and path checks are necessary but not sufficient for a production installer.

## Safety model in this prototype

- No in-game assets or binaries are copied, modified, uploaded or downloaded.
- Paths are read only after rejecting links/junctions and patch-source/destination overlap.
- Only the four explicitly named custom patches and the exact enUS realmlist path are considered. The tool does not touch `WTF`, `Cache`, addons, logs, screenshots, other MPQs, executables, or DLLs.
- Current patch checks use both pinned SHA-256 and byte size. Known older hashes are identified from the historical patch manifest, without authorising writes.
- Unknown existing core/selected optional patches cannot be overwritten.
- A realmlist with a different recognised address is marked for a *potential* backup-first change. Other unrecognised realmlist content is blocked or preserved.
- Existing files to be replaced are included in an estimate of future backup and staging space. This is a conservative **estimate**, not a guarantee.
- A failed executable-build check is blocking. A fake binary used in tests naturally fails this check while other per-file actions remain testable.
- If J and U are both selected, the planner reports their known texture overlap. In-game precedence is **still untested**.
- All four current MPQs have `public_distribution_approved: false`. This tool does not grant permission to share or package them.

## Automated synthetic tests

The repository includes `tests/Test-InstallerPlan.ps1` and a Windows PowerShell GitHub Actions workflow. Test fixtures contain tiny generated text files pretending to be patches and a **test-only generated executable** with synthetic build-12340 metadata. No real WoW client or proprietary game assets are needed for the tests.

The test script exercises: mandatory patches current/missing, verified source vs no source, unknown versions, known older versions, individual optional choices, preserving unselected optional files, J/U warning, realmlist changes, incorrect source hashes, source/destination collision and checksums of all client fixture files before/after each preview.

To run from a Windows PowerShell 5.1 console in the repository directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-InstallerPlan.ps1"
```

The tests create and then delete their **own** disposable temporary fixtures. They are not intended to be run against any genuine game folder.

## Not implemented yet

A finished setup GUI, an installation plan approved for execution, private asset provenance/permissions checking, addons installation, automatic backups, staged copying, failure recovery, update, rollback, uninstall and public distribution remain future milestones. See [ROADMAP.md](ROADMAP.md) and [PROJECT-HANDOVER.md](PROJECT-HANDOVER.md).

**Verified 10 October 2026:** GitHub's Windows PowerShell 5.1 fixture suite passed on [PR #3](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/3), including the non-blocking supported-build preview. The existing preflight tests also passed after its test-harness exit-code fix on [PR #2](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/2). These are **synthetic tests only**, not a demonstration against real game assets or an installer.

**Next action:** add deterministic low-space and remaining failure-path tests, then build a separate **read-only** journal recovery evaluator based on [Transaction Design](TRANSACTION-DESIGN.md).
