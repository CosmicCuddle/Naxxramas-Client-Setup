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

## Owner-managed artwork

The preview reads `assets/default/launcher-art.png` automatically. The optional title logo is `assets/default/launcher-logo.png`.

The final player interface contains **no artwork button, image picker, personal override or replaceable-art label**. A missing image shows the neutral `LAUNCHER ARTWORK UNAVAILABLE` fallback.

To update an image later, the project owner backs up the current file, replaces it with the new PNG using **the same filename**, then rebuilds and tests the downloadable ZIP. There is no need to change the program.

Art must be redistributable before being included in a player release.

## Downloadable preview ZIP

After Windows tests pass, the GitHub workflow packages a ZIP named **Naxxramas-Client-Preview.zip** and offers it as an Actions artifact, named **naxxramas-launcher-preview**.

The package contains only the read-only launcher interface, its local validation engine, and configuration manifests. It contains no WoW executable, no game client archive, no MPQs, no installer-patch payload, and no original Blizzard artwork.

To test the downloadable preview:

1. Open the successful Windows workflow under the development pull request.
2. Download the `naxxramas-launcher-preview` artifact.
3. Extract the ZIP into a folder outside World of Warcraft.
4. Open `tools/Launch-Naxxramas-Preview.bat`.
5. The launcher displays the built-in `assets/default/launcher-art.png` (when supplied by the publisher); players cannot change it in the interface.
6. Choose your existing client folder and use PREVIEW to inspect the proposed changes.

No automatic download, installer writes, or game file modifications are enabled.

The artifact is a **development preview** and must not be advertised as an installation-ready release.

## Testing

GitHub Actions runs existing patch, transaction, recovery and addon tests, then uses a headless WinForms smoke test at multiple window sizes. The GUI test creates synthetic default PNGs, replaces the default file with a differently coloured image, and verifies the image checksum changes without altering executable code.

Human Windows testing is still needed for the visual proportions, 125%/150% DPI, accessibility and artwork choices. Before real-client writes are enabled, permission handling, rollback and source licensing remain separate blockers.
