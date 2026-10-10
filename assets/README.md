# Personal launcher artwork (not bundled)

To customise your **local** Naxxramas launcher preview, create an `assets/local` folder next to this README and supply:

- `launcher-art.png` — the wide illustration displayed on the left
- `launcher-logo.png` — an optional transparent logo overlay

Images are read locally; they are not copied into the World of Warcraft client.

These personal assets are ignored by Git and excluded from the downloadable preview archive. Only include artwork in a distributed build if you have the necessary permission.

Without either file, the launcher shows its built-in original fallback design.

The preview also has a **Choose artwork...** button beneath the hero panel. This lets you browse to a personal PNG or JPEG for the current session without moving or renaming your original image. It is read-only and does not make a copy.

The image uses aspect-ratio-preserving scaling; the logo is displayed in the top title bar. The blank illustration state now says "LAUNCHER ARTWORK NOT SELECTED" rather than displaying the former decorative arcs and duplicate gold borders.
