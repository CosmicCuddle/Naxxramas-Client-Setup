# Updating Naxxramas client patches

The game files remain on the server owner's PC; GitHub stores version metadata, not copyrighted WoW client files.

## What we track

The patch policy is config/client-patches.json. It keeps the latest reviewed reference checksums and identifies mandatory versus optional patches.

- V + Z: always mandatory for a complete Naxxramas setup.
- J: optional Vanilla login visuals (also contains some loading-screen assets).
- C: optional TBC login visuals; mutually exclusive with J.
- U: optional loading screens (overlaps with J on two textures).

Historical records are under config/patch-versions. Starting with patchset-0001, every future reviewed update receives a new version, such as patchset-0002. A newer patch can keep the same filename while its contents and SHA-256 change.

## When you edit any of the patches

1. Back up the original MPQs and finish testing on a separate copy of the WoW client.
2. Get the latest repository ZIP from GitHub and extract it outside the WoW folder.
3. Open tools and drag the folder containing Wow.exe onto Prepare-Patch-Update.bat.
4. The program reads all five patch entries when present and creates tools/patch-update-proposal.json if any changed.
5. Review and send that small JSON privately. It contains relative filenames, hashes, sizes, version numbers and a date, not game binaries, absolute paths, account data or config.
6. Describe the gameplay changes, any DBC dependencies, and whether the updated client was tested.
7. After review, the maintainer updates config/client-patches.json and creates a new immutable record at config/patch-versions/patchset-XXXX.json. Commit the two changes together.
8. Check client compatibility, individual and combined J/U appearance where affected, and any future install/upgrade/rollback routine before publishing.

The proposal tool never updates the live manifest itself, never uploads MPQs, and does not change game files. A patch update is not approved until the report is reviewed and committed. It will not overwrite an earlier unreviewed proposal; save or rename the older report before running it again.

## How players will update (planned, not implemented)

The eventual installer will compare local file hashes to the current manifest and version history.

| Result | Planned behaviour |
| --- | --- |
| Matches current version | No patch change needed |
| Matches older known version | Offer an authorised, verified upgrade |
| Unknown hash | Warn and stop, avoiding unsafe replacement |
| V or Z missing | Reject installation |
| J or U missing | Accept if the player did not select the option |

Every file change must have a backup and a recorded before/after checksum. Updates must come from a legally authorised source. Reference records and published assets must be coordinated to avoid offering an unavailable version.

## Operational rules

- Never delete or overwrite historical version records; these are needed to recognise previous installations.
- Do not require a complete 18.6 GB game download just because a custom patch changed.
- No full MPQs or WoW game binaries are stored in this repository.
- The owner-supplied 9 October 2026 screenshot supplies baseline V/Z checksums. It does not establish redistribution rights, provenance or runtime testing.
- Store prior working V/Z files privately for recovery.
- Test J and U separately and together if either one changes, since their loading-screen assets overlap.

The actual installer, remote updater, patch distribution, automatic rollback and self-update functionality are not implemented yet.

## Read-only GitHub release-reference drift check (13 October 2026)

For a **source/developer-only metadata check**, the repository includes `tools/review_public_release_drift.py` and [public release drift guide](PUBLIC-RELEASE-DRIFT-REVIEW.md). At the time of the check, the official latest stable **Patch-V** is v1.0.6.8.4 and its referenced SHA-256/size still match patchset-0002. Patch-Z remains independently pinned to v1.0.6.7 (the newest release does not bundle a new Z). Optional C/J/U remain optional-v1.0 and N Addon Suite remains v2.0.0.

Use **Actions → Read-only public release reference drift review → Run workflow** to check GitHub release metadata without changing a client. PR CI tests only an offline frozen public metadata snapshot. The operator-invoked live check reads two specific public GitHub release-list endpoints and flags a new stable V, Z, individual optional MPQ or addon version. **No binary MPQ/ZIP downloads, patch proposals, backups or updater actions occur.**

When drift is flagged, verify the published new asset, rights, checksum and in-game behaviour; keep existing client contents untouched and create a **new immutable patchset** only after review. A public source listing and matching SHA-256 are not rights clearance, signed provenance or installer authority. No installation or public release permission is granted.

## Developer-only proposal evidence review (13 October 2026)

A new read-only [patch proposal evidence reviewer](PATCH-PROPOSAL-EVIDENCE.md) compares a saved `patch-update-proposal.json` against the frozen `patchset-0001/0002` source records and a separately supplied public GitHub release metadata snapshot. It checks V and Z independently, then optional J, C and U independently. **No local game directory is opened by this reviewer.**

An internally consistent, publicly matching proposal still returns `manual_review_required_NO_INSTALL_AUTHORITY`. It never creates patchset-0003, rewrites manifests, downloads MPQs, overwrites older files or installs content. A missing/unknown source reference and conflicting claimed before/after state block any inference of approval. Only an explicitly owner-reviewed **new** immutable patchset could be considered later, after separate source rights, authentic backups, game and consent checks.

**Correction to older overview above:** the current v2 patch policy contains **five** patch files (V/Z/J/C/U), rather than four. Optional **C** (TBC login) and **J** (Vanilla login) are mutually exclusive selection choices; U remains independent and J/U share two loading-screen texture paths. A proposal reviewer warns about observed C/J or J/U presence but never deletes either patch.
