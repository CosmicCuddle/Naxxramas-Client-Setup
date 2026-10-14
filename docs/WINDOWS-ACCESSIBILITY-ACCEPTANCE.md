# Windows Accessibility Acceptance — Read-only Guided Setup

**Status: NOT YET MANUALLY VERIFIED.** This is an acceptance checklist, not evidence that any physical display, assistive technology, or actual game client has been tested.

## Scope and safe test setup

Use a disposable, separately backed-up **WoW 3.3.5a build 12340 enUS test client**, not the owner's sole working installation. The wizard does not need an actual game client to open and browse its controls. To exercise real planner results without owning private patch files, use the existing Windows CI disposable fake-client tests; do not redistribute fixture-generated artifacts as game files.

Double-click `tools/Start-Naxxramas-SetupWizard.bat` from a clean copy of the scripts-only candidate, or launch with Windows PowerShell 5.1 STA. The wizard must remain **Review Only**, with no installation, approval, copy, restore, deletion, uninstaller or download button. It must never produce or verify a real backup.

## Human display and keyboard acceptance matrix

Record each configuration separately. **Unrecorded is NOT passed.** Windows scaling must actually be changed on the desktop; setting a test variable does not simulate DPI or establish visual compatibility.

| Windows display setting | Wizard window and Browse fields | Optional C/J/U + overlap warning | Six-file details, long warnings and backup label | Keyboard and assistive technology |
| --- | --- | --- | --- | --- |
| 100% | Not tested | Not tested | Not tested | Not tested |
| 125% | Not tested | Not tested | Not tested | Not tested |
| 150% | Not tested | Not tested | Not tested | Not tested |
| 200% | Not tested | Not tested | Not tested | Not tested |
| 300% (owner-reported) | Partial visual observation | Partial visual; mutual-exclusion interactions untested | Partial visual observation | Partial owner-reported keyboard: Tab/Shift+Tab, Enter, Escape working; review text controls no issue reported. Narrator/contrast untested |

**300% partial observation (14 October 2026):** the owner reports using 300% display scaling on a large monitor and supplied pictures of the Ready and Blocked fake-client wizard, File Details and final console check. Text, six rows, warnings and controls appear readable without obvious overlap in the captured regions. Monitor resolution and OS DPI were not independently checked; other physical scales, **full keyboard traversal**, Narrator and contrast theme remain **NOT TESTED**. Follow-up on 14 October: owner reported Tab/Shift+Tab visible focus, Enter activating Review Only, no issues with review-text controls, and Escape closing the main window; this is **partial keyboard evidence**, not full acceptance. No screenshot or personal path is committed. Details: [partial observation record](WINDOWS-ACCESSIBILITY-TEST-RECORD.md).

### Steps

1. **Open** the wizard. Make sure its heading, three folder selectors, independent J and U choices, always-required V/Z reminder and read-only wording are legible. Scroll down if needed; no action should disappear behind a border.
2. **Select J only, U only, neither and both.** Check the status displays each choice as ON/OFF. With **both** selected, a written WARNING must explain overlapping loading screens and untested combined appearance **before Review Only is pressed**. The warning must not rely on colour.
3. **Tab forward, then Shift+Tab back** through the three folder textboxes and Browse buttons, J/U checkboxes, realm address, Review Only, Clear Review, View File Details (after a valid review), Close and review output. Labels must be understandable when read out of context. The default Enter key must not install anything; Escape must close.
4. **Review a disposable fake client** using local-only synthetic fixtures or a separate backed-up test client. Verify exactly six ordered rows (V, Z, J, C, U and realm settings) in File Details and that the original-backup-required label reads **YES - not created**. Confirm that no review action is presented as approval.
5. **Try long warnings.** The warning area must scroll and remain keyboard-readable after making the window shorter/taller; the Close Review button must remain reachable.
6. **Use a screen reader and Windows high contrast** if available. Confirm the J/U status, overlap warning, proposed file actions, original backup warning, Close and blocked errors are communicated by text, not only by colour or mouse hover.
7. **Change a selection after reviewing.** Confirm the old review clears and View File Details becomes unavailable until a fresh Review Only operation.
8. **Verify safety.** Compare the disposable test client's files before/after the review; nothing must be installed, overwritten, deleted or backed up by this wizard.

