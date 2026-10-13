# Patchset-0003 — Genuine Evidence Trust Model and Simulated Challenge Lifecycle

**Status: architecture and purely in-memory synthetic claim tests. There is NO credential issuer, signing key, evidence capture, trusted time source, protected authority, game test, installer, or independent observer in this feature.**

This document follows the source-only [fake evidence custody reviewer](PATCHSET3-SYNTHETIC-EVIDENCE-CUSTODY.md) and [two untrusted QA report comparison](PATCHSET3-TWO-REPORT-REVIEW.md). Those tools demonstrate byte consistency and disagreement detection. Neither demonstrates that any genuine WoW test occurred or that a separate human reviewed the results.

## Threat boundary: three separate trust domains

| Domain | Proposed responsibility | Current reality |
| --- | --- | --- |
| Tester's disposable client and capture | Independently establish WoW 3.3.5a build 12340/enUS, actual V/Z/optional bytes and capture only authorised evidence | Not implemented; test records are self-reports |
| Independent reviewer | Examine actual captured gameplay, reject C+J and verify the expected checks, separate from the tester | Not implemented; actor labels are not identities |
| External challenge/consumption authority | Generate unpredictable one-use nonces, bind verified plan/client/asset references, enforce expiry/revocation and protected consumed state | Not implemented; local copied JSON can replay its own epoch/nonce/event history |

A GitHub release page, human-record date, local SHA-256, file marker, copied report, or two different-looking actor labels **cannot** substitute for one of these domains. A coherent attacker can rewrite or replay all material they control. DPAPI CurrentUser alone also does not protect against same-user compromise or restore an independently monotonic history; see [Trust Continuity Review](TRUST-CONTINUITY-REVIEW.md) and [Journal Authority](JOURNAL-AUTHORITY.md).

## Executable *negative* trust model

`tools/model_patchset3_evidence_challenge.py` accepts one small **caller-written** JSON timeline via `--timeline` along with the existing proposal and release-metadata fixture arguments. It independently regenerates the hypothetical patchset-0003 plan and refuses invalid plan bindings or unsafe schemas.

The in-memory event state machine is:

```text
not_issued → issued → submitted → reviewed_consistent → consumed
                                      ↘ reviewed_disputed
               ↘ revoked              ↖ no consumption
```

The **only** allowed event verbs are `issue`, `submit`, `review`, `consume` and `revoke`. The input is bounded, uses fixed ASCII identifiers (not paths/names), finite integer Unix timestamp *claims*, lowercase 64-digit SHA-256 *claims*, and strict field sets. An issue must claim a lifetime from 1 second to 1 hour. Submit must claim to bind the exact regenerated plan and a nonzero bundle digest. Review must claim an actor ID distinct from issuer/tester; consume must claim the issuer ID and follow a consistent review. Wrong order, duplicate event, mismatched challenge, old plan, expiry, decreasing time, replay within the same timeline, unauthorised claimed role or attempt to consume a disputed/revoked challenge are all refused.

**This does not prove a clock was correct, an issuer actually generated a nonce, a claimed actor is a human, a digest matches any real artifact, or a key/signature exists.** The integer epoch and event history are supplied by the same untrusted author as the rest of the JSON. The model reports `SIMULATED_CLAIMS_CONSISTENT_NOT_AUTHENTICATED` after a complete consistent event sequence, or an incomplete/disputed classification; it never returns authenticated, approved or a verified gameplay result.

### Critical replay experiment

The tests copy an entire consistent event timeline into a second synthetic instance. **Both yield the same consistent classification**. Changing its claimed authority epoch from seven back to one also passes the purely internal checks when no separately held latest epoch exists.

This demonstrates exactly why a local challenge JSON cannot enforce true single-use, revocation freshness, or independent replay protection. A future protected authority would need to refuse the replay using evidence **outside** the folder and **outside** the control of the party replaying it.

## Run the source-only tests

In the checked-out repository with Python 3.12:

```powershell
python -m unittest discover -s tests -p test_patchset3_claimed_challenge.py -v
```

The test suite creates a small, synthetic timeline in memory and only uses a temporary file for a CLI refusal/privacy test. No MPQs, screenshots, account/WTF files, installer or real credentials are opened. [Windows/Linux CI](../.github/workflows/patchset3-evidence-trust-model.yml) additionally runs the previous synthetic evidence-tampering and replay regressions.

The CLI is only for inspecting **already authored disposable JSON fixtures**. It never issues credentials, saves or consumes a challenge in a protected database, contacts a server, accesses real test media or writes any player file. Errors display only fixed refusal codes; successful outputs contain public event types, phase and counts, but no claimed actor identifiers, nonces, timestamps, actual bundle hashes or user paths.

## Acceptance requirements for a genuine future implementation

1. **Owner-approved test scope and privacy:** use a legally permissible separate client with permission to capture only the necessary visuals/audio; keep any real screenshot, account label, server address or voice/chat out of public source/CI. Decide retention, who may inspect it and how the owner revokes sharing.
2. **Verifiable client baseline:** establish independently authorised source of original game/client bytes, release-asset and DBC fingerprints, correct V/Z requirements and six valid optional combinations. Matching GitHub metadata does not independently rehash a real file or clear rights.
3. **Protected challenge issuance:** generate high-entropy unpredictable nonces through reviewed software under separately protected authority. Bind to a pre-agreed plan, client/asset baseline, permitted capture scope and expiration. Prevent an attacker from self-issuing or replacing the protected record.
4. **Distinct authorised tester and reviewer:** authenticate accounts/roles through a trustworthy identity mechanism with appropriate access controls. A second JSON file, different labels, or even two signatures do not by themselves establish truthful or independent gameplay.
5. **Independent monotonic consumption/freshness:** protect the latest issued/consumed challenge ID, revocations and trust epoch in a failure domain outside the evidence bundle. Review time source, race conditions, key compromise, migration and disaster recovery. Define what to do when the authority is down: **manual review, no automatic approval**.
6. **Actual evidence and adjudication:** independently inspect requested game behaviour for all six valid J/C/U combinations and both forbidden C+J selections, including J+U texture overlaps, while documenting any failed or blocked cases. Separate the observer's decision from legal rights, client-write permission and future release.
7. **Separate release gates:** independently complete legal/third-party asset-rights review, protected originals plus full all-account WTF backups with demonstrated restore/crash durability, authenticated owner consent, and physical Windows 100/125/150/200% DPI, High Contrast, keyboard and screen-reader acceptance.

These are **design acceptance criteria**, not steps secretly performed by the source-only checker. Their implementation must undergo another independent security/rights review and cannot be granted by editing a JSON status to `true`.

**Every current output has** `installation_authorised=false`, `redistribution_authorised=false`, `public_release_authorised=false`, and `coherent_replay_prevented=false`. No new real patchset-0003, installer, backup or live gameplay test has been introduced.

## Follow-on: marked disposable client patch preflight remains untrusted

The [read-only test-copy patch preflight](DISPOSABLE-CLIENT-READONLY-PREFLIGHT.md) verifies locally opened V/Z/J/C/U file sizes and SHA-256 against frozen source pins **only when explicitly pointed at a caller-marked test root**. It rejects extra optional MPQs contaminating a declared scenario and never accesses WTF, account records or realmlist. Its marker can be forged; a matching hash is not authenticated source provenance, a confirmed build 12340, lawful media, independent observer, full backup or actual gameplay evidence. Production use is not scheduled or included in the player package.
