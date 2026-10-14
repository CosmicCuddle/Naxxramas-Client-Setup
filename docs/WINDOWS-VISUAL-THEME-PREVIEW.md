# Naxxramas visual theme — read-only prototype

**Status: preview-only visual treatment; NOT a player installer or final design.**

## Design intent

The existing Windows PowerShell 5.1/WinForms wizard is a **read-only file review** for development, not a working installer. It previously used a generic light Windows application palette. This iteration adds a restrained, original Naxxramas-inspired dark presentation without importing any Blizzard or third-party art, fonts, game textures, client binaries or copyrighted media.

The palette uses dark charcoal/stone backgrounds, readable pale text, subdued necromantic-teal action accents, and warm antique-gold section headings. A narrow decorative trim under the header makes the visual hierarchy more intentional. Native Windows checkboxes, text fields, the scrollbar and keyboard focus handling remain intact. This is a **first skin pass**, not a final fantasy-themed launcher. There is no background image, animation, installer progress, download or patch installation.

## Accessibility and safety invariants

- **Windows High Contrast always takes priority** over the custom palette, including text, backgrounds, borders and file-grid headers. Its colours are sourced from Windows `SystemColors`, not hard-coded fantasy colours.
- Keep Segoe UI, large ordinary buttons, descriptive labels, keyboard Tab/Shift+Tab, Enter/Escape actions, visible focus and the existing responsive scroll extent. Do not use decorative art in place of readable text.
- The six-file `View File Details` review remains a native, read-only grid with status, original-backup warnings, and a keyboard-operable Close Review.
- This design has **no permission** to install, update, back up, restore, delete, download or distribute game assets. Required V and Z remain mandatory; optional J and C are exclusive; optional U stays independent; personal settings remain untouched.
- The high contrast and theme checks in Windows CI validate **programmatic control properties**, not pixels, live accessibility announcements or rendering at 300% DPI. Failures seen by people take precedence over green CI.

## Recommended manual appearance checks

Use the **source checkout** under Windows and run `tests/Start-Accessibility-ManualCheck.bat` against generated disposable fake files only. At the owner's usual, reported **300%** display scale:

1. Check dark/teal/gold text legibility, checkbox contrast and focus outlines. Confirm all scrolling labels and the six-file details still fit.
2. Enable **Settings > Accessibility > Contrast themes** in Windows and apply a contrast theme before opening the wizard again. Native and custom controls must use Windows contrast colours. Check the secondary buttons, grid headings, warning reader and Close Review.
3. Return to the usual contrast theme, **reopen** the wizard, and check ordinary styling is restored. Report clipping, invisible focus or missing controls as **FAIL** with only redacted repro steps; do not publish personal paths or screenshots.

If the user does not use Narrator, screen-reader results remain **NOT TESTED** rather than inferred from Windows CI. The 100/125/150/200% physical matrix is also still open. A theme is **not** verified until actually viewed in Windows.

## Future polished player experience

After practical visual acceptance and the independent legal/safety approvals, a future installer could use a purpose-built Naxxramas-branded UI with licensed or entirely original imagery, step-by-step panes, readable file-review and backup/consent stages. The **current themed preview is not that installer**; no game or account files may be modified without the separate documented original-backup, authentic consent, journal, recovery and rights gates.

## Decorative artwork follow-up — 14 October 2026 (PR pending)

The first dark palette alone was considered too generic. The next source-only review prototype draws original necropolis-style vector artwork in an enlarged header, adds a subtle rune-halo glow and a **visual-only** animation toggle. Window High Contrast and disabled Windows animation effects take precedence. No images, downloads, new UI framework or game files are needed. Physical confirmation of the **new** artwork at the owner's actual 300% scale is still **NOT TESTED**. See [art and motion acceptance steps](NECROPOLIS-ARTWORK-PREVIEW.md).
