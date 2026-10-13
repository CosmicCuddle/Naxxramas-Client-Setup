#!/usr/bin/env python3
"""Build an EMPTY manual QA record or review an owner-authored record, read-only.

All checked game/test observations are UNTRUSTED SELF-REPORTS. There is no
authentication, installation, game access, player path, backup, or release grant.
Only prints JSON; the operator decides whether/where to save the template.
"""
from __future__ import annotations

import argparse
from datetime import date
import hashlib
import json
from pathlib import Path
import sys

import plan_patchset3_manual_qa as planner
import review_patch_update_proposal as proposals
import review_public_release_drift as drift

STATUSES = frozenset(("NOT_TESTED", "PASS", "FAIL", "BLOCKED"))
ISSUES = frozenset((
    "client_startup_failure", "realm_or_character_entry_failure",
    "visual_audio_mismatch", "loading_overlap_problem",
    "unexpected_file_change", "mutex_did_not_reject",
    "other_observed_failure", "no_test_environment",
    "no_protected_backup", "rights_unresolved",
    "missing_required_patch", "incomplete_checks", "other_blocker",
))
FAIL_ISSUES = frozenset((
    "client_startup_failure", "realm_or_character_entry_failure",
    "visual_audio_mismatch", "loading_overlap_problem",
    "unexpected_file_change", "mutex_did_not_reject",
    "other_observed_failure",
))
BLOCK_ISSUES = ISSUES - FAIL_ISSUES
MAX_RECORD = 64 * 1024
META_KEYS = frozenset((
    "schema_version", "kind", "plan_sha256", "reported_utc_date",
    "observed_client_build", "observed_locale",
    "reported_disposable_test_environment", "reported_human_observation",
    "valid_scenarios", "negative_selection_scenarios",
))
VALID_KEYS = frozenset(("case_id", "outcome", "checks", "issue_codes"))
CHECK_KEYS = frozenset(("check_id", "status"))
NEGATIVE_KEYS = frozenset(("case_id", "outcome", "issue_codes"))


class Refusal(ValueError):
    """Constant-only error codes; never include private paths or record text."""


def _json_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True, allow_nan=False).encode("ascii")


def fingerprint(plan: dict) -> str:
    # This binds against accidental plan/reference changes, NOT malicious
    # coordinated rewriting, signed provenance, or independently held state.
    return hashlib.sha256(_json_bytes(plan)).hexdigest()


def template(plan: dict) -> dict:
    return {
        "schema_version": 1,
        "kind": "self_reported_patchset3_manual_observations_NOT_APPROVAL",
        "plan_sha256": fingerprint(plan),
        "reported_utc_date": None,
        "observed_client_build": None,
        "observed_locale": None,
        "reported_disposable_test_environment": False,
        "reported_human_observation": False,
        "valid_scenarios": [{
            "case_id": x["case_id"], "outcome": "NOT_TESTED",
            "checks": [{"check_id": check, "status": "NOT_TESTED"}
                       for check in x["checks"]],
            "issue_codes": [],
        } for x in plan["scenarios"]],
        "negative_selection_scenarios": [{
            "case_id": x["case_id"], "outcome": "NOT_TESTED",
            "issue_codes": [],
        } for x in plan["negative_selection_scenarios"]],
    }


def _date(value: object) -> bool:
    if type(value) is not str or len(value) != 10:
        return False
    try:
        return date.fromisoformat(value).isoformat() == value
    except ValueError:
        return False


def _issues(values: object, outcome: str) -> None:
    if (type(values) is not list or len(values) > 3 or
        any(type(x) is not str or x not in ISSUES for x in values) or
        len(set(values)) != len(values) or values != sorted(values)):
        raise Refusal("unknown_or_ambiguous_issue_codes")
    if outcome in ("PASS", "NOT_TESTED") and values:
        raise Refusal("issue_codes_contradict_outcome")
    if outcome == "FAIL" and not values or outcome == "BLOCKED" and not values:
        raise Refusal("missing_failure_or_blocker_code")
    if outcome == "FAIL" and not set(values) <= FAIL_ISSUES:
        raise Refusal("fail_requires_failure_issue_code")
    if outcome == "BLOCKED" and not set(values) <= BLOCK_ISSUES:
        raise Refusal("blocked_requires_blocker_issue_code")


