#!/usr/bin/env python3
"""Print only an unperformed human Windows QA checklist from reviewed metadata.

No game, client, MPQ, WTF, screenshots, installer, backup or write access.
This does not perform any of the described actions.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

import plan_patchset3_manual_qa as qa
import review_disposable_test_client as preflight
import review_patch_update_proposal as proposals
import review_public_release_drift as drift

B = chr(96)
CHECK_LABELS = {
    "baseline_335a_build_12340_and_enus_compatibility":
        "Independently check genuine WoW 3.3.5a build 12340/enUS; File Properties > Details is only a version claim",
    "required_v_z_present_and_matching_reviewed_bytes":
        "Confirm V/Z against the reviewed source for this particular test; v2 pins do not prove changed hypothetical v3 files",
    "game_starts_and_login_and_realm_selection_work":
        "Launch disposable game manually, inspect login/buttons/music/realm selection; do not publish account or realm details",
    "gameplay_realm_and_character_entry_smoke":
        "Enter an authorised test character and exercise basic gameplay without public player data",
    "no_unexpected_game_file_or_wtf_mutation":
        "Compare separately protected original and all-account WTF before/after inventories, without changing originals",
    "vanilla_login_visuals_buttons_music_and_interaction":
        "Inspect J Vanilla logo/art/buttons/music and verify C is physically absent",
    "tbc_login_dark_portal_visuals_buttons_music_and_interaction":
        "Inspect C TBC Dark Portal art/buttons/music and verify J is physically absent",
    "eastern_kingdoms_kalimdor_standard_and_widescreen_loading":
        "Inspect Eastern Kingdoms and Kalimdor loading artwork in normal and widescreen",
    "j_u_two_overlapping_texture_paths_must_warn_and_be_checked":
        "Observe the two J/U overlapping loading texture paths and actual visual precedence",
}


class Refusal(ValueError):
    """Fixed refusal code without any supplied user data."""


def render(plan: dict) -> str:
    if (type(plan) is not dict or plan.get("status") != "MANUAL_PLAN_NO_TEST_EXECUTION_OR_APPROVAL"
        or plan.get("candidate_patchset") != "patchset-0003_NOT_CREATED"):
        raise Refusal("invalid_qa_plan_state")
    cases = plan.get("scenarios")
    negative = plan.get("negative_selection_scenarios")
    if type(cases) is not list or len(cases) != 6 or type(negative) is not list or len(negative) != 2:
        raise Refusal("invalid_qa_scenario_count")
    lines = [
        "# Naxxramas — Human Windows QA Worksheet", "",
        "**ALL TESTS: NOT TESTED. No client inspection or user approval performed.**", "",
        "This is a printable worksheet generated from a claimed hypothetical patchset-0003 proposal.",
        "Neither the worksheet nor its source data proves game authenticity, legal rights, or install permission.", "",
        "## Prerequisites — all NOT TESTED", "",
        "- [ ] Obtain explicit owner permission for a separate **disposable test copy**, never the sole working client.",
        "- [ ] Separately protect and verify a restorable copy of all original files and **all** account/realm/character WTF data.",
        "- [ ] Confirm lawful sources, permitted test captures, independent reviewer and private evidence retention rules.",
        "- [ ] Verify genuine game 3.3.5a build **12340** and enUS against an independently trusted baseline.",
        "- [ ] On Windows, inspect Wow.exe Properties > Details > File version; do NOT treat that field alone as genuine provenance.",
        "- [ ] Confirm that private account, realm, chat, screenshot and SavedVariables data never enters public reports.",
        "- [ ] Prepare a separately controlled clean disposable baseline for **each** scenario.",
        "- [ ] Note: existing read-only preflight matches frozen **patchset-0002**, not new hypothetical patchset-0003 bytes.",
        "",
        "## Six legal cases — all NOT TESTED", "",
        "Each preflight command must be run **only with prior authorisation**, against the separately marked test copy.",
        "The marker is caller-controlled and cannot prove that the folder is safe or actually disposable.",
        "A clean local SHA/size result is NOT independent evidence of the game build, publisher, gameplay, or v3 update.",
        "Unselected optional MPQs must be physically absent. If a case is mismatched, stop and record BLOCKED/FAIL, not PASS.",
        "",
    ]
    for got, (case_id, extras, purpose) in zip(cases, qa.VALID_CASES):
        if (type(got) is not dict or got.get("case_id") != case_id or
            got.get("selected_optional_patches") != list(extras) or
            got.get("required_patches") != ["V", "Z"] or
            got.get("case_purpose") != purpose or
            got.get("human_execution_status") != "NOT_TESTED" or
            got.get("result") != "NO_RESULT_RECORDED" or
            tuple(preflight.OPTIONS.get(case_id, ("INVALID",))) != extras):
            raise Refusal("qa_preflight_case_drift")
        expected = list(qa.SAFE_CHECK_IDS)
        if "J" in extras:
            expected.append("vanilla_login_visuals_buttons_music_and_interaction")
        if "C" in extras:
            expected.append("tbc_login_dark_portal_visuals_buttons_music_and_interaction")
        if "U" in extras:
            expected.append("eastern_kingdoms_kalimdor_standard_and_widescreen_loading")
        if "J" in extras and "U" in extras:
            expected.append("j_u_two_overlapping_texture_paths_must_warn_and_be_checked")
        if got.get("checks") != expected or any(check not in CHECK_LABELS for check in expected):
            raise Refusal("qa_check_drift")
        names = " + ".join(["V", "Z", *extras])
        lines.extend([
            "### " + B + case_id + B + " — " + names + " — NOT TESTED", "",
            "- [ ] Confirm separate test copy restored and exact optional file selection manually verified.",
            "- [ ] Run read-only reference preflight (source pins are v2; NOT v3 approval):", "",
            B * 3 + "powershell",
            r'py -3.12 tools\review_disposable_test_client.py --test-root "D:\SeparateTestCopy" --selection ' + case_id,
            B * 3, "",
            "- [ ] Review preflight report locally; an extra optional MPQ or mismatch blocks any clean conclusion.",
        ])
        for check in expected:
            lines.append("- [ ] " + B + check + B + " — " + CHECK_LABELS[check])
        lines.extend([
            "- [ ] Record a real observation only in the private plan-bound self-report; never mark this worksheet automatically complete.",
            "",
        ])

    lines.extend(["## Two forbidden combinations — NOT TESTED", ""])
    for got, (case_id, selected) in zip(negative, qa.INVALID_CASES):
        if (type(got) is not dict or got.get("case_id") != case_id or
            got.get("attempted_optional_patches") != list(selected) or
            got.get("expected") != "MUTUALLY_EXCLUSIVE_J_C_REFUSED_NO_FILE_WRITE" or
            got.get("human_execution_status") != "NOT_TESTED" or
            got.get("result") != "NO_RESULT_RECORDED"):
            raise Refusal("qa_negative_case_drift")
        lines.extend([
            "### " + B + case_id + B + " — " + " + ".join(selected) + " — NOT TESTED", "",
            "- [ ] Test **only** an independently authorised selection-only/dry-run interface, if safely available.",
            "- [ ] Confirm J + C rejected BEFORE any file write; do NOT install both patches for this test.",
            "- [ ] Confirm no client, Data or WTF files changed; classify accidental acceptance as " +
            B + "mutex_did_not_reject" + B + ".", "",
        ])
    lines.extend([
        "## Physical Windows accessibility — NOT TESTED", "",
        "These require hands-on acceptance of a reviewed **non-writing** setup UI; CI cannot substitute.",
        "",
    ])
    for scale in ("100%", "125%", "150%", "200%"):
        lines.extend([
            "### Display scaling " + scale + " — NOT TESTED", "",
            "- [ ] No clipped or overlapping controls, labels or long errors.",
            "- [ ] Keyboard Tab / Shift+Tab navigation, activation and non-writing cancellation.",
            "- [ ] High Contrast legible, focus visible; Narrator/screen reader names and error feedback usable.",
            "",
        ])
    lines.extend([
        "## Final independent acceptance — NOT VERIFIED", "",
        "- [ ] Separate authorised reviewer inspects actual minimal test evidence with private data redacted.",
        "- [ ] Verify reviewer identity, freshness and anti-replay outside caller-controlled JSON or cloned files.",
        "- [ ] Preserve FAIL/BLOCKED records; a pair of matching reports is not proof of independent human observations.",
        "- [ ] Independently clear source rights, all-original/WTF backups and restoration, owner consent and gameplay compatibility.",
        "",
        "**NO TESTS EXECUTED. NO BACKUP, RESTORE, INSTALLATION OR PUBLIC RELEASE AUTHORISED.**", "",
    ])
    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser(description="Print an uncompleted Windows game QA worksheet, never run it")
    p.add_argument("--proposal", required=True)
    p.add_argument("--release-snapshot", required=True)
    args = p.parse_args()
    try:
        plan = qa.make_plan(proposals._load(Path(args.proposal)),
                            proposals._load(Path(args.release_snapshot)))
        result = render(plan)
    except (Refusal, proposals.Refusal, drift.Refusal, OSError) as exc:
        label = str(exc) if isinstance(exc, (Refusal, proposals.Refusal, drift.Refusal)) else "unreadable_metadata_fixture"
        print("BLOCKED: " + label, file=sys.stderr)
        return 2
    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
