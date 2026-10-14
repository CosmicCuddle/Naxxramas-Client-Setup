# Windows Read-only Wizard — Manual Accessibility Test Record

**Acceptance status: INCOMPLETE — partial owner-reported visual observation at 300% only.** All other physical DPI/input/assistive-technology configurations remain NOT TESTED. Running CI or seeing successful diagnostics does **not** complete any physical acceptance entry.

**Source:** [Windows Accessibility Acceptance](WINDOWS-ACCESSIBILITY-ACCEPTANCE.md). Test a disposable synthetic client only; never your only working WoW client.

## Before testing

- Open the source repository on a physical Windows desktop using Windows PowerShell 5.1; do not run the headless `-Diagnostics` variant as a substitute for seeing the window.
- **Simplest Windows option:** double-click `tests/Start-Accessibility-ManualCheck.bat` from a full source repository download. The launcher runs the existing **Ready**, then **Blocked** fake-client review; close each wizard when finished. The console remains open for the unchanged fake-file result. It accepts **no arguments or real client paths** and refuses unattended CI.
- **PowerShell alternative:** run the same existing test from the source repository root with Windows PowerShell 5.1:

  ```powershell
  powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\tests\Start-Accessibility-ManualCheck.ps1" -Interactive -Scenario Both
  ```

  This opens the disposable **Ready** wizard first. Close it normally after checking the UI; the fixture verifies its unchanged bytes and cleans up before opening **Blocked**. Both launch methods are source/developer-only, not in the player ZIP. For a single scenario use `-Scenario Ready` or `-Scenario Blocked`.
- The generated fixture is removed after the window is closed. No genuine MPQs or SavedVariables are required. **Keep the console open until its final unchanged-file confirmation.**
- Check a real extracted scripts-only **candidate** launcher separately using `tools/Start-Naxxramas-SetupWizard.bat`, to test startup rather than synthetic file contents. Do not treat that as an installation.
- Never include personal paths, character names, player folders, screenshots containing private content, or complete game archives in a public issue.

## Test device

| Field | Your observation |
| --- | --- |
| Test date | **Not recorded** |
| Windows version/build | **Not recorded** |
| Display resolution | **Not recorded** |
| Actual screen reader/version | **Not recorded** |
| Text scaling/accessibility settings | **Not recorded** |
| Real client modified? (must be **No**) | **Not verified** |

## Physical DPI and input matrix

For each scale, set actual **Windows display scaling**, close and reopen the wizard, and run both **Ready** and **Blocked** synthetic modes. Each cell starts **NOT TESTED**; change only after personally observing the physical display and controls.

| Actual scaling | Folder/Browse legibility | C/J mutex, U independent, J+U warning | Addon suite BLOCKED, scrollable details | Tab/Shift+Tab, Read Review Text, Escape | Screen reader and contrast |
| --- | --- | --- | --- | --- | --- |
| 100% | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| 125% | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| 150% | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| 200% | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| 300% (owner reported) | PARTIAL VISUAL: folder inputs and Browse buttons visible in supplied images | PARTIAL VISUAL: choices and written C/J restriction visible; keyboard mutex interaction NOT TESTED | PARTIAL VISUAL: addon controls, six-file details, warning text and Close Review observed in screenshots | NOT TESTED | NOT TESTED |

## Owner-reported 300% visual review — 14 October 2026 (partial; not acceptance)

