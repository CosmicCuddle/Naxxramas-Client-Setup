# Milestone 4 — Guided Windows setup wizard (read-only)

**Status:** A working Windows Forms **review window**, not an installer. No copying, patching, backups, downloads, registration, genuine consent, uninstall or recovery actions exist. The wizard never calls a write engine.

## Player experience

Double-click `tools/Start-Naxxramas-SetupWizard.bat` from a copy of this GitHub repository on **Windows with Windows PowerShell 5.1**. The launcher starts the read-only `tools/Start-Naxxramas-SetupWizard.ps1` in STA mode, which Windows Forms requires.

The interface offers three clearly labelled sections:

1. **Choose folders:** your existing World of Warcraft 3.3.5a build 12340 enUS client, a separate folder with the local patch files you already legally possess (where needed), and a separate existing backup folder that a future approved installer would use. The three **Browse...** controls allow selecting existing directories. New folders cannot be created through the picker.
2. **Optional appearance:** independently choose **Vanilla login screen (Patch-J)** and **Vanilla loading screens (Patch-U)**. Core patches V and Z are mandatory for this setup and deliberately have no off switch. Enter an optional plain-text realm host override, or leave it blank to use the configured server address.
3. **Review proposed changes:** choose **Review Only**. The scrollable result explains each of the five known game file paths and proposed keep/add/replace-after-original-backup/blocked action. It includes estimated space, backup requirements, selected options and source/preflight warnings. **Clear Review** clears the result; **Close** exits.

There is **no Install, Apply, Approve, Copy, Backup, Remove or Rollback control**, even when the preview has no blockers. This window does **not collect user consent**.

The program invokes the existing [Player Installation Review](PLAYER-INSTALL-REVIEW.md), which invokes the existing **actual read-only local installer planner**. It does not invent its own patch policy or download custom MPQs.

## Accessibility

- Clear numbered headings, stable five-file review order, readable Segoe UI text, sufficient contrast and non-colour-only written status.
- All folder textboxes, Browse buttons, independent cosmetic patch checkboxes, realm textbox, Review/Clear/Close buttons and scrollable output are keyboard accessible. **Enter = Review Only**, **Escape = Close**.
- Result text is scrollable, selectable but **read-only**.
- After changing a folder, realm address or optional checkbox, the old result is cleared and the player must request a fresh review. This avoids displaying an earlier preview as though it still describes the chosen options.
- A failed scan shows a plain-language error and stops; it does not silently skip failed checks or try to fix files.
- The UI does not print the selected absolute client/source/backup paths inside the saved review text. Folder textboxes naturally display the user-selected local paths **on their own computer**; no upload or telemetry takes place.

## Installation and backup scope

The wizard **does not create or validate durable backups**. It only *explains* originals that would need exact byte preservation before any future replacement. It does not issue single-use authorization, hold file handles after a preview, authenticate a Windows owner or independently check replay-resistant latest transaction history.

You may inspect your own existing client read-only, but use a **separate backed-up client copy** for development experiments and never treat a no-blocker review as permission to modify a game installation. Private V/Z/J/U archives are not hosted or redistributed by this project; legal source rights are not inferred from checksum matches.

## Developer commands

Ordinary window:

`powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\tools\Start-Naxxramas-SetupWizard.ps1"`

Optionally pre-populate the folder textboxes and J/U choices:

`powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\tools\Start-Naxxramas-SetupWizard.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Local-Patches" -BackupRoot "F:\Separate-Backups" -VanillaLoading`

These paths are **examples only**. Neither command creates those paths or writes anything.

Headless Windows Forms construction/metadata diagnostic, **never displays the window**:

`powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\tools\Start-Naxxramas-SetupWizard.ps1" -Diagnostics`

Headless read-only planner bridge (requires a supported **existing** client folder):

`powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\tools\Start-Naxxramas-SetupWizard.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Local-Patches" -BackupRoot "F:\Separate-Backups" -PreviewJson`

The diagnostic flags are intended for developers and CI, not installer approvals.

## Windows CI and what it proves

Run:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-SetupWizard.ps1"`

The workflow `.github/workflows/guided-windows-setup.yml` checks:

