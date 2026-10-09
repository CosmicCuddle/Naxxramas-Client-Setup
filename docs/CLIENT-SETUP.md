# Inspecting the existing Naxxramas client

**Please keep your current working client untouched.** Back it up before any later installation or cleanup work.

## Inventory (read-only)

1. Download the repository ZIP from GitHub and extract it to a separate folder.
2. Open its \`tools\` folder.
3. In File Explorer, find the **folder containing \`Wow.exe\`** in your existing client.
4. Drag that **folder** onto \`Inspect-Client.bat\`.
5. When the black window reports completion, open \`tools/client-inventory.txt\`.

You can share the resulting text file in our development chat after reviewing it. **Do not upload it to a public repository if it contains filenames you would rather keep private.**

### What does the inventory contain?

- Filenames and folder names at the top level of the client.
- The names and approximate sizes of MPQ files under \`Data\`.
- The names of installed addon folders under \`Interface\AddOns\`.

It intentionally **does not** collect file contents, settings, account folders inside \`WTF\`, addon SavedVariables, character names, passwords, realmlist contents, or machine-specific installation paths.

### What if it does not run?

Open PowerShell and use the script directly, substituting your own two paths:

\`\`\`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\Naxxramas-Client-Setup\tools\Inspect-Client.ps1" -ClientPath "C:\Path\To\Your\World of Warcraft"
\`\`\`

The bypass flag applies to that PowerShell process only; inspect scripts before running them. The script does not change your game's files.

## What happens after the inventory?

We will identify permitted custom assets and create an installer manifest. The installer must:

- Check that a compatible 3.3.5a installation is selected.
- Offer a separate installation copy rather than overwriting the player's only client.
- Back up any overwritten configuration or addon files.
- Make changes only after explicit confirmation.
- Support rollback/uninstall using the installation manifest.
- Never install or bundle copyrighted game files without redistribution permission.

**There is no installer yet.** Do not treat the inventory scripts as an installation package.
