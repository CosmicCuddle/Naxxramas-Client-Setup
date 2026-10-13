#!/usr/bin/env python3
"""Inspect ONLY marked, disposable ASCII fake patchset-0003 evidence bundles.

A complete bundle proves consistency of bytes under one caller's control,
NOT independent game testing, chain of custody, signature, freshness, or rights.
No game/MPQ/WTF, arbitrary screenshot, backup, installer, network or write I/O.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import plan_patchset3_manual_qa as planner
import review_patch_update_proposal as proposal
import review_public_release_drift as drift
import review_patchset3_manual_record as records

MARKER = ".naxx-patchset3-synthetic-evidence-only"
MARKER_BYTES = b"NAXX_SYNTHETIC_PATCHSET3_EVIDENCE_V1\n"
KIND = "synthetic_patchset3_evidence_index_NOT_GAME_PROOF"
ENTRY_FIELDS = {"case_id", "check_id", "status", "file", "size_bytes", "sha256"}
INDEX_FIELDS = {"schema_version", "kind", "plan_sha256", "report_sha256", "artifacts"}
MAX_INDEX_BYTES = 32 * 1024
MAX_PAYLOAD_BYTES = 512
MAX_ARTIFACTS = 64
HEADER = "SYNTHETIC PATCHSET3 EVIDENCE ONLY\n"


class Refusal(ValueError):
    """Fixed, privacy-safe failure code."""


def _secure_file(path: Path, size: int) -> bytes:
    try:
        if path.is_symlink() or not path.is_file():
            raise Refusal("missing_or_linked_synthetic_file")
        stat = path.stat()
        if stat.st_nlink != 1 or stat.st_size < 1 or stat.st_size > size:
            raise Refusal("unsafe_synthetic_file_length_or_link_count")
        data = path.read_bytes()
        if len(data) != stat.st_size or len(data) > size:
            raise Refusal("unstable_synthetic_file_size")
        return data
    except OSError as exc:
        raise Refusal("unreadable_synthetic_file") from exc


def fake_payload(case_id: str, check_id: str, status: str) -> bytes:
    # Exact no-binary, no-user-info fixture grammar. This cannot accept real
    # screenshots or player files, even when given a fake .txt extension.
    return (HEADER + "case_id=" + case_id + "\n" +
            "check_id=" + check_id + "\n" +
            "status=" + status + "\n").encode("ascii")


def expected_artifacts(record: dict, plan: dict) -> list[tuple[str, str, str]]:
    """Derive required fake evidence from an already validated report."""
    records.review_record(record, plan)
    required = []
    for scenario in record["valid_scenarios"]:
        ident = scenario["case_id"]
        for check in scenario["checks"]:
            if check["status"] != "NOT_TESTED":
                required.append((ident, check["check_id"], check["status"]))
        if scenario["outcome"] == "BLOCKED":
            required.append((ident, "case_blocker", "BLOCKED"))
    for scenario in record["negative_selection_scenarios"]:
        if scenario["outcome"] != "NOT_TESTED":
            required.append((scenario["case_id"], "selection_outcome", scenario["outcome"]))
    if len(required) > MAX_ARTIFACTS:
        raise Refusal("too_many_synthetic_artifact_observations")
    return required


def _decode_file(path: Path, max_bytes: int) -> object:
    return drift._decode(_secure_file(path, max_bytes))


def review(bundle: Path, plan: dict) -> dict:
    if bundle.is_symlink() or not bundle.is_dir():
        raise Refusal("unmarked_or_linked_synthetic_root")
    marker = _secure_file(bundle / MARKER, 100)
    if marker != MARKER_BYTES:
        raise Refusal("synthetic_fixture_marker_mismatch")
    root_names = {entry.name for entry in bundle.iterdir()}
    if root_names != {MARKER, "report.json", "index.json", "evidence"}:
        raise Refusal("unexpected_synthetic_root_contents")
    folder = bundle / "evidence"
    if folder.is_symlink() or not folder.is_dir():
        raise Refusal("missing_or_linked_synthetic_evidence_folder")
    report = _decode_file(bundle / "report.json", records.MAX_RECORD)
    # Do NOT trust the report; run the exact existing plan-bound status rules.
    summary = records.review_record(report, plan)
    index = _decode_file(bundle / "index.json", MAX_INDEX_BYTES)
    if type(index) is not dict or set(index) != INDEX_FIELDS:
        raise Refusal("invalid_synthetic_evidence_index")
    if (type(index["schema_version"]) is not int or index["schema_version"] != 1 or
        index["kind"] != KIND or
        type(index["plan_sha256"]) is not str or
        index["plan_sha256"] != records.fingerprint(plan) or
        type(index["report_sha256"]) is not str or
        index["report_sha256"] != hashlib.sha256(records._json_bytes(report)).hexdigest()):
        raise Refusal("stale_or_coherently_unproven_bundle_binding")
    expected = expected_artifacts(report, plan)
    rows = index["artifacts"]
    if type(rows) is not list or len(rows) != len(expected) or len(rows) > MAX_ARTIFACTS:
        raise Refusal("incomplete_or_excess_synthetic_artifacts")
    names = set()
    summaries = []
    for row, (ident, check_id, status) in zip(rows, expected):
        if type(row) is not dict or set(row) != ENTRY_FIELDS:
            raise Refusal("invalid_synthetic_artifact_entry")
        expected_name = f"{ident}--{check_id}.txt"
        expected_path = "evidence/" + expected_name
        if (row["case_id"] != ident or row["check_id"] != check_id or
            row["status"] != status or row["file"] != expected_path or
            type(row["size_bytes"]) is not int or
            type(row["sha256"]) is not str or
            row["sha256"] != hashlib.sha256(fake_payload(ident, check_id, status)).hexdigest() or
            row["size_bytes"] != len(fake_payload(ident, check_id, status)) or
            expected_name in names):
            raise Refusal("incorrect_or_reused_synthetic_artifact_binding")
        names.add(expected_name)
        real = _secure_file(folder / expected_name, MAX_PAYLOAD_BYTES)
        if real != fake_payload(ident, check_id, status):
            raise Refusal("modified_or_replaced_synthetic_artifact_bytes")
        summaries.append({"case_id": ident, "check_id": check_id,
                          "claimed_status": status, "synthetic_bytes_match": True})
    if {entry.name for entry in folder.iterdir()} != names:
        raise Refusal("unindexed_or_missing_synthetic_artifact")
    return {
        "kind": "patchset3_disposable_evidence_byte_consistency_review",
        "status": "SYNTHETIC_BYTES_CONSISTENT_NOT_GAME_EVIDENCE",
        "scenario_count": 8,
        "synthetic_artifact_count": len(summaries),
        "synthetic_artifacts": summaries,
        "self_reported_counts": summary["self_reported_counts"],
        "fixture_only": True,
        "marker_not_a_trusted_authority": True,
        "bundle_hashes_not_an_independent_trust_root": True,
        "independent_custody_verified": False,
        "publisher_or_test_operator_authenticated": False,
        "physical_gameplay_or_accessibility_observed": False,
        "real_mpq_image_or_player_files_read": False,
        "real_mpq_image_or_player_files_modified": False,
        "protection_against_coherent_replay": False,
        "true_source_rights_established": False,
        "backup_or_recovery_performed": False,
        "patchset_or_manifest_written": False,
        "installation_authorised": False,
        "redistribution_authorised": False,
        "public_release_authorised": False,
        "private_paths_hashes_report_dates_or_identities_emitted": False,
        "limitations": "An entirely caller-controlled fake ASCII bundle can be coherently replayed or recreated. Byte matching proves no physical gameplay, separate observer, protected custody or approval.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect only explicitly marked disposable ASCII evidence bundles")
    parser.add_argument("--proposal", type=Path, required=True)
    parser.add_argument("--release-snapshot", type=Path, required=True)
    parser.add_argument("--synthetic-bundle", type=Path, required=True)
    args = parser.parse_args()
    try:
        plan = planner.make_plan(proposal._load(args.proposal),
                                 proposal._load(args.release_snapshot))
        result = review(args.synthetic_bundle, plan)
    except (Refusal, records.Refusal, proposal.Refusal, drift.Refusal, OSError) as exc:
        # Never print raw exceptions, paths, checked private hashes or data.
        failure = str(exc) if isinstance(exc, (Refusal, records.Refusal, proposal.Refusal, drift.Refusal)) else "unreadable_synthetic_fixture"
        print("BLOCKED: " + failure, file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