- A **real** Windows PowerShell STA Windows Forms window can be constructed without showing it in CI.
- Three independent folder input/picker pairs, two optional checkboxes, no core patch toggle, keyboard Review/Close defaults, read-only result and absence of installer/approval controls.
- The same GUI review bridge calls the already-tested real local planner with a **disposable fake** client, versioned fake `Wow.exe`, fake old V/current Z, unselected existing J, locally supplied new U, changed realmlist and separate original-backup sentinel.
- The old V and realmlist are shown as requiring future preservation; absent selected U as a hypothetical addition; unselected J is preserved. Missing backup folder or unknown V produces a blocked preview.
- No changes to the fake client, source or existing backup files and no private absolute-path leakage through diagnostics.

CI runs on Windows PowerShell 5.1 and fake files only. No genuine Blizzard client, custom patch archives, credential stores or Windows registry state are used.

## Safety gates before enabling any installation

The owner has **not yet selected the offline-vs-independent-latest-state** approval model; that impacts how single-use authorization and historical replay protection can be claimed. Any future write-capable installer must separately address: genuine accessible user consent, authenticated current owner/client registration, protected spent-token/latest journal state, race-resistant Windows file/directory handles, separately preserved **durable verified** originals, source rights and non-destructive crash recovery.

Until those issues are resolved and reviewed, this GUI will remain a **Review Only** tool.

Related: [Roadmap](ROADMAP.md), [Project Handover](PROJECT-HANDOVER.md), [Player Installation Review](PLAYER-INSTALL-REVIEW.md), [Owner Recovery Policy](OWNER-RECOVERY-POLICY.md).

## Larger file details and clearer errors (PR #29)

The **View File Details...** control starts disabled. After a successful read-only review (even if the planner reports blockers), it opens a **larger, separate read-only window** showing exactly five rows in the mandatory V/Z, optional J/U and realmlist order. The table has an explicit proposed-action column and an **Original backup first?** column that says **YES - not created** where an existing original would need preservation. A separate scrollable area shows warnings, blockers and the existing planner's notes. Only **Close Review** is available inside this window.

The wizard calls the existing real player-reviewer **once per Review Only click** in JSON mode, checks its fixed allowlist and no-write/no-consent flags, and formats both the small summary and expanded table from **that same inspection**. This avoids two presentations accidentally referring to two different file scans. Editing a folder, cosmetic checkbox or realm address **clears the result and disables View File Details**, so a previous review cannot be reopened against changed selections.

When a required client path is empty or a selected folder does not exist, the wizard now explains which folder needs attention instead of merely showing a generic scan failure. Failures from version/hash/storage/safety checks remain fail-closed: the UI recommends checking the supported client, local sources and separate backup location, without exposing an internal error path or offering a bypass.

### Manual Windows accessibility and layout check (not automated)

The GitHub Windows tests build the controls headlessly but do **not** prove the appearance, screen-reader behavior or layout at every display scale. When reviewing on a backed-up **test** client:

1. Open the `Start-Naxxramas-SetupWizard.bat` launcher. Confirm the initial **View File Details** button is disabled and no Install/Apply/Approve option exists.
2. Use **Tab**, **Shift+Tab**, **Enter** and **Escape**; confirm the result text can be read and scrolled with the keyboard.
3. Run **Review Only**, then open **View File Details**. Confirm five readable rows, clear backup labels and a usable scrollable warning panel.
4. Change a folder field, the realm override and each optional J/U checkbox. Verify the old result clears and the details button disables each time.
5. Try an absent folder and a deliberately invalid **fake** patch in a disposable fixture; confirm a helpful message or blocked review and no modification.
6. Resize both windows and check 100%, 125%, 150% and 200% Windows display scaling where available. Check high contrast, keyboard focus and any screen-reader labels; record clipping issues for subsequent fixes.
7. Close the review and wizard without changing your client. Verify the original test-client and backup files were preserved.

**Not yet proven:** hands-on appearance at every screen resolution and accessibility configuration. Headless CI verifies actual Windows Forms construction, five-file table contents, disabled editing/approval and synthetic no-write behavior; it is not a substitute for visual exploratory QA.

**The only actions implemented are inspect, clear the display, inspect details and close the window.**
