# Windows Accessibility Acceptance — Read-only Guided Setup

**Status: NOT YET MANUALLY VERIFIED.** This is an acceptance checklist, not evidence that any physical display, assistive technology, or actual game client has been tested.

## Scope and safe test setup

Use a disposable, separately backed-up **WoW 3.3.5a build 12340 enUS test client**, not the owner's sole working installation. The wizard does not need an actual game client to open and browse its controls. To exercise real planner results without owning private patch files, use the existing Windows CI disposable fake-client tests; do not redistribute fixture-generated artifacts as game files.

Double-click `tools/Start-Naxxramas-SetupWizard.bat` from a clean copy of the scripts-only candidate, or launch with Windows PowerShell 5.1 STA. The wizard must remain **Review Only**, with no installation, approval, copy, restore, deletion, uninstaller or download button. It must never produce or verify a real backup.

## Human display and keyboard acceptance matrix

Record each configuration separately. **Unrecorded is NOT passed.** Windows scaling must actually be changed on the desktop; setting a test variable does not simulate DPI or establish visual compatibility.

| Windows display setting | Wizard window and Browse fields | Optional J/U + overlap warning | Five-file details, long warnings and backup label | Keyboard and assistive technology |
| --- | --- | --- | --- | --- |
| 100% | Not tested | Not tested | Not tested | Not tested |
| 125% | Not tested | Not tested | Not tested | Not tested |
| 150% | Not tested | Not tested | Not tested | Not tested |
| 200% | Not tested | Not tested | Not tested | Not tested |

### Steps

1. **Open** the wizard. Make sure its heading, three folder selectors, independent J and U choices, always-required V/Z reminder and read-only wording are legible. Scroll down if needed; no action should disappear behind a border.
2. **Select J only, U only, neither and both.** Check the status displays each choice as ON/OFF. With **both** selected, a written WARNING must explain overlapping loading screens and untested combined appearance **before Review Only is pressed**. The warning must not rely on colour.
3. **Tab forward, then Shift+Tab back** through the three folder textboxes and Browse buttons, J/U checkboxes, realm address, Review Only, Clear Review, View File Details (after a valid review), Close and review output. Labels must be understandable when read out of context. The default Enter key must not install anything; Escape must close.
4. **Review a disposable fake client** using local-only synthetic fixtures or a separate backed-up test client. Verify exactly five ordered rows in File Details and that the original-backup-required label reads **YES - not created**. Confirm that no review action is presented as approval.
5. **Try long warnings.** The warning area must scroll and remain keyboard-readable after making the window shorter/taller; the Close Review button must remain reachable.
6. **Use a screen reader and Windows high contrast** if available. Confirm the J/U status, overlap warning, proposed file actions, original backup warning, Close and blocked errors are communicated by text, not only by colour or mouse hover.
7. **Change a selection after reviewing.** Confirm the old review clears and View File Details becomes unavailable until a fresh Review Only operation.
8. **Verify safety.** Compare the disposable test client's files before/after the review; nothing must be installed, overwritten, deleted or backed up by this wizard.

### Record evidence without leaking private information

For every setting, record: Windows edition, resolution, actual scaling percentage, optional font/text-size adjustment, screen reader (if any), success/failure with reproduction steps, affected control, and whether any file changed. Capture screenshots **only if safe**, hiding local usernames, paths, realm credentials, addon names and any private MPQ file content. Do **not** put private client archives or screenshots showing personal paths in the repository.

## Automated coverage versus manual evidence

`tests/Test-SetupWizard.ps1` runs actual Windows Forms **headlessly** in Windows PowerShell 5.1 and uses a disposable fake game client. It checks the fixed five-file review, independent J/U choices, immediate textual overlap indicator, keyboard defaults, scrolling metadata, blocked states and non-mutating behaviour.