### Record evidence without leaking private information

For every setting, record: Windows edition, resolution, actual scaling percentage, optional font/text-size adjustment, screen reader (if any), success/failure with reproduction steps, affected control, and whether any file changed. Capture screenshots **only if safe**, hiding local usernames, paths, realm credentials, addon names and any private MPQ file content. Do **not** put private client archives or screenshots showing personal paths in the repository.

## Automated coverage versus manual evidence

`tests/Test-SetupWizard.ps1` runs actual Windows Forms **headlessly** in Windows PowerShell 5.1 and uses a disposable fake game client. It checks the fixed five-file review, independent J/U choices, immediate textual overlap indicator, keyboard defaults, scrolling metadata, blocked states and non-mutating behaviour.

It does **not** establish rendered pixel-level text clipping, DPI scaling at 100/125/150/200/300%, real screen-reader announcements, high-contrast usability or suitability for release. The internal scripts-only ZIP remains a **candidate**, not a published release, until manual acceptance is documented and separately reviewed.


## Compact-window exploratory check

In addition to the scaling matrix above, make the **File Details** window approximately 640 × 480 while the display scale is set in Windows. Verify the six-file grid remains above the warnings; scroll down to find the exact **original backup not created** notice and **Close Review** without the controls obscuring each other. Tab through the grid, warning reader and Close Review, then return to the wizard. Do not mark the scaling matrix as passed based on CI's compact logical-viewport check.


## High Contrast and initial focus test (PR #34)

Before opening the wizard, enable **Windows High Contrast / contrast theme** and then start the wizard afresh. Check foreground/background contrast for the main heading, client/source/backup fields, J/U status, Review Only, status message, scrollable review result and File Details table/warnings. Toggle back to ordinary Windows colours and **restart the wizard**; verify ordinary styling remains readable. Test initial Tab focus at the existing client-folder field and keyboard traversal to Clear Review and Close. Use a real screen reader to check whether status changes are **actually announced**; setting `AccessibleDescription` alone is not proof of a spoken notification. Record actual results per desktop configuration. The automated system-colour assertions do not replace this check.

## Starting the real launcher

For each manual 100/125/150/200/300% scaling test, launch **by double-clicking the actual `tools/Start-Naxxramas-SetupWizard.bat` in the extracted scripts-only candidate**, not by invoking `-Diagnostics` (which never displays a window). Run this from an ordinary folder with spaces in its name to exercise the packaged path handling. Validate the real UI, Windows security prompts (if any), and safe Close behaviour. The CI headless BAT test confirms argument wiring only and must **not** be recorded as a passed human accessibility test.

## Double-click local human QA (source checkout only)

On a physical Windows desktop, extract the **full source repository** outside the game folder, then double-click `tests/Start-Accessibility-ManualCheck.bat`. It opens the same established, disposable **Ready** and **Blocked** fake-client fixtures as the PowerShell instructions below, in that order. Close each wizard normally and leave the console open to see the final fake-file integrity result. **No WoW client, original settings or MPQs are needed.** The BAT refuses arguments, client paths and unattended CI; it does not belong to the strict player scripts-only archive.

Repeat at actual Windows scaling 100%, 125%, 150%, 200% and 300%, using keyboard and (when available) Narrator and High Contrast. Record the observations manually in [Windows Accessibility Test Record](WINDOWS-ACCESSIBILITY-TEST-RECORD.md). A successful disposable integrity test is **not** a gameplay, screen-reader, DPI or release PASS.

## Disposable local visual acceptance fixtures (PR #37)

If you have a **Windows computer** and a local clone/download of the **source repository** (not merely the scripts-only candidate ZIP), you can visually test the real read-only WinForms wizard without pointing it at an existing WoW installation. Open **Windows PowerShell 5.1** in the source repository root, at each actual Windows display-scaling setting.

