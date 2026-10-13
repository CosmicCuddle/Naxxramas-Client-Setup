# Patchset-0003 — Synthetic Evidence Integrity and Custody Review

**Status:** developer-only, offline, **synthetic ASCII evidence**. This is NOT an actual game capture, independent observation, user authentication, original backup, patch verification or release approval.

Previous milestones could produce a plan, check one self-reported result, and identify differences between two untrusted reports. This milestone exercises the **integrity and file-handling mechanics** that a genuinely independent evidence handoff would eventually need, while refusing to accept or inspect actual player media.

## What the reviewer actually reads

`tools/review_synthetic_patchset3_evidence.py` only accepts an **explicitly marked disposable directory** with exactly:

```text
synthetic-bundle/
  .naxx-patchset3-synthetic-evidence-only
  report.json
  index.json
  evidence/
    base--game_starts_and_login_and_realm_selection_work.txt
    ... (only corresponding fake checked observations)
```

The marker must have the exact bytes `NAXX_SYNTHETIC_PATCHSET3_EVIDENCE_V1\n`. This is **a local safety guard, not trust or authorisation**; a caller can reproduce it. `report.json` must pass the same strict, plan-bound single-human-record validator as PR #74. `index.json` holds the canonical SHA-256 of the regenerated plan, canonical SHA-256 of that self-report, and a sorted/ordered artifact inventory. A recorded PASS/FAIL/BLOCKED **check** requires exactly one matching **fake ASCII** file; every BLOCKED valid case also requires a `case_blocker` placeholder. A completed or failed C/J mutex selection gets `selection_outcome`.

Every evidence file is limited to an exact deterministic, printable synthetic payload:

```text
SYNTHETIC PATCHSET3 EVIDENCE ONLY
case_id=base
check_id=game_starts_and_login_and_realm_selection_work
status=PASS
```

This is **deliberately not** a screenshot, gameplay log, WoW/MPQ texture, personally identifiable record, proof of a real tester or original media. Real screenshots, movie clips, player `WTF`, addons, binary MPQs and arbitrary user text **will be refused** by this development tool even if renamed to `.txt`.

## What failures mean

The reviewer refuses an absent/incorrect marker, arbitrary extra files, unsafe symlink/hardlink inputs, oversized files, unknown manifest or record fields, a mismatched plan/record digest, wrong case/check/outcome bindings, duplicate/reordered/missing files, attempts to reuse one case's digest as another case's proof, changed placeholder bytes, path traversal or any record failing the earlier strict schema. It does not follow arbitrary manifest paths; each path is derived from an expected fixed public case/check identifier.

The tool prints **only fixed public IDs, status labels and counts**; no real paths, client/user information, raw proposed hashes, report dates or private evidence content. It **never writes any file**.

The new tests create the fake directory entirely inside a disposable system temporary folder. The repository does **not** commit any supposed human PASS evidence. The tests include a coherent-copy attack where the entire index/report/marker/artifact set is replayed: byte verification succeeds again, **while every independent custody, replay-protection and installation flag stays false**.

## How to run the regression suite

From a trusted repository checkout with Python 3.12:

```powershell
python -m unittest discover -s tests -p test_synthetic_patchset3_evidence.py -v
```

The test suite creates its own synthetic files in a temporary directory and cleans them up. For CI, see **Actions → Synthetic patchset 0003 evidence custody**, which runs Windows/Linux fixture tests and earlier one/two report validators. There is **no command that captures game evidence**. The CLI `--synthetic-bundle` exists only to inspect already generated, deliberately marked fake bundles.

## What genuine independent custody would require

| Future gate | Why this source-only tool cannot fulfil it |
| --- | --- |
| Real disposable client baseline | A separately authorised, independently checked WoW 3.3.5a build 12340/enUS with appropriate V/Z and selected optional patch content |
| Authentic MPQ provenance | Independently trusted sources and real file SHA-256, not caller-controlled GitHub release metadata or an invented fixture |
| Capture evidence | Actual consented, privacy-reviewed game visual/audio/login/realm observations and safe evidence minimisation—never silently capture account details |
| Independent custody | Separate observer/reviewer authority, protected signing keys or equivalent trustworthy attestation, independently protected time/nonce and anti-replay state |
| Review of actual truth | Human examination of real gameplay, including J+U overlap and rejection of C+J, not mere checksum agreement |
| Permission and protection | Rightsholder licence review, complete original/WTF backups with crash-safe recovery, physical Windows 100/125/150/200% DPI and assistive technology acceptance, and independent owner consent |

**Crucial limitation:** even a real file with a matching SHA-256 would only establish byte agreement with a provided hash. It would not prove who captured it, when, on which client, whether it depicts the requested test, or whether it is legal to redistribute. Coordinated rewriting of index, report and artifacts can always produce another internally valid bundle. To prevent coherent replay, the trust root must be **independently protected outside the caller-controlled evidence folder**; this project has no such implemented authority.

**No real patchset-0003 is created. No WoW files, SavedVariables, client installations, automatic backups, restorations or public releases are touched or authorised.**

## Follow-on: challenge lifecycle is still only a caller's claim

See [Evidence Trust Model](PATCHSET3-EVIDENCE-TRUST-MODEL.md) for a strict *in-memory simulation* of challenge issue/submit/review/consume/revoke steps, expiry, actor-label separation and revoked or repeated claims. The test deliberately shows that **replaying the whole internally valid challenge event history and rolling back its claimed epoch can still pass** because no independently protected authority is present. It is not a live nonce issuer, identity service, signature, real evidence capture, backup or approval.