It does **not** establish rendered pixel-level text clipping, DPI scaling at 100/125/150/200%, real screen-reader announcements, high-contrast usability or suitability for release. The internal scripts-only ZIP remains a **candidate**, not a published release, until manual acceptance is documented and separately reviewed.


## Compact-window exploratory check

In addition to the scaling matrix above, make the **File Details** window approximately 640 × 480 while the display scale is set in Windows. Verify the five-file grid remains above the warnings; scroll down to find the exact **original backup not created** notice and **Close Review** without the controls obscuring each other. Tab through the grid, warning reader and Close Review, then return to the wizard. Do not mark the scaling matrix as passed based on CI's compact logical-viewport check.


## High Contrast and initial focus test (PR #34)

Before opening the wizard, enable **Windows High Contrast / contrast theme** and then start the wizard afresh. Check foreground/background contrast for the main heading, client/source/backup fields, J/U status, Review Only, status message, scrollable review result and File Details table/warnings. Toggle back to ordinary Windows colours and **restart the wizard**; verify ordinary styling remains readable. Test initial Tab focus at the existing client-folder field and keyboard traversal to Clear Review and Close. Use a real screen reader to check whether status changes are **actually announced**; setting `AccessibleDescription` alone is not proof of a spoken notification. Record actual results per desktop configuration. The automated system-colour assertions do not replace this check.

## Starting the real launcher

For each manual 100/125/150/200% scaling test, launch **by double-clicking the actual `tools/Start-Naxxramas-SetupWizard.bat` in the extracted scripts-only candidate**, not by invoking `-Diagnostics` (which never displays a window). Run this from an ordinary folder with spaces in its name to exercise the packaged path handling. Validate the real UI, Windows security prompts (if any), and safe Close behaviour. The CI headless BAT test confirms argument wiring only and must **not** be recorded as a passed human accessibility test.

## Disposable local visual acceptance fixtures (PR #37)

If you have a **Windows computer** and a local clone/download of the **source repository** (not merely the scripts-only candidate ZIP), you can visually test the real read-only WinForms wizard without pointing it at an existing WoW installation. Open **Windows PowerShell 5.1** in the source repository root, at each actual Windows display-scaling setting.

**Scenario 1 — expected review (five actions, two originals needing future backup):**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-SetupWizard.ps1" -ManualReview -ManualScenario Ready
```

**Scenario 2 — intentionally blocked review (unknown fake core V and omitted backup selection):**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-SetupWizard.ps1" -ManualReview -ManualScenario Blocked
```

Each command generates its *own* uniquely named temporary directory, a synthetic C# build-12340 `Wow.exe` (not an actual game client), four tiny fake patch sources, fake V/Z/J files, a fake `realmlist.wtf`, and an existing fake backup sentinel. It then opens the genuine **Review Only** WinForms window with those synthetic paths already filled in. In either case, press **Review Only**, open **View File Details**, read/scroll warnings, try both J/U selections, Tab and Shift+Tab through the controls, and check screen-reader announcements and contrast manually. **Close the wizard** to let the test compare SHA-256 hashes of synthetic client/source/backup files and automatically delete its temporary directory.

The `Ready` fixture's no-blocker status **does not grant installation permission**. The `Blocked` fixture must still preserve all fake data and deny modifications. Do not point either wizard at your real WoW directory. Do **not** share screenshots containing local usernames or private paths.

There is a separate, headless CI option `-ManualHeadless` that tests the generated fixtures and their real five-file reports but **never shows a GUI**. CI passing that mode is **not** completion of the 100%, 125%, 150% or 200% physical desktop matrix above.

**Important distinction:** these commands exercise the repository's copied read-only wizard against a **test-only policy** whose SHA-256 values match tiny fake patches. They do **not** test the untouched extracted ZIP's real patch policy. For final packaged-BAT acceptance, also use the separately documented **Starting the real launcher** instructions, and record results independently. No public prerelease is authorised until actual human checks are recorded.
