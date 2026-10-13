# Public GitHub Release Drift — Read-only Review

**Evidence checked 13 October 2026. Status: published metadata aligned with current frozen pins; NOT approved for installation or redistribution.**

The [official main patch releases](https://github.com/CosmicCuddle/Naxxramas-Server-Patches/releases) and [N Addon Collection releases](https://github.com/CosmicCuddle/N-Addon-Collection/releases) still list:

| Resource | Current observed public source | Pinned reference | Observation |
| --- | --- | --- | --- |
| Required Patch-V | `v1.0.6.8.4` | `v1.0.6.8.4` / 450,631,505 B | Published tag, SHA-256 and size match |
| Required Patch-Z | `v1.0.6.7` | `v1.0.6.7` / 47,337,608 B | Older **intentional** required asset; no replacement in newest V-only release |
| Optional Patch-J | `optional-v1.0` | Same / 5,739,890 B | Published metadata matches |
| Optional Patch-C | `optional-v1.0` | Same / 26,753,640 B | Published metadata matches |
| Optional Patch-U | `optional-v1.0` | Same / 11,050,502 B | Published metadata matches |
| N Addon Suite | `v2.0.0` | Same / 26,762,217 B | Published metadata matches |

This is an observation of the **public release listing** at one point in time, not a new audit of binary MPQ payloads. The previous independent real v2.0.0 addon ZIP SHA-256/CRC checks remain recorded elsewhere. A matching public checksum does **not** prove copyright clearance, secure publisher identity, independent backup or in-game compatibility.

## How a future release is noticed

The source-only `tools/review_public_release_drift.py` compares a fresh GitHub public release *metadata listing* to the immutable reference files `config/patch-versions/patchset-0002.json`, `config/optional-content.json`, and `docs/release-rights-evidence-v1.json`.

- **Required V and Z are tracked independently:** the newest main release may update only V. The last published Z from an older main release remains valid until a new Z asset is published.
- **J, C and U are tracked independently:** an updated C-only optional release does not imply J/U were updated. C/J remain mutually exclusive *inside the existing planner*; U remains independently selectable.
- **The addon suite is treated separately:** the latest published stable vN.N.N suite is compared to the pinned `v2.0.0` archive metadata. The reviewer does not assume a future ZIP has the same five installed folder structure without another archive/source review.
- **Prereleases and drafts are not silent updates.** A published stable asset with changed bytes under the *same tag*, a new tag or missing required pinned asset gets `manual_reference_review_required`.
- **Untrustworthy or incomplete metadata fails closed:** unexpected shapes, duplicate assets, missing SHA-256, unsafe JSON, oversized files, missing stable releases, or API failure cannot be treated as a successful match.

The fixed [frozen test fixture](../tests/fixtures/public-release-metadata-v1.json) stores a **small, real public release metadata snapshot**; running unit tests against it is *not* a live network check. All observed values are public release tag metadata; real player files are never read, scanned, uploaded or changed.

## Run a live check only when requested

Open the repository's **Actions → Read-only public release reference drift review → Run workflow**. The manual run performs the Windows/Linux fixture tests, then a **live metadata-only GitHub API check** on Ubuntu.

Alternatively a developer with Python 3.12 and a trusted source checkout can run:

```powershell
python .\tools\review_public_release_drift.py --live
```

Only two fixed `api.github.com/repos/CosmicCuddle/...` release-list API endpoints can be contacted. No input URL, GitHub token, MPQ path or WoW client folder is accepted. The tool fetches at most 3 MiB of public JSON per response and prints a small classification report without local file paths or complete checksums.

**Exit meanings:** `0` = public source metadata matches frozen reference (still NOT approval); `2` = unsafe/unavailable metadata, refuse conclusion; `3` = new/changed/missing public release reference requiring human review. A red manually run workflow on exit `3` means **review needed**, not an authorised automatic upgrade.

Do **not** automatically change `config/client-patches.json`, overwrite old `patchset-0001/0002`, download or replace V/Z/J/C/U, or publish a new bundle when the tool reports drift. Verify new GitHub release content and legal rights, test compatibility, collect owner's checksum/approval and create a **new immutable** `patchset-0003` or later review in a separate PR. The frozen historical patchset remains valid history.

## Scope and outstanding release blockers

This observer cannot authenticate the upstream GitHub owner against a protected independent trust root and does not rehash full released MPQ files; GitHub release metadata may be changed by a person with upstream access. It does not perform downloads of **binary assets**, install addons, create backups, resolve copyright/licence requirements, pass human physical DPI/keyboard/High Contrast/screen-reader tests, or approve publication. Existing authorisation flags in all setup policies remain false. **The setup remains Review Only.**
