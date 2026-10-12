#!/usr/bin/env python3
"""Public source evidence consistency gate; NEVER determines legal permissions.

Only reads this repository's public JSON/text files. No network, game/client,
MPQ, binary archive, account/WTF, download, installation or backup activity.
"""
from __future__ import annotations

import copy
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs" / "release-rights-evidence-v1.json"
CATALOG = ROOT / "config" / "optional-content.json"

ASSETS = {
    "patch-v": ("v1.0.6.8.4", "patch-V.mpq",
                "68ca0d260841a028181fdeac72db5cd96a752da9c5f2798432a065db6dcd70ff", 450631505),
    "patch-z": ("v1.0.6.7", "patch-Z.mpq",
                "5eb17ce5dc7b87990dd173a7c3dd3ff5be7d34219be407eaa854d95625011b3a", 47337608),
    "patch-j": ("optional-v1.0", "Patch-J.mpq",
                "24385046f0db6c17db5f549fa0f418f5d5ed1d4c2100059f1db9bede709113c9", 5739890),
    "patch-c": ("optional-v1.0", "Patch-C.mpq",
                "16b339522ca9394c11a5afe505e25cf9f326325eb2518dfde328ff08a99920c8", 26753640),
    "patch-u": ("optional-v1.0", "Patch-U.mpq",
                "51fc8cbd1786537772ea7f59eac7be244eedabf7e6487ee41e5ce2009ecd9a6d", 11050502),
}
FOLDERS = {
    "ncore": "NCore",
    "individual-progression": "IndividualProgressionAddon",
    "dungeon-journal": "DungeonJournal",
    "multibot": "MultiBot",
    "loot-ledger": "NaxxLootLottery",
}
ROW_FIELDS = {
    "id", "kind", "release", "file", "sha256", "size_bytes",
    "source_license_evidence", "rights_issue", "redistribution_cleared",
    "installation_approved", "public_release_authorised",
}
GATE_FIELDS = {
    "asset_fingerprints_authorise_distribution",
    "release_page_authorises_repackaging",
    "source_tag_authorises_repackaging",
    "known_gpl_notice_proves_all_assets_licensed",
    "original_author_credits_are_permission",
    "suite_licence_compatibility_verified",
    "optional_patch_repackaging_approved",
    "required_patch_repackaging_approved",
    "addon_suite_repackaging_approved",
    "real_client_installation_approved",
    "public_client_setup_release_approved",
}


def check_evidence(document: object, catalog: object) -> None:
    """Deny incomplete data and *all* unreviewed permissions, no exceptions."""
    if type(document) is not dict or type(catalog) is not dict:
        raise ValueError("unsupported_public_evidence_structure")
    if (type(document.get("schema_version")) is not int or
        document["schema_version"] != 1 or
        document.get("kind") != "public_source_rights_evidence_not_distribution_authority" or
        document.get("classification") != "reference_only_not_legal_clearance"):
        raise ValueError("unrecognised_release_rights_evidence")
    rows = document.get("items")
    if type(rows) is not list or len(rows) != 10:
        raise ValueError("incomplete_public_source_inventory")
    seen = set()
    for item in rows:
        if type(item) is not dict or set(item) != ROW_FIELDS:
            raise ValueError("malformed_source_evidence_row")
        key = item["id"]
        if type(key) is not str or key in seen or key not in ASSETS and key not in FOLDERS:
            raise ValueError("duplicate_or_unknown_source_item")
        seen.add(key)
        if any(type(item[k]) is not bool or item[k] for k in
               ("redistribution_cleared", "installation_approved", "public_release_authorised")):
            raise ValueError("unverified_redistribution_or_install_permission")
        if (type(item["source_license_evidence"]) is not str or
            not item["source_license_evidence"] or
            type(item["rights_issue"]) is not str or len(item["rights_issue"]) < 45):
            raise ValueError("incomplete_rights_gap_explanation")
        if key in ASSETS:
            release, file, digest, size = ASSETS[key]
            if (item["kind"] not in ("required_patch", "optional_patch") or
                (item["release"], item["file"], item["sha256"], item["size_bytes"]) !=
                (release, file, digest, size)):
                raise ValueError("changed_pinned_patch_release_reference")
        else:
            if (item["kind"] != "suite_folder" or item["release"] != "v2.0.0" or
                item["file"] != FOLDERS[key] or item["sha256"] is not None or
                item["size_bytes"] is not None):
                raise ValueError("changed_suite_folder_evidence")
    if seen != set(ASSETS) | set(FOLDERS):
        raise ValueError("missing_source_items")
    gates = document.get("gates")
    if type(gates) is not dict or set(gates) != GATE_FIELDS or any(type(v) is not bool or v for v in gates.values()):
        raise ValueError("rights_verification_not_permission")
    sources = document.get("source_repositories")
    if type(sources) is not list or len(sources) != 4:
        raise ValueError("missing_public_evidence_references")
    for source in sources:
        if type(source) is not dict or set(source) != {"name", "url", "source_tag"}:
            raise ValueError("malformed_public_evidence_reference")
        if (type(source["name"]) is not str or type(source["source_tag"]) is not str or
            type(source["url"]) is not str or not source["url"].startswith(
                "https://github.com/CosmicCuddle/")):
            raise ValueError("untrusted_public_evidence_reference")
    if not catalog.get("patch_c") or not catalog.get("addon_suite"):
        raise ValueError("missing_read_only_optional_catalog")
    patch = catalog["patch_c"]
    addon = catalog["addon_suite"]
    if (patch.get("sha256") != ASSETS["patch-c"][2] or
        patch.get("size_bytes") != ASSETS["patch-c"][3] or
        type(patch.get("redistribution_approved")) is not bool or patch["redistribution_approved"]):
        raise ValueError("optional_patch_redistribution_unapproved")
    for key in ("archive_verification_approved", "automatic_download_approved", "install_approved"):
        if type(addon.get(key)) is not bool or addon[key]:
            raise ValueError("addon_suite_install_or_download_unapproved")
    if addon.get("archive_sha256") != "07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324":
        raise ValueError("addon_release_reference_changed")
    if addon.get("required_with_suite") != ["NCore"] or set(addon.get("optional_folders", [])) != set(FOLDERS.values()) - {"NCore"}:
        raise ValueError("unrecognised_suite_folder_scope")


class ReleaseRightsEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = json.loads(EVIDENCE.read_text(encoding="utf-8"))
        cls.catalog = json.loads(CATALOG.read_text(encoding="utf-8"))

    def test_original_public_snapshot_has_no_install_or_redistribution_authority(self):
        check_evidence(self.doc, self.catalog)

    def test_no_item_can_silently_be_marked_cleared(self):
        for row in self.doc["items"]:
            for key in ("redistribution_cleared", "installation_approved", "public_release_authorised"):
                with self.subTest(id=row["id"], gate=key):
                    changed = copy.deepcopy(self.doc)
                    changed["items"][next(i for i, item in enumerate(changed["items"])
                                          if item["id"] == row["id"])][key] = True
                    with self.assertRaises(ValueError):
                        check_evidence(changed, self.catalog)

    def test_missing_source_and_duplicate_are_rejected(self):
        truncated = copy.deepcopy(self.doc)
        truncated["items"].pop()
        with self.assertRaises(ValueError):
            check_evidence(truncated, self.catalog)
        repeated = copy.deepcopy(self.doc)
        repeated["items"][-1] = copy.deepcopy(repeated["items"][0])
        with self.assertRaises(ValueError):
            check_evidence(repeated, self.catalog)

    def test_no_caller_controlled_approval_flag_can_replace_evidence(self):
        for key in GATE_FIELDS:
            altered = copy.deepcopy(self.doc)
            altered["gates"][key] = True
            with self.subTest(gate=key), self.assertRaises(ValueError):
                check_evidence(altered, self.catalog)

    def test_patch_release_reference_pins_are_not_permission(self):
        changed = copy.deepcopy(self.doc)
        changed["items"][0]["sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            check_evidence(changed, self.catalog)

    def test_existing_patch_c_and_suite_planner_remain_denied(self):
        changed = copy.deepcopy(self.catalog)
        changed["patch_c"]["redistribution_approved"] = True
        with self.assertRaises(ValueError):
            check_evidence(self.doc, changed)
        for key in ("archive_verification_approved", "automatic_download_approved", "install_approved"):
            changed = copy.deepcopy(self.catalog)
            changed["addon_suite"][key] = True
            with self.subTest(key=key), self.assertRaises(ValueError):
                check_evidence(self.doc, changed)

    def test_gpl_text_is_not_asset_rights_or_full_legal_compliance(self):
        rows = {item["id"]: item for item in self.doc["items"]}
        self.assertEqual(rows["dungeon-journal"]["source_license_evidence"],
                         "gpl_v2_text_and_detailed_credits_present")
        self.assertEqual(rows["multibot"]["source_license_evidence"], "gpl_v3_text_present")
        self.assertIn("not covered by GPL", rows["dungeon-journal"]["rights_issue"])
        self.assertFalse(self.doc["gates"]["known_gpl_notice_proves_all_assets_licensed"])


if __name__ == "__main__":
    unittest.main()
