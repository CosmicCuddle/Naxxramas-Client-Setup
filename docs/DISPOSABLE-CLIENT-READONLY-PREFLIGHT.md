# Disposable Test Client — Read-only Patch Preflight

**Status: optional developer review utility. Not a game tester, source-authentication system, installer, backup tool, approval, or redistribution clearance.** No real client has been inspected during development; CI uses fake text bytes only.

The existing `Test-Naxxramas-Client.ps1` and `Get-Core-Patch-Hashes.ps1` can inspect patch references. This additional narrower `tools/review_disposable_test_client.py` addresses one issue specific to gathering future **genuine gameplay evidence**: a test report that claims one optional-patch combination must not quietly contain another optional MPQ.

## What it checks

When deliberately invoked on an **already existing, separately prepared test copy**, the Python 3.12 reviewer:

1. Refuses to open a folder without the exact marker file `.naxx-disposable-test-client-read-only` containing `NAXX_DISPOSABLE_TEST_CLIENT_REVIEW_ONLY_V1` followed by a newline. This marker is an **opt-in safety label added by the owner**, not independent evidence of separation, permission, original-file protection or disposable identity.
2. Rechecks source-only `patchset-0001`, `patchset-0002` and `config/client-patches.json` invariants against the already merged [read-only patch proposal reviewer](PATCH-PROPOSAL-EVIDENCE.md). It does not change the pinned source bytes.
3. Reads **only five named files directly under Data**, if present: V and Z (always required), J (Vanilla login), C (TBC login), and U (optional loading screens). It compares *each existing patch* with the expected pinned SHA-256 and exact size. It never displays a raw hash or a local absolute path.
4. Checks the **physical optional selection**, not just a command-line preference. It refuses to classify a declared clean `j` scenario when C or U is physically present; similarly `c` cannot hide J, and `base` cannot hide any of J/C/U. It flags any other direct `Data/patch-*.mpq` file by **count only**; no filename is reported.
5. Rejects symlink/junction ancestry, linked patch files, unexpected filename casing, ambiguous case collisions and basic during-read file changes. It uses bounded SHA-256 streaming and never recursively scans the client.
6. Notes only whether `Wow.exe` and `Data/enUS` exist. **Neither presence proves** a genuine WoW 3.3.5a build 12340 executable, enUS game contents, licence, game compatibility, server status or absence of malware.

| Selection | Must be present | Must be absent among optional patch files |
| --- | --- | --- |
| `base` | V + Z | J, C, U |
| `u` | V + Z + U | J, C |
| `j` | V + Z + J | C, U |
| `j-u` | V + Z + J + U | C |
| `c` | V + Z + C | J, U |
| `c-u` | V + Z + C + U | J |

**J and C are never a supported combination.** When J+U are selected the tool adds the existing two-loading-texture overlap warning: those combinations still need actual human in-game testing. The scanner does not try to resolve asset or MPQ precedence, and no output means six game scenarios were actually run.

## How an owner could use it later

**Do not run it on your original working WoW client.** Only after an owner deliberately prepares a separate lawful test copy, protects the full originals and all account/realm/character `WTF` contents, and confirms the copy is disposable, they may create the exact marker file inside the test copy. This opt-in marker requirement intentionally stops accidental use on an unmarked client, but a malicious or mistaken caller can put it anywhere. The tool cannot tell a real client from a copy.

From a trusted **source** checkout, after preparing that separate test root:

```powershell
python .\tools\review_disposable_test_client.py --test-root "D:\\YourDisposableTestCopy" --selection j-u
```

The example path is only illustrative, not a folder that the tool creates. **Do not create or change the marker in your existing client.** Nothing is scanned automatically, no folder is discovered, and the script is not part of the published scripts-only player ZIP.

**Return codes:** `0` = locally selected files match *current pinned reference metadata* and no unselected optional MPQ was found (**NOT GAME VERIFIED OR APPROVED**); `3` = missing/mismatched selected file, unselected optional/extra patch, or missing executable/locale folder requiring manual review; `2` = missing/unsafe marker, linked directories/files, invalid source policy or another refusal. All reports explicitly set every installation, backup, source authentication, gameplay/accessibility verification, and public distribution flag to false.

The result displays only fixed patch IDs, fixed classifications and counts. It **never opens `WTF`, SavedVariables, account or character records, addon folders, realmlist, screenshots, logs or other MPQs**. There is no generated output file and no player information upload. As with any ordinary read of files on an operating system, races and malicious same-user/admin control cannot be completely ruled out by this utility. File hashes pinned from sources/screenshots are not authentic publisher signatures. A mere marker cannot authenticate the test copy.

## Automated checks and ongoing blockers

Windows/Linux CI creates five **tiny, explicitly fake MPQ-named text files** under temporary directories, plus a fake `Wow.exe` and `WTF` content that the scanner is instructed **never to read**. Tests cover all six legal selections, unexpected physically present optional content, both C/J conflicts, J+U overlap, invalid SHA versus equal-size bytes, missing V/Z, other patch files, symlink/hardlink attempts, casing collisions, absence of a marker, privacy and source preservation. These do **not** represent genuine MPQ verification or real gameplay.

The separate [Manual QA Plan](PATCHSET3-MANUAL-QA-PLAN.md), [Evidence Trust Model](PATCHSET3-EVIDENCE-TRUST-MODEL.md) and [Human QA Record](PATCHSET3-MANUAL-QA-RECORD.md) remain NOT TESTED with respect to real gameplay. Future acceptance additionally requires independently authorised original game-client baseline, true source provenance, protected challenge/reviewer identity and non-replayable custody, physical Windows DPI/High Contrast/keyboard/screen reader tests, legal third-party asset rights, and complete owner-original/WTF backups with crash-safe recovery and separate user consent.

**No existing player client, original MPQ, SavedVariables, patchset, game folder or public installation was changed.**
