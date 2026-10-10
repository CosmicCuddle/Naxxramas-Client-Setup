# Launcher artwork — easy to update

The launcher supports two image layers, and **does not copy either image into World of Warcraft**.

1. **Packaged default**: `assets/default/launcher-art.png` is the current featured artwork. When a default file is present in the GitHub development branch, the Windows preview package automatically includes it.
2. **Personal override**: `assets/local/launcher-art.png` takes priority over the packaged default. That folder is Git-ignored and never published.
3. **Temporary selection**: The **Choose artwork...** button can load any personal PNG/JPEG for the current launcher session, without changing either file.

Optional logos work the same way: `assets/default/launcher-logo.png` for an approved packaged logo and `assets/local/launcher-logo.png` for a personal replacement. Without any logo file, the launcher uses its normal NAXXRAMAS title.

## How to change the image in future

Replace the file in `assets/default/launcher-art.png` and rebuild the preview ZIP. **No code changes are needed.** For a private preference, use `assets/local/launcher-art.png` instead.

The picture is displayed using aspect-ratio-preserving scaling; wide artwork will not stretch. The file should be a PNG or JPEG under 30 MiB.

Only distribute art you have permission to include. A private repository does not grant copyright permission. Do not upload game files or Blizzard assets to the repository without the appropriate rights.