**Scenario 1 — expected review (six file rows, two originals needing future backup):**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-SetupWizard.ps1" -ManualReview -ManualScenario Ready
```

**Scenario 2 — intentionally blocked review (unknown fake core V and omitted backup selection):**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-SetupWizard.ps1" -ManualReview -ManualScenario Blocked
```

Each command generates its *own* uniquely named temporary directory, a synthetic C# build-12340 `Wow.exe` (not an actual game client), five tiny fake patch sources, fake V/Z/J files, a fake `realmlist.wtf`, and an existing fake backup sentinel. It then opens the genuine **Review Only** WinForms window with those synthetic paths already filled in. In either case, press **Review Only**, open **View File Details**, read/scroll warnings, try both J/U selections, Tab and Shift+Tab through the controls, and check screen-reader announcements and contrast manually. **Close the wizard** to let the test compare SHA-256 hashes of synthetic client/source/backup files and automatically delete its temporary directory.

The `Ready` fixture's no-blocker status **does not grant installation permission**. The `Blocked` fixture must still preserve all fake data and deny modifications. Do not point either wizard at your real WoW directory. Do **not** share screenshots containing local usernames or private paths.

There is a separate, headless CI option `-ManualHeadless` that tests the generated fixtures and their real five-file reports but **never shows a GUI**. CI passing that mode is **not** completion of the 100%, 125%, 150% or 200% physical desktop matrix above.

**Important distinction:** these commands exercise the repository's copied read-only wizard against a **test-only policy** whose SHA-256 values match tiny fake patches. They do **not** test the untouched extracted ZIP's real patch policy. For final packaged-BAT acceptance, also use the separately documented **Starting the real launcher** instructions, and record results independently. No public prerelease is authorised until actual human checks are recorded.

## Manual defect observation — Close Review click (PR #38)

During a real user-run **Ready** disposable fixture, the five-file grid, backup notices, independent scrolling and Close Review placement were observed on a Windows display. Clicking **Close Review** exposed a genuine event callback scope bug: PowerShell StrictMode could not retrieve `$win`. The test console subsequently reported **PASS: Manual Ready fixture did not change any synthetic files** and cleanup reached its end. This is **not** an overall accessibility-matrix pass because the actual scaling percentage, keyboard-only navigation and screen-reader behaviour were not established.

PR #38 changes the handler to resolve the owning form from the clicked button, and adds a *headless real-Click-event regression* for both Ready and Blocked fixtures. **A successful CI result is not a substitute for the user repeating the click on the refreshed project.** After updating the extracted GitHub source, rerun Ready, choose **Review Only → View File Details → Close Review**; ensure there is **no unhandled exception**, then close the main wizard and confirm the unchanged-synthetic-files PASS. Keep the public scripts-only release gate open.

## Optional-content interaction check (PR #39)

At each actual desktop scaling size (100/125/150/200/300%) test **Patch-C ↔ Patch-J exclusion** with keyboard and mouse: selecting C must automatically turn off J; selecting J must turn off C. Patch-U remains independent. Try J+U together and confirm the existing overlap warning. Choose C alone and then N Addon Suite v2.0.0 alone; each selected option must show a **BLOCKED, NOT VERIFIED** review while preserving exactly the original five verified file actions. Check the NCore/four-addon names and standalone N Talent Calculator exclusion are readable and screen-reader accessible, and that changing any choice clears the old review. Do not claim C is approved, or that addons are installed. No actual on-screen acceptance results for these new options have yet been recorded.

## Six-file Patch-C manual test (PR #41)

On a **fresh extracted copy** of the reviewed source, using the disposable Ready/Blocked fixture, confirm File Details shows six distinct rows **V, Z, J, C, U and realm settings**. Toggle TBC-C, Vanilla-J, and Vanilla-U with keyboard and mouse; J/C are mutually exclusive, U independent. Verify the actual Close Review button still closes normally and no files change. When the Ready fixture includes an unselected existing J, selecting C must result in a clearly readable **incompatible existing-login MPQ** blocker, even though the J box is off. Review warning scroll, real desktop 100/125/150/200/300% DPI, Windows High Contrast and screen reader with proper dated human evidence. CI headless tests do not verify real screen reader announcements or physical DPI. No public prerelease/installation permission is granted.

