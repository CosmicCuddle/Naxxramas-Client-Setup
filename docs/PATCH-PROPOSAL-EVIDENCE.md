# Patch Update Proposal — Read-only Evidence Review

**Status:** developer-only synthetic/source evidence gate. It does **not** install, authenticate, download, verify real game MPQ bytes, create backups, modify manifests or authorise redistribution.

## Purpose

`tools/Prepare-Patch-Update.ps1` can create a metadata-only `patch-update-proposal.json` when an owner locally inspects patch files. The resulting JSON is a **caller-controlled claim**, not proof of real game bytes, a signed release or owner approval.

New `tools/review_patch_update_proposal.py` checks the **proposal's internal consistency**, its stated prior checksums against the frozen `patchset-0002` and `config/client-patches.json` references, and **new proposed SHA-256/size values** against the per-asset latest stable published GitHub release metadata in a supplied JSON snapshot. It never reads `Wow.exe`, `Data/`, original MPQs, `WTF` or installed addons.

## Source-only review example

From a trusted **source repository checkout**, Python 3.12:

```powershell
python .\tools\review_patch_update_proposal.py --proposal .\tests\fixtures\synthetic-patch-proposal-v3.json --release-snapshot .\tests\fixtures\public-release-metadata-v1.json
```

That checked-in proposal is **purely synthetic** (hypothetical V hash `e…e`, no such genuine source asset); the release snapshot is a frozen public metadata fixture, not current live GitHub status. Expected outcome: `manual_review_required_NO_INSTALL_AUTHORITY` and the changed V is **not recognised** as the latest stable published V. No new `patchset-0003.json` file is produced.

For a genuine owner-supplied metadata-only proposal (kept private), a developer can supply its file via `--proposal`. Do not commit proposals containing unexpected private information, and **never** upload your MPQs or complete game client. To compare against newly observed public metadata, obtain a trusted JSON snapshot separately; the reviewer makes **no network connections** and does not fetch public release data itself.

## Validation and refusal rules

1. **Frozen history baseline:** the exact reviewed Git blob bytes of `patchset-0001.json` and `patchset-0002.json` are checked against fixed source pins. The current manifest must still match all five version-2 references and preserve required V/Z, C/J mutual exclusion, original-file protection and backup-required design flags. *These local source pins are not a cryptographically independent trusted history or physical backup.*
2. **Schema and freshness:** `proposal_schema_version=1`, `kind=review_only_not_published`, base revision `2`, proposed revision `3`, version `patchset-0003`, constrained UTC timestamp, note and bounded lists. A proposal from revision 1 or proposing revision 4 fails as **stale/inconsistent**, not an automatic rebasing request. Future actual patchsets must be reviewed separately.
3. **All required files:** `Data/patch-V.mpq` and `Data/patch-Z.mpq` must both be present in `files_checked`. Optional J/C/U may be absent. Paths must be exact known strings in expected order; no absolute client paths, duplicate names, unknown fields, malformed digest, Boolean-as-size or path traversal accepted.
4. **Before/after:** every `changed=true` file must truly differ from pinned size or hash, with **exactly one** corresponding `changes` entry. The before values must equal the frozen reference, and after values must equal `files_checked`; mismatched counts, unreported changes and duplicate entries fail closed.
5. **Public metadata:** each changed file is independently compared with the latest stable published asset of that name from the supplied patch-release snapshot. Because Patch-Z can remain on older `v1.0.6.7` when Patch-V receives a V-only update, Z is not inferred missing merely because a newer main release contains only V. Optional C/J/U likewise advance independently. Matching the *public metadata* only gives `changed_bytes_match_public_release_metadata_NOT_APPROVAL`, **never** permission or a verified local MPQ.
6. **Conflict warnings:** if a proposal observes both optional C and J, it reports `optional_c_j_both_present_login_mutex_requires_review`; J+U emits their known overlapping-texture warning. These are observations about claimed local presence, not remedies, deletions or installer actions.

A malformed or unsafe local proposal is rejected with a **fixed, path-free** refusal code. A structurally valid proposal always returns `manual_review_required_NO_INSTALL_AUTHORITY`, whether its changed checksum appears in published metadata or not. Output reports only public patch IDs, counts and fixed classifications, **not** account names, actual paths, user timestamps, new hashes, game file content or private directory identifiers.

## CI and acceptance boundaries

`tests/test_patch_update_proposal_evidence.py` uses only fake proposal and release fixtures; it covers old base, forged before/after, changed flags contradicting bytes, missing Z, absent optional patches, duplicate/relative paths, unknown private fields, unavailable releases, original history modified **in a disposable temporary copy**, and unchanged actual checked-in source files. Windows/Linux Python 3.12 CI also reruns the prior public release drift regression suite.

**A passing reviewer or GitHub CI check does not create an approved patch update.** Next real update still requires an owner-reviewed new immutable patchset committed separately with its manifest, verified MPQ sources, real in-game compatibility, legal asset rights, complete originals/WTF backup design, authenticated one-use consent and crash-safe recovery. Physical Windows DPI 100/125/150/200%, keyboard, High Contrast and screen-reader checks remain **NOT TESTED**.

**No game-client write, backup/restore, automatic download or public release is authorised.**
