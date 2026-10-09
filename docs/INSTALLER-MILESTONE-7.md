# Milestone 7 — Windows graphical preview

**Status: draft development branch. No production installation actions.**

This is the first graphical client setup prototype, written using Windows PowerShell 5.1 and built-in Windows Forms controls. No third-party UI framework, game client, MPQ files or proprietary assets are bundled.

## Design goals

- Readable layout with large labels, dark background, gold accents and high-contrast status text.
- Clear choice of the local WoW 3.3.5a directory (must contain `Wow.exe`).
- Optional separate local patch source for V and Z, plus optional J and U.
- Optional official N Addon Collection v2.0.0 ZIP: the suite always includes NCore, while the other four modules are independently selectable.
- A visible **Preview changes** action, plus **Inspect recovery state**.
- A results panel that reports changes, source integrity, disk-space estimate, and any errors from the backend.
- Background processing so checksum work does not freeze the interface.
- **No Install button. No download button. No game-client writing or recovery in the GUI.**

## How to open it on Windows

1. Download the development branch as a ZIP and extract it **outside** your WoW directory.
2. In the extracted repository, open `tools`.
3. Run **`Launch-Naxxramas-Preview.bat`**.
4. Select the existing folder containing `Wow.exe`.
5. If necessary, choose your **separate** local patch source (with a `Data` subfolder).
6. Optionally browse to the official N Addon Suite v2.0.0 ZIP and select addon features.
7. Click **Preview changes**. Read the output. Do not treat a successful preview as proof that an installation is ready.
8. **Inspect recovery state** is also read-only and can help diagnose past test installs.

If no patch source is provided, the preview still works when the existing client already has matching mandatory V and Z files. The backend validates source hashes against the currently pinned `patchset-0001`. The ZIP is checked against the release's recorded SHA-256.

## What the program deliberately cannot do

The GUI calls the existing installer script ONLY with `-Action Plan` or `-Action Inspect`, using a strict argument builder. It never exposes or forwards `-Action Install`, `-Apply`, `-ConfirmDisposableFixture`, update actions, or failure simulation controls.

The results are displayed as text. Game files are only read; the background PowerShell job is stopped if the window closes.

No network downloads, background update checks, installer distribution or telemetry are included.

## Windows automated checks

The additional CI tests cover:

- The GUI and argument-building library parse under Windows PowerShell 5.1.
- The WinForms screen is constructed in a headless smoke test (no dialog shown).
- The argument builder refuses write actions and unknown addon names.
- NCore's optional-suite relationship and optional J/U selections are represented correctly.
- The read-only preview job handles paths with spaces and special characters without constructing executable code.
- Inspect receives only the necessary client and action arguments.
- Constructing preview requests leaves a synthetic WoW directory unchanged.

A GUI that constructs successfully may still have layout, scaling, focus, or accessibility issues. Those require manual interaction testing on Windows, especially at 100%/125%/150% display scaling and with keyboard navigation.

## What comes next

1. Review the GUI visually and correct spacing, focus order and scaling.
2. Strengthen the backend's permission, source-integrity and journal-authentication boundaries.
3. Test full-sized **disposable** game copies with owner-provided, authorised files and reliable backups.
4. Review legal permissions for redistribution of every custom game patch.
5. Only after acceptance testing, add an explicit installation confirmation screen and a tested rollback path.

**The current UI must not be advertised as an install-ready player release.**
