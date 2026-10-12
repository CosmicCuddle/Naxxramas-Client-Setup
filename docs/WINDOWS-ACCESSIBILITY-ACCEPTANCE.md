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
