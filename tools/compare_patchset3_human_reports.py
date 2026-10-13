#!/usr/bin/env python3
"""Compare TWO human self-reports against one plan; NO authentic verification.

This is a mismatch detector, not an independent observer or trust authority.
Two matching reports can be fabricated, copied, backdated or replayed.
No game, MPQ, client/WTF, backup, install, network or source update I/O.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import plan_patchset3_manual_qa as planner
import review_patch_update_proposal as proposal
import review_public_release_drift as drift
import review_patchset3_manual_record as records

RESULT_KIND = "patchset3_two_untrusted_reports_discrepancy_review"
CASES = ("base", "u", "j", "j-u", "c", "c-u", "j-c", "j-c-u")


def review(report_a: object, report_b: object, plan: dict) -> dict:
    """Fail closed on invalid inputs; compare public IDs/statuses only."""
    # Do not compare raw, caller-controlled records before each independently
    # passes the full existing schema/check/status/plan binding validation.
    summary_a = records.review_record(report_a, plan)
    summary_b = records.review_record(report_b, plan)

    matching = []
    discrepant = []
    details = []
    count_checks_differ = 0
    count_issues_differ = 0
    for idx, expected in enumerate(plan["scenarios"] + plan["negative_selection_scenarios"]):
        negative = idx >= len(plan["scenarios"])
        key = "negative_selection_scenarios" if negative else "valid_scenarios"
        j = idx - len(plan["scenarios"]) if negative else idx
        a, b = report_a[key][j], report_b[key][j]
        ident = expected["case_id"]
        unequal_checks = []
        if not negative:
            for aa, bb in zip(a["checks"], b["checks"]):
                if aa["status"] != bb["status"]:
                    unequal_checks.append(aa["check_id"])
        count_checks_differ += len(unequal_checks)
        issues_disagree = a["issue_codes"] != b["issue_codes"]
        if issues_disagree:
            count_issues_differ += 1
        outcomes_disagree = a["outcome"] != b["outcome"]
        if outcomes_disagree or unequal_checks or issues_disagree:
            discrepant.append(ident)
            details.append({
                "case_id": ident,
                "outcomes_disagree": outcomes_disagree,
                "discrepant_check_ids": unequal_checks,
                "issue_classifications_disagree": issues_disagree,
            })
        else:
            matching.append(ident)
    if len(matching) + len(discrepant) != 8:
        # Defensive invariant independent of caller-supplied lengths.
        raise records.Refusal("incomplete_case_comparison")

    # Both records could have been authored by the same party. Identical
    # canonical bytes are a *strong warning*, but different bytes do NOT
    # establish two people, separate machines, or independent custody.
    identical = records._json_bytes(report_a) == records._json_bytes(report_b)
    observed_a = 8 - summary_a["self_reported_counts"]["not_tested"]
    observed_b = 8 - summary_b["self_reported_counts"]["not_tested"]
    if identical:
        status = "IDENTICAL_RECORD_CONTENT_NOT_INDEPENDENT_EVIDENCE"
    elif discrepant:
        status = "UNTRUSTED_REPORT_DISCREPANCIES_REQUIRE_MANUAL_REVIEW"
    elif not observed_a or not observed_b:
        status = "NO_COMPARABLE_REPORTED_TEST_EXECUTION"
    else:
        status = "MATCHING_UNTRUSTED_REPORTS_NOT_INDEPENDENTLY_VERIFIED"
    return {
        "kind": RESULT_KIND,
        "schema_version": 1,
        "status": status,
        "scenario_count": 8,
        "matching_case_ids": matching,
        "discrepant_case_ids": discrepant,
        "public_discrepancies": details,
        "discrepant_check_count": count_checks_differ,
        "issue_classification_disagreement_count": count_issues_differ,
        "report_a_self_reported_counts": summary_a["self_reported_counts"],
        "report_b_self_reported_counts": summary_b["self_reported_counts"],
        "identical_record_content": identical,
        "both_reports_may_have_same_author": True,
        "reporter_identity_authentication_performed": False,
        "independent_test_custody_verified": False,
        "physical_client_or_mpq_evidence_examined": False,
        "release_asset_rights_cleared": False,
        "discrepancies_adjudicated": False,
        "all_game_tests_independently_verified": False,
        "trusted_independent_observer_present": False,
        "tamper_or_replay_proof_established": False,
        "patchset_or_manifest_written": False,
        "client_or_wtf_read_or_modified": False,
        "backup_or_recovery_executed": False,
        "installation_authorised": False,
        "redistribution_authorised": False,
        "public_release_authorised": False,
        "private_report_dates_paths_hashes_or_identity_emitted": False,
        "limitations": "Untrusted caller-authored reports; agreement does not prove distinct observers, authentic gameplay, independent test environment, source rights or approval.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare two local patchset-0003 QA self-reports without authenticating either")
    parser.add_argument("--proposal", required=True, type=Path)
    parser.add_argument("--release-snapshot", required=True, type=Path)
    parser.add_argument("--report-a", required=True, type=Path)
    parser.add_argument("--report-b", required=True, type=Path)
    args = parser.parse_args()
    try:
        plan = planner.make_plan(proposal._load(args.proposal),
                                 proposal._load(args.release_snapshot))
        result = review(records._read_record(args.report_a),
                        records._read_record(args.report_b), plan)
    except (records.Refusal, proposal.Refusal, drift.Refusal) as exc:
        print("BLOCKED: " + str(exc), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, ensure_ascii=True))
    # Discrepancies/identical content cannot be misread as clean comparison
    # by an unattended command runner. No positive status ever authorises use.
    return 3 if result["status"] in (
        "IDENTICAL_RECORD_CONTENT_NOT_INDEPENDENT_EVIDENCE",
        "UNTRUSTED_REPORT_DISCREPANCIES_REQUIRE_MANUAL_REVIEW") else 0


if __name__ == "__main__":
    sys.exit(main())