- Source: owner-provided on-screen screenshots and console text from the **existing disposable FAKE-file** `Start-Accessibility-ManualCheck.bat` Ready and Blocked sessions; **no screenshots, names, temporary paths or account data are committed**.
- Owner reports **300% Windows display scaling** on a large monitor. **Monitor resolution, Windows build and OS-confirmed DPI were not supplied.** Record this as *reported*, not independently measured.
- Visible in screenshots: folder selectors, optional J/C/U choices and textual mutual-exclusion warning, N Addon Suite area, main-page scrolling, six file-details rows, backup-needed text, scrollable warning area, Close Review button, and the blocked preview's unrecognised V / missing backup-folder messages. No obvious clipping or overlap in the captured regions; this does **not** rule out issues elsewhere or establish automatic PASS.
- Console ended with `SYNTHETIC FIXTURES COMPLETE` and confirmed the Blocked fixture's synthetic files unchanged. This is evidence about **fake fixture integrity only**, not real-game integrity or the actual scaling setting; automatic cleanup was announced by the helper, not independently inspected here.
- **NOT TESTED:** complete Tab/Shift+Tab navigation, Enter/Escape by hand, screen-reader announcements, contrast theme, all C/J toggle combinations, separately tested 100/125/150/200% scales, any actual WoW build/gameplay or independently protected original/WTF backups. These remain open; this visual session alone cannot authorise an installer or public release.
- If further testing shows cropping, clipped warnings or inaccessible focus, record FAIL and reproduction steps. Do not upgrade this row to PASS from the screenshots alone.

## Three-minute keyboard check at each scaling level

1. **Open the wizard.** Tab from the existing client field through Browse and optional patch choices. Use Space to toggle J, U, C and addon preferences. C/J must remain mutually exclusive; U is independent.
2. **Review Only.** Press the button with Enter. Confirm there is **no** Install, Approve, Apply, Copy, Recover, Delete or Back Up action.
3. **Read Review Text.** Tab to that button and press Enter or Space. The caret/keyboard focus must enter the existing read-only result. Read the text with keyboard and screen reader; confirm the words `no changes made` or `still preview only` are understandable.
4. **View File Details.** Open the six-row read-only table, navigate the warnings with Tab, scroll to original-backup-required notes, and use **Close Review** with keyboard. No clipped or overlapping controls at the current real scaling.
5. **Blocked fixture.** Confirm explicit manual-review wording; selection changes clear the old result; your screen reader can reach changed status and scrollable warnings.
6. **High Contrast.** Enable the actual Windows contrast theme and restart the wizard. Check text is not hidden or distinguished solely by colour.
7. **Close and verify.** Exit normally. Verify the disposable fixture test reports unchanged test files and cleanup; **do not** infer that a real game installation was tested.

## Failure record

| Scale + input | Observed symptom | Exact control / reproduction | Retested? |
| --- | --- | --- | --- |
| NOT RECORDED | NOT RECORDED | NOT RECORDED | NOT RECORDED |

If anything is clipped, impossible to focus, unreadable with assistive technology, or claims approval when none exists: mark **FAIL**, preserve privacy-safe reproduction notes and hold the public release. A CI pass cannot override a physical failure.

**Release gate:** physical DPI, High Contrast, screen-reader and keyboard acceptance remain **OPEN** until the owner records results. Also independent source rights, game compatibility, complete originals preservation and genuine installation/recovery permission remain separate **BLOCKED** gates.

## Meaning of the launcher result

The helper reports that the **fake fixture bytes were unchanged** after you close each window. It cannot determine what your actual Windows scaling is, whether you saw clipped labels or whether a screen reader announced text. A green console output must **not** change any physical test cell from `NOT TESTED`. Fill those entries **only from your own direct observation**. Never submit private screenshots, folder paths or SavedVariables to CI.

## QA launcher failure handling (automated safety tests)

The **source-only** launcher requires exactly one of `-Interactive` or `-Headless`. Missing/conflicting modes, an unrecognised `-Scenario`, an attempt to provide `-ClientPath`, or a GUI request from CI are rejected **before** the fixture is invoked. If the Ready fixture exits with an error, the Blocked fixture **will not** open; if Blocked fails, the launcher reports a failure rather than completion. These behaviours are regression-tested in a disposable Windows PowerShell 5.1 sandbox; they are not a guarantee about a real game installation.

The underlying disposable test now checks the **directory structure, including empty subfolders**, as well as file content and length. Linked/reparse entries in that disposable snapshot are refused. This closes a testing blind spot, but it does not create or verify actual original backups, guarantee crash durability, or constitute human accessibility acceptance. A failure means **do not mark that session PASS**; retain a privacy-safe description of which scenario failed and rerun after correction. All physical scaling, Narrator, contrast-theme and keyboard acceptance cells above remain **NOT TESTED** until directly observed.
