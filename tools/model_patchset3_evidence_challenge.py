#!/usr/bin/env python3
"""Model claimed evidence challenge lifecycle in memory only.

This is NOT an issuer, signer, credential store, fresh clock, monotonic counter
or protected observer. It consumes caller-authored JSON metadata (never game
files) and does not create, sign, persist or authenticate any challenge.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

import plan_patchset3_manual_qa as planner
import review_patch_update_proposal as proposal
import review_public_release_drift as drift
import review_patchset3_manual_record as record

KIND = "synthetic_patchset3_caller_authored_challenge_timeline"
DIGEST = re.compile(r"[0-9a-f]{64}\Z", re.ASCII)
IDENTITY = re.compile(r"[A-Za-z0-9_-]{8,40}\Z", re.ASCII)
MIN_CLOCK = 1_700_000_000
MAX_CLOCK = 2_200_000_000
MAX_EVENTS = 8
MAX_BYTES = 16 * 1024
BASE_KEYS = {"schema_version", "kind", "plan_sha256", "fixture_scope",
             "authority_epoch_claim", "events"}
EVENT_KEYS = {
    "issue": {"action", "at", "actor", "challenge_id", "expires_at"},
    "submit": {"action", "at", "actor", "challenge_id", "plan_sha256", "bundle_claim_sha256"},
    "review": {"action", "at", "actor", "challenge_id", "verdict"},
    "consume": {"action", "at", "actor", "challenge_id"},
    "revoke": {"action", "at", "actor", "challenge_id"},
}
VERDICTS = {"claims_consistent", "claims_disputed"}


class Refusal(ValueError):
    """Only fixed public refusal codes (no actual identifiers or hashes)."""


def _integer(value: object, low: int, high: int) -> bool:
    return type(value) is int and low <= value <= high


def _identifier(value: object) -> bool:
    return type(value) is str and IDENTITY.fullmatch(value) is not None


def _sha(value: object) -> bool:
    return type(value) is str and DIGEST.fullmatch(value) is not None


def simulate(timeline: object, plan: dict) -> dict:
    """Classify chronological *claims*, never generate authority or consent."""
    if type(timeline) is not dict or set(timeline) != BASE_KEYS:
        raise Refusal("invalid_claimed_timeline_schema")
    if (type(timeline["schema_version"]) is not int or timeline["schema_version"] != 1 or
        timeline["kind"] != KIND or
        timeline["fixture_scope"] != "disposable_335a_enUS_source_only" or
        not _integer(timeline["authority_epoch_claim"], 1, 1_000_000) or
        not _sha(timeline["plan_sha256"]) or
        timeline["plan_sha256"] != record.fingerprint(plan)):
        raise Refusal("untrusted_plan_scope_or_epoch_claim")
    events = timeline["events"]
    if type(events) is not list or not 1 <= len(events) <= MAX_EVENTS:
        raise Refusal("missing_or_unbounded_challenge_events")

    phase = "not_issued"
    previous_time = None
    claimed_nonce = None
    issuer = None
    tester = None
    reviewer = None
    expiry = None
    event_labels = []
    for entry in events:
        if type(entry) is not dict or type(entry.get("action")) is not str:
            raise Refusal("invalid_event_structure")
        action = entry["action"]
        if action not in EVENT_KEYS or set(entry) != EVENT_KEYS[action]:
            raise Refusal("unrecognised_challenge_event")
        time = entry["at"]
        if (not _integer(time, MIN_CLOCK, MAX_CLOCK) or
            (previous_time is not None and time < previous_time)):
            raise Refusal("claimed_clock_rollback_or_invalid_time")
        previous_time = time
        if not _identifier(entry["actor"]) or not _identifier(entry["challenge_id"]):
            raise Refusal("unsafe_or_missing_claimed_actor_or_challenge")

        if action == "issue":
            if phase != "not_issued":
                raise Refusal("duplicate_or_replayed_challenge_issue")
            expiry = entry["expires_at"]
            if not _integer(expiry, MIN_CLOCK, MAX_CLOCK) or not 1 <= expiry - time <= 3600:
                raise Refusal("invalid_claimed_challenge_lifetime")
            issuer = entry["actor"]
            claimed_nonce = entry["challenge_id"]
            phase = "issued"
        else:
            if phase == "not_issued" or entry["challenge_id"] != claimed_nonce:
                raise Refusal("missing_or_foreign_challenge")
            if expiry is None or time > expiry:
                raise Refusal("expired_claimed_challenge")
            if action == "submit":
                if phase != "issued":
                    raise Refusal("duplicate_or_out_of_order_submission")
                if (entry["actor"] == issuer or
                    entry["plan_sha256"] != timeline["plan_sha256"] or
                    not _sha(entry["bundle_claim_sha256"]) or
                    entry["bundle_claim_sha256"] == "0" * 64):
                    raise Refusal("tester_separation_or_bundle_claim_invalid")
                tester = entry["actor"]
                phase = "submitted"
            elif action == "review":
                if phase != "submitted":
                    raise Refusal("review_out_of_order_or_replayed")
                if (entry["actor"] in (issuer, tester) or
                    type(entry["verdict"]) is not str or entry["verdict"] not in VERDICTS):
                    raise Refusal("reviewer_separation_or_claim_invalid")
                reviewer = entry["actor"]
                phase = "reviewed_consistent" if entry["verdict"] == "claims_consistent" else "reviewed_disputed"
            elif action == "consume":
                if phase != "reviewed_consistent":
                    raise Refusal("consume_out_of_order_or_replayed")
                if entry["actor"] != issuer:
                    raise Refusal("claimed_issuer_not_consistent")
                phase = "consumed"
            elif action == "revoke":
                if phase not in ("issued", "submitted", "reviewed_consistent", "reviewed_disputed"):
                    raise Refusal("revoke_out_of_order_or_replayed")
                if entry["actor"] != issuer:
                    raise Refusal("claimed_issuer_not_consistent")
                phase = "revoked"
        event_labels.append(action)

    return {
        "kind": "patchset3_claimed_challenge_lifecycle_review",
        "status": "SIMULATED_CLAIMS_CONSISTENT_NOT_AUTHENTICATED"
                  if phase == "consumed" else "SIMULATED_INCOMPLETE_OR_DISPUTED_CLAIMS_NOT_AUTHENTICATED",
        "phase": phase,
        "event_count": len(events),
        "public_event_types": event_labels,
        "claimed_roles_separated_by_labels": bool(issuer and tester and reviewer and
                                                   len({issuer, tester, reviewer}) == 3),
        "claimed_authority_epoch_is_trusted": False,
        "claimed_clock_is_trusted": False,
        "challenge_nonce_independently_issued": False,
        "reviewer_or_tester_identity_authenticated": False,
        "signature_or_protected_key_verified": False,
        "external_monotonic_consumption_record_checked": False,
        "coherent_replay_prevented": False,
        "actual_bundle_bytes_verified": False,
        "actual_gameplay_or_accessibility_observed": False,
        "source_provenance_or_rights_cleared": False,
        "real_client_or_wtf_read_or_modified": False,
        "real_backup_or_recovery_performed": False,
        "patchset_or_manifest_written": False,
        "installation_authorised": False,
        "redistribution_authorised": False,
        "public_release_authorised": False,
        "private_actor_nonce_hash_or_time_disclosed": False,
        "limitations": "All roles, clocks, nonces, bundles, epochs and events are caller-authored claims. Coherent replay or identity spoofing cannot be rejected without an external protected authority.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Model untrusted evidence challenge order, without issuing credentials")
    parser.add_argument("--proposal", type=Path, required=True)
    parser.add_argument("--release-snapshot", type=Path, required=True)
    parser.add_argument("--timeline", type=Path, required=True)
    args = parser.parse_args()
    try:
        plan = planner.make_plan(proposal._load(args.proposal), proposal._load(args.release_snapshot))
        timeline = drift._decode(proposal._read_bytes(args.timeline, MAX_BYTES))
        result = simulate(timeline, plan)
    except (Refusal, proposal.Refusal, drift.Refusal, OSError) as err:
        label = str(err) if isinstance(err, (Refusal, proposal.Refusal, drift.Refusal)) else "unreadable_fixture"
        print("BLOCKED: " + label, file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
