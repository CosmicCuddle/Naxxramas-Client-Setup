# Original Necropolis Artwork — Review-only UI Prototype

**Status:** First human-review candidate. This is still a PowerShell 5.1 / WinForms **read-only** client review window, **not** an installer.

## What is new

The original small dark header is replaced with a roomier hero section showing an **original vector-drawn floating gothic citadel, runic gate, arcane circle, carved border and mist**. No Blizzard textures, fonts, WoW cinematics, private art, downloads, MPQ files or external binary resources are required. Artwork is compiled locally from text in `tools/Naxxramas-WizardDetails.ps1`, using the existing .NET Windows Forms and Drawing assemblies; it is a decorative header, not a new GUI framework.

An optional **Enable subtle rune glow** checkbox animates only the painted halo/runes, at a low frame rate with modest luminosity variation. It **never** moves controls, flashes warnings or affects review results. It defaults to motion only where **Windows client-area animation settings allow it**, and is disabled automatically in Windows High Contrast or where the Windows motion setting cannot be read. The user may uncheck it at any time, without restarting. No preferences are saved, and no external files are accessed. **The timer is not allowed to run in headless diagnostics; tests do not open a game window.**

The taller header reserves additional scroll extent rather than covering the three client folder fields or optional choices. Existing native text boxes, checkboxes, screen-reader descriptions, six-file review, Tab/Shift+Tab focus and Enter/Escape shortcuts remain; all user-facing actions are still read-only.

## Physical Windows acceptance still required

Check only the existing disposable **fake-file** Ready/Blocked tester (`tests/Start-Accessibility-ManualCheck.bat`) extracted outside the WoW folder.

1. At your preferred actual Windows **300% scaling**, confirm the necropolis artwork is visible without hiding the title, read-only disclaimer or folder fields. Check normal mouse/keyboard navigation and all six file rows are still reachable by scrolling.
2. Toggle the **Enable subtle rune glow** checkbox. Observe that **only the halo and runes pulse softly**, with no moving controls or flashing text; toggle OFF and make sure animation stops.
3. If comfortable, use Windows **Settings > Accessibility > Visual effects > Animation effects** to turn animation effects OFF, then reopen the tester. The rune glow should be disabled and unavailable. Restore your preferred Windows setting afterwards.
4. If available, enable a **Windows Contrast theme**, relaunch and confirm original artwork/motion do not override system contrast or hide warnings and buttons. Revert the theme and restart before comparing the regular colours.
5. Report **any** clipping, unreadable label, animation discomfort, delayed input or obscured control. Do not publish screenshots with local paths, private account data or downloaded game files.

Headless CI asserts only control construction, system-setting gating, focus-safe layout, retained six-file and read-only semantics. It **cannot** prove how the art looks or moves at 300%, any screen-reader announcements, or safety of a genuine client install. Mark these manual checks **NOT TESTED** until directly observed.

## Strict limits

V and Z remain mandatory. J and C remain mutually exclusive and U independent. No patch, client, addon, account, SavedVariables, realm or backup writes; no installer, rollback, download, permission or public release. The existing scripts-only candidate remains internal. Future truly game-like graphics, packaging and any new licensed art or installer flow require separate owner approval and safety/recovery review.
