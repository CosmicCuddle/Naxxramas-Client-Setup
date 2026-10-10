# Milestone 10 — Pinned and verified patch source downloads

**This is a development tool, not permission to distribute game files or install into an actual WoW client.**

## Verified release sources

The owner-published GitHub releases have these specific file identities, matching the current `patchset-0002` reference:

| Patch | Required? | Release | Filename |
|---|---|---|---|
| V | Yes | `v1.0.6.8.4` | `patch-V.mpq` |
| Z | Yes | `v1.0.6.7` | `patch-Z.mpq` |
| J (Vanilla login) | No | `optional-v1.0` | `Patch-J.mpq` |
| C (TBC login) | No | `optional-v1.0` | `Patch-C.mpq` |
| U (Vanilla loading) | No | `optional-v1.0` | `Patch-U.mpq` |

The exact HTTPS URLs are held in `config/patch-downloads.json`. The downloader checks them against an exact allowlist and cross-checks the SHA-256 and file size against `config/client-patches.json`. It does not follow untrusted version feeds or choose “latest” automatically.

## Faster folder selection — Paste path

The classic launcher has **Browse** and **Paste** buttons next to each location field (game client, separate patch source, optional addon ZIP).

1. Open the desired folder in Windows File Explorer.
2. Use **Copy as path** (or click the Explorer address bar and copy the full path with Ctrl+C).
3. In the launcher, press **Paste** beside the matching field.
4. The launcher removes surrounding quotation marks, checks that the location exists, and fills the editable path field. It does not change your game files.

**Ctrl+V directly inside a path field also works.** The launcher cleans up the surrounding quotes after you leave the field. The separate Browse dialogs remain available for navigating visually.

When pasting an addon ZIP, copy its **file** path, not its containing folder. A copied ZIP file is not accepted as a WoW folder, and a directory is not accepted as an addon ZIP. Errors appear as small messages rather than unhandled Windows exceptions.

## Download directly from the classic launcher

1. Select your existing WoW client folder.
2. Create a separate folder outside your WoW client and outside the launcher, for example `C:\Naxxramas-Patch-Sources`. Select this with the launcher’s **Local patch source** Browse button.
3. Choose **Vanilla login (J)** or **TBC login (C)** (or neither). You may independently select **Vanilla loading (U)**.
4. Click **Get patches** in the lower-left toolbar.
5. Read the confirmation showing the destination folder, and choose **Yes** to download from the pinned GitHub release URLs. Choosing No does not download.
6. The launcher downloads any missing required core files and optional selections to the separate source folder, verifies SHA-256 and byte size before accepting them, and reports status in the verification log.
7. Click **PREVIEW** to review the setup plan against those local sources. **No game installation occurs.**

**Important:** The **Cancel** button stops the active background task. If a download is interrupted, a temporary `.partial` file may remain inside the separate patch source folder and can be removed after the downloader has stopped. A failed verification never turns that partial file into an accepted MPQ.

The publisher provides download links only; the preview does not bundle copyrighted MPQs. Players must have any rights required to obtain or use these files.

## Manual use in Windows PowerShell 5.1

1. Extract the complete launcher project **outside** your WoW folder.
2. Create a separate empty folder, for example `C:\Naxxramas-Patch-Sources`.
3. Open Windows PowerShell inside the launcher folder.
4. Run a read-only plan:

~~~powershell
.\tools\Get-Patch-Sources.ps1 -ClientPath "D:\Games\World of Warcraft" -PatchSourcePath "C:\Naxxramas-Patch-Sources"
~~~

5. When you have reviewed the plan, explicitly approve saving the required V/Z downloads into your separate source folder:

~~~powershell
.\tools\Get-Patch-Sources.ps1 -ClientPath "D:\Games\World of Warcraft" -PatchSourcePath "C:\Naxxramas-Patch-Sources" -Action Download -ConfirmDownload
~~~

6. Optionally include TBC login C and Vanilla loading U:

~~~powershell
.\tools\Get-Patch-Sources.ps1 -ClientPath "D:\Games\World of Warcraft" -PatchSourcePath "C:\Naxxramas-Patch-Sources" -TbcLogin -VanillaLoading -Action Download -ConfirmDownload
~~~

For Vanilla login, substitute `-VanillaLogin` for `-TbcLogin`. **Never select J and C together.** The downloader also refuses an incompatible login patch that is already installed in the game.

## Safety behaviour

- **Plan** reads and hashes existing files, with no writes.
- **Download** requires `-ConfirmDownload`, an already-existing destination folder, and a client folder containing `Wow.exe`.
- The patch source directory cannot be inside (or contain) the selected client or launcher directory.
- Only the five pinned GitHub release assets are accepted; no arbitrary URL can be supplied.
- Every download is staged in a randomly named `.partial` file and validated for SHA-256 and expected size **before** it is moved to `Data/`.
- An existing correct source file is reused. A mismatched file is rejected, not overwritten.
- A download error can leave already verified patch sources in the separate folder; it never rolls those back. Rerunning safely skips verified files.
- The downloader creates no `.naxxramas-setup` transaction state and has no `Install`, `Rollback`, or recovery switches.
- It never writes or deletes anything in the game client.
- Synthetic testing uses a marker-locked dummy fixture, not network access or actual MPQs.

An interrupted download may leave a `.naxx-download-*.partial` file in the separate patch source folder; that temporary file is not a valid source and can be deleted after confirming no downloader is running.

## Limitations

Automated tests cover source validation and local synthetic transfers, including hash rejection, safe reuse, J/C conflict handling, and source-folder isolation. The tests do not prove that live internet downloading succeeds on every player's network, and they do not test the original game's runtime compatibility. Official release availability and licensing must still be reviewed for future distribution.
