# Owner-managed launcher artwork

The launcher loads its displayed background from exactly:

`assets/default/launcher-art.png`

If a launcher logo is supplied, it loads:

`assets/default/launcher-logo.png`

**Players have no artwork controls.** There is no artwork picker, status strip, personal override, or setting to change these files through the launcher.

## Changing the artwork in a future release

1. Make a backup of the existing `assets/default/launcher-art.png`.
2. Replace the file with your newly chosen image, using **exactly the same filename**.
3. Rebuild the downloadable launcher package.
4. Test the preview and issue the updated package.

No application-code changes are needed. For the logo, replace `launcher-logo.png` in the same way.

If the artwork file is absent, the launcher displays `LAUNCHER ARTWORK UNAVAILABLE`. The program still runs and the preview remains read-only. Supported image files are PNG or JPEG, subject to the existing 30 MiB size limit; keep `launcher-art.png` as a valid PNG for the standard package.

Only distribute artwork for which you have the appropriate rights.
