# Naxxramas realmlist configuration

The server owner supplied a 28-byte ASCII file called `realmlist.wtf` on 9 October 2026. Its complete contents were:

```text
set realmlist 85.190.254.242
```

The configured default address is stored in [`config/realm.json`](../config/realm.json), separate from the MPQ patch-set version. If the public server address changes, update that JSON and the related documentation, then run tests. **Do not change patch V or Z just to update a realmlist address.**

The intended client location for the current `enUS` build is `Data/enUS/realmlist.wtf`. The realmlist is a player-facing network address, not a username or password.

## What the tools do now

The read-only `tools/Check-Naxxramas-Client.bat` checks the default address from `config/realm.json`. It reads the existing `Data/enUS/realmlist.wtf` (if present) and displays whether it matches, differs, or needs configuration.

If a different address is found, the tool **only warns**. It does not overwrite, delete, move, back up, or create anything in the game folder.

`Test-Naxxramas-Client.ps1 -RealmHost example.org` allows a temporary command-line override when checking a future address without changing the repository configuration.

## Future installer requirements

1. Use the default host from `config/realm.json`, with an advanced/manual override.
2. Display the destination path and proposed text for approval.
3. Close WoW before making any changes.
4. Save the exact previous `realmlist.wtf` bytes before replacing the file; do not depend on reconstructing its old contents.
5. Use a staged temporary file and verify the written bytes.
6. Record the change and backup in the installation manifest, and restore the old file on rollback.
7. If a player's file has been changed after installation, do not overwrite it during rollback without resolving the conflict.
8. Verify the public realm's network reachability and AzerothCore `realmlist` configuration separately, before a real player release.

**Important:** We have verified the address appears in the supplied file; no live connectivity test has been performed, and no file-writing installer is available yet.
