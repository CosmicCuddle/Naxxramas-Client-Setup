# Windows Read-only Wizard — Manual Accessibility Test Record

**Acceptance status: NOT TESTED.** This document is a blank, privacy-safe worksheet. Running CI or seeing successful diagnostics does **not** complete any entry.

**Source:** [Windows Accessibility Acceptance](WINDOWS-ACCESSIBILITY-ACCEPTANCE.md). Test a disposable synthetic client only; never your only working WoW client.

## Before testing

- Open the source repository on a physical Windows desktop using Windows PowerShell 5.1; do not run the headless `-Diagnostics` variant as a substitute for seeing the window.
- Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-SetupWizard.ps1" -ManualReview -ManualScenario Ready` to open the actual wizard with throwaway fake files. Repeat with `-ManualScenario Blocked`.
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
