# Milestone 4 — Player-readable installation review (read-only)

**Status: usable offline preflight display, not an installer or genuine approval screen.** The command reads a local client, local source patches when selected, and an existing separately selected backup folder through the [read-only installation planner](INSTALLER-PLAN.md). It **does not change the client, patches, backup folder, realmlist, Windows registry or any report file**.

## What this adds

Previous milestones established strict real-file rules but much of the output was technical: SHA-256 fingerprints, file IDs, interrupted checkpoint claims and opaque states. The new script `tools/Show-Naxxramas-InstallReview.ps1` presents those **existing planner decisions** in clear, consistent language suitable for a future accessible setup wizard.

Every one of the five recognised paths is explained:

| Game file | How it is presented | Player choice |
| --- | --- | --- |
| `Data/patch-V.mpq` | Required core patch V | Always part of the selected Naxxramas setup |
| `Data/patch-Z.mpq` | Required core patch Z | Always part of the selected Naxxramas setup |
| `Data/Patch-J.mpq` | Optional Vanilla login screen | Independently selected with `-VanillaLogin` |
| `Data/Patch-U.mpq` | Optional Vanilla loading screens | Independently selected with `-VanillaLoading` |
| `Data/enUS/realmlist.wtf` | Realm address settings | Reviewed using the configured address or `-RealmHost` |

The reviewer translates known actions into plain English:

- **Keep existing file unchanged** — already matches expected content.
- **Preserve existing file (not replacing it)** — including an existing unselected optional J/U file or an existing realmlist with extra valid settings.
- **Not selected; leave it alone** — no file is proposed.
- **Would add a new file after separate approval** — it is currently absent.
- **Would replace ONLY after an exact original backup and separate approval** — an existing recognised older patch or differing known realmlist would need its exact original preserved *before* any future replacement.
- **Blocked: existing files must be preserved for review** — unfamiliar V/Z/J/U contents, missing selected source files or other existing planner blockers.

These are **hypothetical actions only**. There is no apply, install, confirm or consent button.

The display also shows selected cosmetic choices, realm address, number of proposed additions/replacements, byte size of originals that *would* need backing up, separate backup folder selection and separate client/backup **estimated** capacity. These estimates are not reserved space. No original backup is created or verified.

## Read-only use on Windows

Run from a downloaded Naxxramas-Client-Setup repository checkout using **Windows PowerShell 5.1**. Use a separately backed-up client copy for any experimentation:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Show-Naxxramas-InstallReview.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Local-Naxx-Patches" -BackupRoot "F:\Independent-Backups" -VanillaLoading`

Add `-VanillaLogin` to select optional J independently, or omit `-VanillaLoading` to leave U unselected. For a preview of a different realm, provide a simple hostname/IP to `-RealmHost`.

To receive a stable machine-readable summary rather than plain text:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Show-Naxxramas-InstallReview.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Local-Naxx-Patches" -BackupRoot "F:\Independent-Backups" -VanillaLoading -Json`

These are **example paths, not folders checked or created**. Nothing is downloaded. The tool prints to the console/stdout only; it does not create a report file.

If you omit a separate backup folder while proposing to add/replace files, the player-friendly review explicitly marks manual review as required even if the lower-level planner has no other blockers.

## Accessibility and player trust

- **Plain language with stable file order.** Each file has a title and an explicit action. Selection state is text, never conveyed by colour alone.
- **No secret or hidden action.** The header and footer prominently say this is read-only, and JSON unconditionally reports `file_writes_authorised=false`, `genuine_user_consent_collected=false` and `original_backups_created=false`.
- **No absolute private paths in the player summary.** Player-facing output names only allowlisted **relative game paths**, not the local Windows directory, source hash, installation ID or backup file identity.
- **Offline friendly.** The view requires no login, account, token, DPAPI key or network connection. This does not grant permission to install offline or prove replay-resistant consent.
- **Dyslexia-friendly future design.** Keep short action labels, consistent headings, easy-to-scan spacing, full keyboard access and explicit cancellation in a future graphical UI. Do not add a misleading disabled-looking “Install now” button or claim the review represents a human approval event.
- **Cosmetic overlap warning.** When J and U are both selected, the existing planner's warning about overlapping loading screen textures is shown; the in-game precedence remains untested.

## Windows CI coverage

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-PlayerInstallReview.ps1"`

The suite builds **tiny fake text patch files**, a harmless versioned `Wow.exe` fixture, an older recognised fake V, a current fake Z, an existing unselected private fake J, a missing but locally available fake U, a differing realmlist, and a separate backup directory with a sentinel. It invokes the **real planner**, then checks:

- Exactly five known file explanations in stable order.
- Older V and differing realmlist correctly marked as **requires original backup**, while absent U is a proposed add, current Z is unchanged, and unselected existing J is preserved.
- Exact count and byte estimate of prospective original backups, with no claim a backup was made.
- Optional J/U independence, rejection of an unfamiliar selected J, and the joint J/U overlap warning.
- Unrecognised mandatory V, missing selected patch source and omitted separate backup location blocked for review.
- Plain-language text contains prominent no-write warnings; JSON preserves all consent/no-write flags.
- Source, client and existing backup sentinel bytes remain unchanged; personal absolute paths and source hashes are not shown.

All writes in the test are confined to a uniquely generated **disposable temporary folder**. The runtime script does not create, copy, replace, remove or restore any game file.

## Guided Windows review window

The [Guided Windows Setup](GUIDED-WINDOWS-SETUP.md) milestone now uses this same real read-only player review behind a **Windows Forms GUI** with existing-folder pickers and independently optional J/U controls. It is only a friendlier way of inspecting the same plan, never an approval click. The form clears older previews when inputs change and never offers installation, rollback or backup operations.

## Important limits and next engineering gate

This new view **summarises one invocation of the existing read-only planner**. It is not an atomic file snapshot, lacks held handles across later operations, and does not revalidate contents after the review finishes. A different script can modify files after a preview; a match is never proof of owner consent.

We also have **not chosen** between a strictly offline local installation model (cannot guarantee full coherent replay detection) and an opt-in independent latest-state authority (would require deliberate decisions about privacy, credentials, offline update availability, support and account recovery). That architecture remains subject to a separate owner decision; no server-side service or account is being created.

A genuine future setup wizard must separately implement accessible exact-plan review, a **real user action**, short-lived consent bound to fully validated live files and protected transaction state, exact durable original backups, known source rights, safe write-time Windows handles and non-destructive recovery. Until those blockers are independently resolved, the installer, updater, uninstaller and rollback remain disabled.

Related: [Installer Plan](INSTALLER-PLAN.md), [Owner Recovery Policy](OWNER-RECOVERY-POLICY.md), [Original Backup Readiness](BACKUP-ORIGINALS-READINESS.md), [Roadmap](ROADMAP.md), [Project Handover](PROJECT-HANDOVER.md).

**A clear preview is not permission to install.**