def _exact_case_list(values: object, expected: list, negative: bool) -> list:
    if type(values) is not list or len(values) != len(expected):
        raise Refusal("missing_or_extra_scenario")
    reports = []
    for item, canonical in zip(values, expected):
        keys = NEGATIVE_KEYS if negative else VALID_KEYS
        if type(item) is not dict or set(item) != keys:
            raise Refusal("unrecognised_scenario_schema")
        if item["case_id"] != canonical["case_id"] or type(item["case_id"]) is not str:
            raise Refusal("scenario_identity_or_order_mismatch")
        outcome = item["outcome"]
        if type(outcome) is not str or outcome not in STATUSES:
            raise Refusal("invalid_scenario_outcome")
        _issues(item["issue_codes"], outcome)
        if not negative:
            checks = item["checks"]
            needed = canonical["checks"]
            if type(checks) is not list or len(checks) != len(needed):
                raise Refusal("incomplete_scenario_checks")
            values_checked = []
            for check, expected_id in zip(checks, needed):
                if (type(check) is not dict or set(check) != CHECK_KEYS or
                    check["check_id"] != expected_id or
                    type(check["check_id"]) is not str or
                    type(check["status"]) is not str or
                    check["status"] not in STATUSES):
                    raise Refusal("unexpected_scenario_check")
                values_checked.append(check["status"])
            if outcome == "NOT_TESTED" and any(x != "NOT_TESTED" for x in values_checked):
                raise Refusal("not_tested_contains_observation")
            if outcome == "PASS" and any(x != "PASS" for x in values_checked):
                raise Refusal("pass_requires_every_check_pass")
            if outcome == "FAIL" and "FAIL" not in values_checked:
                raise Refusal("fail_requires_failed_check")
            if outcome == "BLOCKED" and (
                "FAIL" in values_checked or
                not any(x in ("BLOCKED", "NOT_TESTED") for x in values_checked)
            ):
                raise Refusal("blocked_requires_incomplete_or_blocked_check")
        reports.append({"case_id": canonical["case_id"], "self_reported_outcome": outcome})
    return reports


def review_record(record: object, plan: dict) -> dict:
    if type(record) is not dict or set(record) != META_KEYS:
        raise Refusal("unrecognised_record_schema")
    if (type(record["schema_version"]) is not int or record["schema_version"] != 1 or
        record["kind"] != "self_reported_patchset3_manual_observations_NOT_APPROVAL" or
        type(record["plan_sha256"]) is not str or
        record["plan_sha256"] != fingerprint(plan)):
        raise Refusal("record_plan_binding_invalid_or_stale")
    if (type(record["reported_disposable_test_environment"]) is not bool or
        type(record["reported_human_observation"]) is not bool):
        raise Refusal("invalid_self_report_attestations")
    valid = _exact_case_list(record["valid_scenarios"], plan["scenarios"], False)
    negatives = _exact_case_list(record["negative_selection_scenarios"],
                                 plan["negative_selection_scenarios"], True)
    combined = valid + negatives
    observed = sum(x["self_reported_outcome"] != "NOT_TESTED" for x in combined)
    if observed:
        if (record["observed_client_build"] != 12340 or
            type(record["observed_client_build"]) is not int or
            record["observed_locale"] != "enUS" or
            type(record["observed_locale"]) is not str or
            not record["reported_disposable_test_environment"] or
            not record["reported_human_observation"] or
            not _date(record["reported_utc_date"])):
            raise Refusal("observation_requires_explicit_disposable_335a_context")
    else:
        if (record["reported_utc_date"] is not None or
            record["observed_client_build"] is not None or
            record["observed_locale"] is not None or
            record["reported_disposable_test_environment"] or
            record["reported_human_observation"]):
            raise Refusal("blank_record_must_not_claim_observation")
    counts = {status.lower(): sum(x["self_reported_outcome"] == status for x in combined)
              for status in ("PASS", "FAIL", "BLOCKED", "NOT_TESTED")}
    return {
        "kind": "patchset3_manual_qa_self_report_consistency_review",
        "status": "UNTRUSTED_SELF_REPORT_ONLY_MANUAL_VERIFICATION_REQUIRED",
        "case_count": len(combined),
        "self_reported_counts": counts,
        "valid_scenarios": valid,
        "negative_selection_scenarios": negatives,
        "claimed_disposable_335a_context_present": bool(observed),
        "all_cases_independently_verified": False,
        "human_identity_or_consent_authenticated": False,
        "game_or_mpq_files_read": False,
        "game_or_mpq_files_written": False,
        "case_claims_independently_corrobated": False,
        "backup_or_recovery_executed": False,
        "manifest_or_patchset_written": False,
        "installation_authorised": False,
        "redistribution_authorised": False,
        "public_release_authorised": False,
        "private_notes_identifiers_paths_hashes_and_dates_emitted": False,
        "limitations": "Internally consistent human self-reports are not independently verified test evidence or approval. The plan fingerprint is locally reproducible, not signed or rollback-resistant.",
    }


def _read_record(path: Path) -> object:
    # Reuse strict size, no-symlink, duplicate-key, finite JSON protection.
    return drift._decode(proposals._read_bytes(path, MAX_RECORD))


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate blank or review self-reported manual patchset3 QA records (no writes)")
    parser.add_argument("--proposal", type=Path, required=True)
    parser.add_argument("--release-snapshot", type=Path, required=True)
    choice = parser.add_mutually_exclusive_group(required=True)
    choice.add_argument("--print-template", action="store_true")
    choice.add_argument("--record", type=Path)
    args = parser.parse_args()
    try:
        plan = planner.make_plan(proposals._load(args.proposal),
                                 proposals._load(args.release_snapshot))
        result = (template(plan) if args.print_template
                  else review_record(_read_record(args.record), plan))
    except (Refusal, proposals.Refusal, drift.Refusal) as exc:
        print("BLOCKED: " + str(exc), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
