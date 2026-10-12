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

## Smaller desktops and longer reviews — Milestone 4 follow-up

The main wizard now limits its **initial window height** to the available Windows desktop working area, with a vertical scrollbar for lower controls. The optional J and U checkboxes are on **separate rows**, so they do not collide when space is narrow. The main results area remains read-only and can be reached by scrolling the window; the review text has its own scrollbar.

The five-file details window keeps the grid in view while its **Issues and important notes** text expands on taller windows and remains vertically scrollable. Its footer and Close Review button remain attached to the bottom as the window is resized. Keyboard navigation enters the read-only file table, then warning text, then Close Review; Escape still closes.

Windows CI now asserts scroll layout properties, initial desktop-height fit, separated J/U choices, stale-review clearing for both realm edits and optional changes, and detail-dialog keyboard/scroll configuration. These are **headless structural tests only**; actual Windows 100%, 125%, 150% and 200% scaling, screen-reader announcements, text clipping and appearance still require human exploration on a disposable backed-up client.

**Manual check:** on a small laptop display, use Tab to reach Review Only, scroll down to read the results, open View File Details, resize it vertically, and navigate through the table, long warnings and Close Review. Confirm nothing is installed or backed up. In particular, check that the core V/Z reminder, separate J/U selection and backup-not-created language remain visible and understandable.

## Scripts-only ZIP candidate (PR #31)

Development packaging now has a **separate builder**, `tools/Build-Naxxramas-ReviewBundle.ps1`. It is **not run by the setup wizard**. On Windows PowerShell 5.1 it copies an **explicitly allowlisted set of scripts, policy JSON and documentation** from the repository into an initially empty, independent output folder, records a SHA-256/size manifest and creates `Naxxramas-Review-Only-Scripts.zip`. The archive never includes any MPQ, executable, client tree, addons or private game files.

The packaging workflow `.github/workflows/scripts-only-review-bundle.yml` uses disposable fake source data to test the positive allowlist, file integrity and fail-closed rejection of nested/nonempty output and changed mandatory-core policy. Only after the test passes does CI upload a **short-lived internal workflow artifact**, **not a published Release**. No signature, provenance attestation or suitability for general public distribution is claimed.

If authorized for local developer inspection, use an **existing empty folder outside the repository and outside any game client**:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Build-Naxxramas-ReviewBundle.ps1" -OutputDirectory "C:\Temp\Empty-Review-Output"`

The output folder has to exist and be empty. The builder is a developer-only packaging operation; the included player-facing GUI remains **strictly read-only**. Any real client or display test should use a separately backed-up disposable copy.

**Release gate still open:** visually inspect the wizard and details view on Windows at 100%, 125%, 150% and 200% scaling, with keyboard-only input, Windows high contrast and a screen reader. Check file-action and backup-needed language, long warnings, button clipping and initial focus. Keep the downloadable scripts ZIP marked as a CI *candidate* until a separate release review approves it. Never include MPQs or game binaries.

## Visible J/U status and overlap warning (Milestone 4)

The wizard now shows plain-text **Patch-J ON/OFF** and **Patch-U ON/OFF** directly underneath the two independent checkboxes, before any scan. When both are checked it immediately displays:

> WARNING: J and U overlap on two loading screens. Combined appearance is untested.

This is a warning about an untested visual overlap, not proof that the files are incompatible. It is readable without relying on colour and uses an accessible description. V and Z are still required with no disable switch. Editing either J/U choice clears any previous review. The scrollable main window includes space for this notice, with no game-file writing functionality.

For actual Windows 100%, 125%, 150%, 200% display-scale, keyboard and screen-reader acceptance, follow [Windows Accessibility Acceptance](WINDOWS-ACCESSIBILITY-ACCEPTANCE.md). The checklist is also shipped inside the internal scripts-only ZIP candidate. No manual screen-reader or on-screen DPI test has been claimed.


## Compact File Details viewport (PR #33)

The read-only five-file details window now uses a **scrollable inner content region** with a minimum 730-pixel logical-height layout. On a smaller desktop, the *viewport* can shrink and the player scrolls vertically to reach all five file rows, long issues, original-backup notice and **Close Review**, rather than allowing the bottom-anchored footer and warnings to collide with the grid. The window's opening size is limited by the desktop work area where possible.

