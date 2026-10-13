#!/usr/bin/env python3
"""Developer-only plan of *unperformed* manual tests for a hypothetical patchset.

No MPQ, ZIP, installer, client, gameplay, human-accessibility or backup I/O.
A valid plan is never consent, a verified in-game result, or release permission.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import review_patch_update_proposal as proposal_review
import review_public_release_drift as drift

# Six supported combinations. Required V and Z are present in every case.
# J and C are deliberately mutually exclusive; U is independently optional.
VALID_CASES = (
    ("base", (), "standard_login_without_optional_loading_patch"),
    ("u", ("U",), "standard_login_with_u"),
    ("j", ("J",), "vanilla_login_without_u"),
    ("j-u", ("J", "U"), "vanilla_login_with_u_texture_overlap"),
    ("c", ("C",), "tbc_login_without_u"),
    ("c-u", ("C", "U"), "tbc_login_with_u"),
)
INVALID_CASES = (("j-c", ("J", "C")), ("j-c-u", ("J", "C", "U")))
SAFE_CHECK_IDS = (
    "baseline_335a_build_12340_and_enus_compatibility",
    "required_v_z_present_and_matching_reviewed_bytes",
    "game_starts_and_login_and_realm_selection_work",
    "gameplay_realm_and_character_entry_smoke",
    "no_unexpected_game_file_or_wtf_mutation",
)
GATES = (
    "independent_hash_and_size_of_real_owner_mpqs_not_performed",
    "upstream_release_publisher_or_provenance_not_authenticated",
    "patch_internal_assets_and_dbc_dependencies_not_examined",
    "copyright_and_source_rights_not_cleared",
    "full_originals_and_all_account_wtf_backup_not_verified",
    "independent_failure_domain_and_crash_durability_not_verified",
    "recovery_and_trusted_one_use_owner_consent_not_implemented",
    "physical_windows_100_125_150_200_dpi_contrast_keyboard_reader_not_tested",
    "manual_in_game_compatibility_not_tested",
    "owner_signoff_not_obtained",
)


def make_plan(proposal: object, releases: object) -> dict:
    # Delegate strict checks of frozen history, proposal before/after evidence,
    # required V/Z, optional known names and stable public release metadata.
    reviewed = proposal_review.review(proposal, releases)
    if (reviewed["status"] != "manual_review_required_NO_INSTALL_AUTHORITY" or
        reviewed["base_patchset"] != "patchset-0002" or
        reviewed["hypothetical_next_patchset"] != "patchset-0003_NOT_CREATED"):
        raise proposal_review.Refusal("unknown_patch_proposal_review_result")

    changed = [item["id"] for item in reviewed["items"] if item["changed"]]
    changed_set = set(changed)
    focus = []
    if changed_set & {"patch-v", "patch-z"}:
        focus.append("core_v_z_dbc_spell_client_asset_and_server_compatibility")
    if changed_set & {"patch-j", "patch-c"}:
        focus.append("login_glue_visual_audio_assets_and_standard_screen_reversion")
    if "patch-u" in changed_set or "patch-j" in changed_set:
        focus.append("eastern_kingdoms_kalimdor_and_widescreen_loading_art")
    if "patch-c" in changed_set:
        focus.append("tbc_login_with_and_without_u")

    cases = []
    for case_id, options, description in VALID_CASES:
        checks = list(SAFE_CHECK_IDS)
        if "J" in options:
            checks.append("vanilla_login_visuals_buttons_music_and_interaction")
        if "C" in options:
            checks.append("tbc_login_dark_portal_visuals_buttons_music_and_interaction")
        if "U" in options:
            checks.append("eastern_kingdoms_kalimdor_standard_and_widescreen_loading")
        if "J" in options and "U" in options:
            checks.append("j_u_two_overlapping_texture_paths_must_warn_and_be_checked")
        cases.append({
            "case_id": case_id,
            "required_patches": ["V", "Z"],
            "selected_optional_patches": list(options),
            "case_purpose": description,
            "checks": checks,
            "human_execution_status": "NOT_TESTED",
            "result": "NO_RESULT_RECORDED",
        })

    negatives = []
    for case_id, options in INVALID_CASES:
        negatives.append({
            "case_id": case_id,
            "attempted_optional_patches": list(options),
            "expected": "MUTUALLY_EXCLUSIVE_J_C_REFUSED_NO_FILE_WRITE",
            "human_execution_status": "NOT_TESTED",
            "result": "NO_RESULT_RECORDED",
        })

    release_evidence = {item["id"]: item["status"] for item in reviewed["items"]
                        if item["changed"]}
    return {
        "kind": "naxxramas_patchset_0003_manual_qa_plan_ONLY",
        "schema_version": 1,
        "status": "MANUAL_PLAN_NO_TEST_EXECUTION_OR_APPROVAL",
        "base_patchset": "patchset-0002",
        "candidate_patchset": "patchset-0003_NOT_CREATED",
        "changed_patch_ids": changed,
        "changed_release_metadata_classifications": release_evidence,
        "manual_risk_focus": focus,
        "valid_scenario_count": len(cases),
        "scenarios": cases,
        "invalid_mutex_scenario_count": len(negatives),
        "negative_selection_scenarios": negatives,
        "required_human_evidence": [{"gate": gate, "status": "NOT_VERIFIED"} for gate in GATES],
        "all_scenarios_passed": False,
        "publisher_or_source_authenticated": False,
        "gameplay_test_performed": False,
        "physical_accessibility_test_performed": False,
        "real_mpq_bytes_inspected": False,
        "player_client_or_wtf_read": False,
        "player_client_or_wtf_modified": False,
        "backups_created": False,
        "recovery_tested": False,
        "patchset_or_manifest_written": False,
        "installation_authorised": False,
        "redistribution_authorised": False,
        "public_release_authorised": False,
        "private_paths_hashes_or_user_timestamps_reported": False,
        "limitations": "A test plan computed from untrusted proposal and public metadata, not execution evidence, authentic owner consent, licence clearance or reproducible physical Windows/gameplay testing.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Plan (never execute) synthetic/manual checks for hypothetical patchset-0003")
    parser.add_argument("--proposal", required=True, type=Path)
    parser.add_argument("--release-snapshot", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = make_plan(proposal_review._load(args.proposal),
                           proposal_review._load(args.release_snapshot))
    except (proposal_review.Refusal, drift.Refusal) as exc:
        print("BLOCKED: " + str(exc), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
