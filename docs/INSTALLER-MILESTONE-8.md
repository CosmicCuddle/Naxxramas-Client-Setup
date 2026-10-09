# Milestone 8 — Classic-era launcher layout and downloadable preview package

**Development-only.** The installer cannot yet change any real WoW client files. This prototype is intended for manual visual and workflow testing.

## Visual redesign

The window now uses the structure associated with the older World of Warcraft launchers:

- Top engraved-style title band and build text
- Wide left-hand illustration area, with an optional locally supplied image and logo
- Framed news and verification log under the illustration
- Compact client, patch and addon selectors on the right
- Permanent bottom action bar, including **PREVIEW**, Inspect, Clear and Cancel
- No long page scrolling; only the options or verification log scroll when necessary

The bundled visual fallback is an original decorative gradient and simple line motif—not Blizzard artwork. The public development repository does not contain Blizzard logos or game images.

## Personal-use artwork

If you have artwork you're entitled to use locally, place it in the repository copy at:

~~~text
assets/local/launcher-art.png
assets/local/launcher-logo.png
~~~

The artwork is loaded **from disk at runtime**. The filenames are exact and case-insensitive on standard Windows filesystems. The application doesn't download or upload them and doesn't modify the user's source files.

The art panel crops the background like a classic launcher and scales the logo to fit. If either file is absent, its fallback is displayed. PNG files larger than 30 MiB are rejected.

The local-art folder is excluded from Git by `.gitignore`. When a release becomes downloadable, it must not automatically include third-party copyrighted assets just because development happens in a private repository.

## Downloadable preview ZIP

After Windows tests pass, the GitHub workflow packages a ZIP named **Naxxramas-Client-Preview.zip** and offers it as an Actions artifact, named **naxxramas-launcher-preview**.

The package contains only the read-only launcher interface, its local validation engine, and configuration manifests. It contains no WoW executable, no game client archive, no MPQs, no installer-patch payload, and no original Blizzard artwork.

To test the downloadable preview:

1. Open the successful Windows workflow under the development pull request.
2. Download the `naxxramas-launcher-preview` artifact.
3. Extract the ZIP into a folder outside World of Warcraft.
4. Open `tools/Launch-Naxxramas-Preview.bat`.
5. Optionally add artwork to `assets/local` inside the extracted copy.
6. Choose your existing client folder and use PREVIEW to inspect the proposed changes.

No automatic download, installer writes, or game file modifications are enabled.

The artifact is a **development preview** and must not be advertised as an installation-ready release.

## Testing

GitHub Actions runs existing patch, transaction, recovery and addon tests, then uses a headless WinForms smoke test at multiple window sizes. The GUI test also creates tiny synthetic PNGs and verifies that local-art support doesn't prevent the window from constructing.

Human Windows testing is still needed for the visual proportions, 125%/150% DPI, accessibility and artwork choices. Before real-client writes are enabled, permission handling, rollback and source licensing remain separate blockers.