Windows PowerShell 5.1 CI constructs the actual details dialog without displaying it, shrinks its viewport to **640 × 480 logical WinForms units**, and checks scroll reachability, non-overlapping regions and controls remaining within the content width. This is a **geometry check, not real Windows DPI or assistive-technology validation**. It does not change the planner's read-only status, the exact five-file review, any patches or the no-backup/no-install/no-consent policy.

Human acceptance still needs real 100%, 125%, 150%, 200% display-scaling and screen-reader/high-contrast checks on a backed-up disposable test setup. Follow [Windows Accessibility Acceptance](WINDOWS-ACCESSIBILITY-ACCEPTANCE.md) and record any visible truncation or control focus issue before approving a scripts-only public release.


## Windows High Contrast palette and review status (PR #34)

The **read-only** wizard now chooses its palette using Windows' reported High Contrast setting **when the window is constructed**. With High Contrast enabled, the main window, header, text, primary review button and read-only output use native `SystemColors` for window/text/control/highlight rather than overriding them with fixed dark-blue and white colours. File Details uses the same approach for its background, text, warnings reader and five-row table. With High Contrast disabled, the existing visual palette is retained.

Keyboard focus starts at the **existing client folder field** rather than the review action. The review-status line now provides an accessible name and synchronised description when the user changes inputs, runs a preview or receives a blocker; Clear and Close also have explicit accessible names. This does not create an automatic announcement or prove any specific screen reader's behaviour.

Windows CI constructs the real forms **without displaying them**, asserts the active palette follows the current Windows flag and checks the explicit High Contrast palette maps to Windows system colours. CI does **not** enable the OS contrast mode, render visible pixels, announce screen-reader text, or exercise live theme switching. **Close and reopen the wizard after changing Windows High Contrast settings** before manual testing.

The [Windows Accessibility Acceptance](WINDOWS-ACCESSIBILITY-ACCEPTANCE.md) checklist is still **not manually completed** at 100%, 125%, 150% or 200% desktop scaling. The CI ZIP remains only an internal scripts-only candidate. No game file modifications, patch redistribution or actual backup actions have been introduced.

## Standalone extracted ZIP verification (PR #35)

The Windows scripts-only candidate now has a separate **extracted-package runtime smoke test**. CI checks that the ZIP unpacks with all required relative scripts and JSON, then invokes `tools/Start-Naxxramas-SetupWizard.ps1` directly *from the extracted ZIP* using `-Diagnostics`, `-PreviewJson` and `-DetailDiagnostics` while running from a different working folder.

All review calls use a newly generated, disposable **fake** WoW build-12340 client with a synthetic existing optional Patch-J and realmlist; **no real game archives or personal files** are used. Because no verified local core patch sources are present, the review must remain **blocked**, show exactly five read-only file actions, leave unrecognised J intact and explain the J/U overlap when both are selected. CI verifies the synthetic client and the unpacked scripts have exactly the same SHA-256 hashes before and after.

This test checks that the package is functional and safely refuses unavailable patches, **not** that game patch assets are legal to redistribute or that the interface looks correct at actual Windows 100–200% display scaling. The ZIP remains only a short-lived internal CI candidate. Human accessibility acceptance must be completed separately before any public pre-release.

## Packaged BAT launcher smoke test (PR #36)

The normal player instructions are unchanged: extract the scripts-only ZIP **outside the WoW folder** and double-click `tools/Start-Naxxramas-SetupWizard.bat`. It opens only the read-only review wizard. A developer-only `--diagnostics` argument is also understood by the BAT: it starts the same packaged Windows PowerShell script in STA, builds the interface headlessly and prints diagnostic JSON, **without displaying the wizard or operating on client files**. Invalid arguments exit immediately. No command is required for ordinary players.

Windows CI now tests the actual `cmd.exe` to `.bat` to `.ps1` path from an extracted ZIP located in a directory with **spaces**, not just direct invocation of the PS1. It verifies that a missing PS1 dependency produces a nonzero exit rather than hanging in a `pause`, and still checks the synthetic client and extracted scripts remain byte-identical. This does not certify desktop DPI, real screen-reader announcements or public release suitability; those remain manual gates.