## N Addon Suite module and folder review (PR #42)

On a **new extracted source-only disposable fixture**, check at each real desktop scale 100/125/150/200/300% and in Windows High Contrast: the NCore required notice, four future-activation module preferences, and N Loot Ledger (WIP) are readable by keyboard/screen reader. Ensure the four controls are disabled while the suite is off and editable only when selected; switching them clears stale review results. Use **Review Only** and verify the names-only `Interface/AddOns` inventory and duplicate-folder warnings are accessible in the scrolling result and File Details without suggesting installs or backups occurred. Verify **Close Review** works without the previously observed scope exception. Test intentionally existing legacy folders only in a disposable fake-client fixture; do not modify a real client's addons. CI headless results cannot substitute for on-screen accessibility results, the archive contents/rights review, or real in-game addon compatibility.

## Read-only addon upgrade language (PR #47)

With the updated source-only fake-client review open, check that the seven addon upgrade classifications and settings-preservation warnings remain understandable and scrollable at 100/125/150/200/300% physical Windows scaling. Verify keyboard-only focus, warning and File Details screen-reader announcements, High Contrast, and working Close Review. When an existing synthetic addon directory appears, it should say **unknown version: preserve/manual review**, not claim it is current, verified or installed by this program. Existing legacy NClassicBattlegrounds/ServerDungeonJournal warnings must never imply automatic deletion. The known SavedVariables list is informational; no actual WTF files were inspected or backups created. Record physical test evidence before any public candidate.

## Keyboard route to read-only results (new development, PR pending)

The wizard now includes a **Read Review Text** button below the Review Only / Clear Review / View File Details / Close row. It is available even before a review, and does **only one thing**: moves keyboard focus into the existing read-only, scrollable review text (at its beginning). It does not invoke the planner, grant consent, alter the selected files, copy a backup or allow installation.

After any selection change, the result text is reset and its accessible description includes the updated status. After a completed or blocked **Review Only**, the status and result reader descriptions also stay synchronized. The separate **View File Details** dialog retains its read-only six-file table and keyboard-reachable warnings; no new file-change commands are provided.

**Physical verification still required** at 100/125/150/200/300% scaling: Tab to **Read Review Text**, press Space or Enter, and check that focus enters the read-only result where Up/Down and screen-reader reading commands work. Then Shift+Tab to the button and continue to **View File Details**. Repeat with J+U overlap warning, C/J exclusion, addon suite BLOCKED, missing backup, and intentional blocked file review. Confirm the status is understandable with a real screen reader rather than only reading the accessibility metadata in CI. Review the concise [blank Windows QA record](WINDOWS-ACCESSIBILITY-TEST-RECORD.md). **Do not mark any human screen-reader or physical display checks passed from CI alone.**

## Simplified hands-on launch — one command

From the **source repository** on Windows PowerShell 5.1, use this one command at each *actual* Windows display scale:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\tests\Start-Accessibility-ManualCheck.ps1" -Interactive -Scenario Both
```

The helper opens a fresh disposable **Ready** fixture first, checks fake-client/source/backup hashes and cleans it up when closed, then opens a separately generated **Blocked** fixture. There is no real client-path parameter, download, backup writer or installation action. The command **does not** set DPI or record a physical pass; the user must change Windows display scaling in Settings and personally check legibility, keyboard focus, actual narrator announcements and High Contrast.

For developers/CI, `-Headless -Scenario Both` exercises the same disposable branches **without showing a window**. It must never be confused with physical acceptance. The helper rejects interactive runs in unattended CI. The official [blank acceptance record](WINDOWS-ACCESSIBILITY-TEST-RECORD.md) remains **NOT TESTED** until someone documents actual display and assistive-technology observations. For final acceptance, also test the original scripts-only candidate launcher separately; this synthetic helper is *not* a substitute for packaging tests.