## Safe human accessibility trial with fake data (PR #37)

For genuine *human* Windows scaling, High Contrast, keyboard and screen-reader inspection **without connecting a real client**, the source repository's existing disposable Windows wizard test now provides an interactive mode. From the source repository root on Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-SetupWizard.ps1" -ManualReview -ManualScenario Ready
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-SetupWizard.ps1" -ManualReview -ManualScenario Blocked
```

Run each scenario **separately**: the first shows a synthetic plausible five-file review and original-backup warning, the second intentionally introduces unknown fake core V and an omitted backup selection to exercise blocker messages. The real GUI stays read-only. Closing it triggers automatic byte-for-byte SHA-256 tree checks and cleanup of the newly generated *temporary* client/source/backup directory. The second command must not start until the first window is closed.

This fixture remains **developer/source-only**: it is *not* in the player scripts-only candidate ZIP. CI runs both with `-ManualHeadless` (no displayed UI) to prove fixture setup and read-only result consistency. Neither automation nor real on-screen/manual accessibility testing has been marked passed until evidence is actually collected. For the separate extracted-ZIP/BAT test, use the ordinary candidate launcher and follow [Windows Accessibility Acceptance](WINDOWS-ACCESSIBILITY-ACCEPTANCE.md).

## Optional Patch-C and N Addon Suite planning (PR #39)

The wizard now has an additional **optional TBC login screen (Patch-C)** checkbox alongside the existing optional J and U choices. Patch-C and Vanilla-login Patch-J are **mutually exclusive**: selecting either one deselects the other. Direct command-line input with both fails instead of silently accepting an impossible combination. Vanilla loading-screen Patch-U may be selected independently, and the existing J/U overlap warning remains.

**Patch-C is not yet a verified fifth MPQ.** Its proposed `Data/Patch-C.mpq` spelling and capitalization, SHA-256, length, provenance, contents and distribution permission must be independently confirmed. Therefore the original four-verified-patch + realmlist **five-file table remains unchanged**. Selecting C produces an explicit **BLOCKED planning note**, including in File Details, without an installer, file source or false hash match. When an owner-provided local copy is available, fingerprint it with a read-only utility and separately review an amended historical patchset; do not invent or accept a fake SHA.

A separate **N Addon Suite v2.0.0** planning checkbox identifies the officially released [N Addon Collection](https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0) and its five addon folders: `NCore` (mandatory within the suite), `IndividualProgressionAddon`, `DungeonJournal`, `MultiBot`, `NaxxLootLottery` (optional). N Talent Calculator is **not in this release**. The suite is optional as a whole. Choosing it also produces **BLOCKED** because its release ZIP fingerprint/rights and any installation, backup and rollback rules are not approved here. Neither the wizard nor scripts-only ZIP downloads the suite, modifies `Interface/AddOns`, removes duplicate addons, or changes `WTF` SavedVariables.

These two options are captured in an explicitly unapproved `config/optional-content.json` reference catalogue. They do not weaken the strict `config/client-patches.json` V/Z/J/U fingerprint checks or the no-approval/no-install/no-release rules. Automated tests cover the exclusion rule and fail-closed selected-status. Real physical Windows DPI, screen-reader checks and game compatibility are still outstanding.

## Patch-C release reference obtained (PR #40)

The owner supplied the published [Naxxramas Server Patches `optional-v1.0` release](https://github.com/CosmicCuddle/Naxxramas-Server-Patches/releases/tag/optional-v1.0). Its asset metadata gives filename `Patch-C.mpq`, size `26,753,640` bytes and SHA-256 `16b339522ca9394c11a5afe505e25cf9f326325eb2518dfde328ff08a99920c8`. The same release's J and U assets agree with the current registered J/U fingerprints. Its description confirms Patch-C and Patch-J are exclusive, while either can be combined with U.

The **release metadata is pinned** in `config/optional-content.json` and enforced by `tools/Naxxramas-OptionalContent.ps1`; the wizard no longer calls the release hash unknown. But the MPQ has **not** been downloaded and independently rehashed/inspected, its copyright and redistribution permissions are not approved, and C is still outside the immutable `patchset-0001` five-file planner. Selecting C remains **BLOCKED** until an independently reviewed successor patchset and full read-only review exist. No MPQ is shipped, fetched, installed or deleted.

## Patch-C six-file inspection — patchset-0002 (PR #41)

The read-only Windows wizard now displays a **six-row file review**:

1. Required core patch V.
2. Required core patch Z.
3. Optional Vanilla login screen J.
4. Optional TBC login screen C.
5. Optional Vanilla loading screens U.
6. Realm address settings (`realmlist.wtf`).

The pinned immutable current reference is now `patchset-0002` with five MPQs (V/Z/J/C/U); prior `patchset-0001` stays in the version archive. When C is selected, the planner hashes the existing `Data/Patch-C.mpq` and, if available, a matching file supplied in the **separate existing local patch-source directory**. No network or file-write call is used. A matching original remains untouched; an absent C without a valid source is **BLOCKED**; an unrecognised existing C is **BLOCKED** rather than overwritten; an absent C with an exact matching source is shown as a *future proposed addition*, not approved to execute.

**Important extra safety:** even when Patch-J is unchecked, an already-installed Patch-J file makes selecting C **BLOCKED**. The opposite is true when J is selected and C is already installed; both installed also block. The wizard will not remove/rename either MPQ automatically. For testing, use a **disposable backed-up test client**, and don't alter your actual game's files based on a preview.

N Addon Suite still has its own separate noninstallable planning option. All six file rows are read-only and no backups have been created; the scripts-only CI ZIP remains an internal candidate with neither real MPQs nor addons. Real Windows scaling 100/125/150/200%, screen reader and game compatibility QA and any public-release decision remain separate gates.

## Read-only addon folder inventory and NCore preferences (PR #42)

The N Addon Suite v2.0.0 section now has four individually selectable **future NCore module preferences** beneath the main optional suite checkbox: Individual Progression Companion, Dungeon Journal, MultiBot Chatless and N Loot Ledger (WIP). **NCore is always required with the suite** and already includes N Classic Battlegrounds; the release archive still contains all five addon folders. These preferences do **not** extract a subset, activate live addons, edit `WTF`, install, download, approve or make client changes. When the suite is deselected, module controls are disabled. The user can review the available selections with **Review Only** and inspect their effects in the read-only result and File Details.

On review, a **shallow names-only** inspection reports whether NCore, the four suite addon folders, and legacy `NClassicBattlegrounds` / `ServerDungeonJournal` folders exist beneath `Interface/AddOns`. A present folder is marked **present_unverified**, not verified for version, source, contents or suitability. An unsafe linked root causes fail-closed review. Unexpected files or linked addon entries produce clear blockers rather than being followed or overwritten. Legacy standalone Battlegrounds and ServerDungeonJournal are reported as potential duplicate functionality; the wizard **never deletes them**. No recursive addon or SavedVariables inspection occurs.

From Windows PowerShell 5.1, a developer can optionally preview a subset (without GUI) using the already-documented `-PreviewJson` fake test-client parameters plus `-AddonSuite -AddonModules 'DungeonJournal,MultiBot'`. `-AddonModules None` means no optional NCore modules planned; NCore remains mandatory if the suite is chosen. Other names, repeated names, or module arguments without `-AddonSuite` are rejected. This command is **not** an installation command. A selected suite continues to show **BLOCKED**, because approved ZIP verification, licensing, backup/SavedVariables preservation and rollback have not been completed.

Official [v2.0.0 release](https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0) metadata publishes `N-Addon-Collection-v2.0.0.zip`, **26,762,217 bytes**, SHA-256 `07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324`. This is a *published release-asset reference*, **not independent ZIP contents verification**, licence approval or permission to redistribute. The scripts-only CI candidate has no addon ZIP, WoW executable, MPQ or personal addon files.

Physical 100/125/150/200% Windows accessibility checks and actual addon compatibility tests still require human evidence before any separate public-release/installer decision.

## Developer-only offline N Addon Suite ZIP audit (PR #43)

A separate **source-only** tool, `tools/Test-Naxxramas-AddonArchive.ps1`, can **read** a locally obtained original N Addon Suite v2.0.0 ZIP to verify its exact **published size and SHA-256** and inspect its five top-level addon folder names/TOC presence **without extracting anything**. Get the archive separately from the owner's [v2.0.0 release](https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0), keep it outside the WoW client folder and run the example in [Addon Archive and Recovery Plan](ADDON-ARCHIVE-AND-RECOVERY-PLAN.md). The audit produces JSON containing only names/counts and explicit denial of installation, backup, redistribution and gameplay approval. It does not verify payload CRC, Lua content/licence, game compatibility or rollback.

Windows CI exercises this developer-only reader with deliberately valid/unsafe **fake ZIPs**, not a fetched release ZIP. The new auditor is intentionally absent from the **player-facing scripts-only ZIP**; the existing wizard's N Addon Suite choice remains **BLOCKED**, and there is no network fetching, extraction, installation, game modification or SaveVariables operation. Human DPI/contrast/screen-reader QA and full future-backup architecture remain open.

## Source-tag ZIP metadata improvements (PR #44)

Source-only developer auditing now checks that an independently provided local v2.0.0 ZIP declares twelve canonical packaging markers from the owner release's **v2.0.0 source tag**, including the NCore generated-version manifest, embedded Classic Battlegrounds, all five exact root TOCs and expected licence/credit entries. It also detects unsafe executable extensions and ZIP file/directory path collisions. This audit still does not extract archives, scan Lua/TOC contents, verify CRCs, or authorise installation or distribution. See [v2 source-tag evidence and SavedVariables](ADDON-V2-SOURCE-TAG-REVIEW.md).

The actual release ZIP was **not downloaded or independently inspected** in this engineering run. All Windows automated audit tests use synthetic ZIPs; do not replace actual Windows and game compatibility acceptance with test results.

## Read-only addon upgrade assessment (PR #47)

When **N Addon Suite** is selected, **Review Only** now shows a conservative planned-upgrade explanation for each of the five bundled addon folders and both possible legacy standalone folders. A folder's mere presence does **not** establish its version; the wizard always identifies it as **unknown, not inspected**. Existing folders must be preserved and manually reviewed before any later approved upgrade. An absent folder is only an **unapproved future addition**, not permission to install. If `NClassicBattlegrounds` or `ServerDungeonJournal` exists, the user sees an explicit potential legacy duplicate conflict; neither is removed. No suite selected means existing addons are retained, not upgraded. NCore plus all four optional folder names exist in the v2 ZIP regardless of individual *future module activation preferences*; there is no selective ZIP extraction.

The same review names known v2.0.0 settings that a future recovery system would need to preserve: account-wide `IndividualProgressionDB`, `DungeonJournalDB`, `MultiBotGlobalSave`, `NaxxLootLotteryDB` and character-specific `MultiBotSave`, `MultiBotDB`, `MultiBotSaved`. **This is only a public TOC-based reference**. The wizard does NOT open or enumerate the user's `WTF` folders or SavedVariables, collect personal information, create a backup, restore, install, download, delete or overwrite anything. A future approved backup would need to protect *all* existing account/realm/character settings and originals, not just the known variable names.

The preview JSON exposes `addon_upgrade_assessment` and `addon_settings_protection` (no private paths, content, account names or character names). On physical Windows, check scrollability, the File Details Close button, keyboard reading, High Contrast and desktop scales 100/125/150/200%, using **disposable synthetic files only**. CI does not substitute for screen-reader acceptance or in-game compatibility.


## Keyboard-first reading of review results (accessibility follow-up)

The read-only wizard provides a **Read Review Text** button below the main action row. After **Review Only** (or after changing any selection), use **Tab** to reach this button and press **Space** or **Enter**. Keyboard focus moves to the beginning of the existing read-only result area. You can now use the arrow keys or your screen reader to read the summary and warnings without searching the entire form. This control never runs a planner, installs files, creates backups, records consent or changes settings. **View File Details** still provides the six-file read-only table and additional scrollable notes.

The result control's accessible description now carries the current read-only review status, including when a selection invalidates the previous result. This is an improvement in available text and keyboard navigation, **not proof that any screen reader announced a change**. Human Windows tests must verify focus, spoken text, actual 100/125/150/200% desktop scaling and High Contrast. Use the short [manual test record](WINDOWS-ACCESSIBILITY-TEST-RECORD.md), whose entries remain NOT TESTED until physically checked. The standard double-click launcher and all safety/permission limits remain unchanged.

