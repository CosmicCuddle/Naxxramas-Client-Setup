#!/usr/bin/env python3
"""Developer-only unit tests: disposable fake ZIP bytes, never real player files."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

MODULE = Path(__file__).resolve().parents[1] / "tools" / "audit_addon_zip_payload.py"
spec = importlib.util.spec_from_file_location("addon_payload_audit", MODULE)
audit_module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(audit_module)


def make_members() -> dict[str, bytes]:
    members = {
        "NCore/NCore.toc": b"## Interface: 30300\n## Title: NCore\n\nCore.lua\nExpectedVersions.lua\nClassicBattlegrounds\\NClassicBattlegrounds.lua\nSettings.lua\nLegacyCheck.lua\n",
        "NCore/Core.lua": b"CRC_SENTINEL_PAYLOAD_42",
        "NCore/ExpectedVersions.lua": b'NCore.expectedVersions = {\n    ["IndividualProgressionAddon"] = "5.2.0",\n    ["DungeonJournal"] = "0.6.1",\n    ["MultiBot"] = "4.0",\n    ["NaxxLootLottery"] = "0.1.0.27",\n}\n',
        "NCore/ClassicBattlegrounds/NClassicBattlegrounds.lua": b"-- fake test file\n",
        "NCore/Settings.lua": b"-- fake test file\n",
        "NCore/LegacyCheck.lua": b"-- fake test file\n",
        "DungeonJournal/LICENSE-GPL-2.0.txt": b"GNU GENERAL PUBLIC LICENSE\nVersion 2, June 1991",
        "DungeonJournal/CREDITS.txt": b"FAKE license credits for synthetic fixtures",
        "MultiBot/LICENSE": b"GNU GENERAL PUBLIC LICENSE\nVersion 3, 29 June 2007",
    }
    for name, (account, character) in audit_module.SAVED_VARIABLES.items():
        if name == "NCore":
            continue
        lines = ["## Interface: 30300", f"## Title: {name}", "## Dependencies: NCore"]
        if account:
            lines.append("## SavedVariables: " + ", ".join(account))
        if character:
            lines.append("## SavedVariablesPerCharacter: " + ", ".join(character))
        lines.append("")
        lines.append("Core.lua")
        members[f"{name}/{name}.toc"] = ("\n".join(lines) + "\n").encode()
        members[f"{name}/Core.lua"] = b"-- safe fake script, never executed\n"
    return members


class TestDeveloperAddonPayloadAudit(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(prefix="NaxxAddonPayload-SYNTHETIC-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.sentinel = self.root / "FAKE-player-addon-settings.lua"
        self.sentinel.write_bytes(b"DO_NOT_TOUCH_SYNTHETIC_SETTINGS")

    def make_zip(self, files: dict[str, bytes] | None = None,
                 extras: list[tuple[str, bytes]] | None = None) -> Path:
        path = self.root / "fake.zip"
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as z:
            for name, data in (files if files is not None else make_members()).items():
                z.writestr(name, data)
            for name, data in (extras or []):
                z.writestr(name, data)
        return path

    def expect_blocked(self, files: dict[str, bytes]) -> None:
        with self.assertRaises((audit_module.AuditFailure, zipfile.BadZipFile,
                               RuntimeError, EOFError)):
            audit_module.audit(self.make_zip(files), fixture=True)
        self.assertEqual(self.sentinel.read_bytes(), b"DO_NOT_TOUCH_SYNTHETIC_SETTINGS")

    def test_good_fixture_reads_all_members_and_preserves_settings(self) -> None:
        report = audit_module.audit(self.make_zip(), fixture=True)
        self.assertEqual(report["reference_kind"], "synthetic_test_only")
        self.assertEqual(report["files_crc_verified"], len(make_members()))
        self.assertEqual(report["toc_load_file_references_checked"], 9)
        self.assertTrue(report["savedvariables_declarations_match_tag"])
        self.assertTrue(report["license_and_credits_files_readable"])
        self.assertFalse(report["installation_backup_or_rollback_authorised"])
        self.assertFalse(report["redistribution_authorised"])
        self.assertFalse(report["client_files_modified"])
        self.assertEqual(self.sentinel.read_bytes(), b"DO_NOT_TOUCH_SYNTHETIC_SETTINGS")

    def test_reject_wrong_interface(self) -> None:
        files = make_members()
        files["MultiBot/MultiBot.toc"] = files["MultiBot/MultiBot.toc"].replace(b"30300", b"20400")
        self.expect_blocked(files)

    def test_reject_missing_ncore_dependency(self) -> None:
        files = make_members()
        files["DungeonJournal/DungeonJournal.toc"] = files["DungeonJournal/DungeonJournal.toc"].replace(
            b"## Dependencies: NCore\n", b"")
        self.expect_blocked(files)

    def test_reject_missing_toc_loaded_file(self) -> None:
        files = make_members()
        files["NCore/NCore.toc"] += b"Unshipped.lua\n"
        self.expect_blocked(files)

    def test_reject_savedvariables_changes(self) -> None:
        files = make_members()
        files["MultiBot/MultiBot.toc"] = files["MultiBot/MultiBot.toc"].replace(
            b"MultiBotSave, MultiBotDB, MultiBotSaved", b"MultiBotSave")
        self.expect_blocked(files)

    def test_reject_wrong_expected_version(self) -> None:
        files = make_members()
        files["NCore/ExpectedVersions.lua"] = files["NCore/ExpectedVersions.lua"].replace(
            b'"MultiBot"] = "4.0"', b'"MultiBot"] = "9.9"')
        self.expect_blocked(files)

    def test_reject_dropped_gpl_license(self) -> None:
        files = make_members()
        files["DungeonJournal/LICENSE-GPL-2.0.txt"] = b"NO LICENCE"
        self.expect_blocked(files)

    def test_reject_unsafe_extracted_paths_even_in_fixture(self) -> None:
        path = self.make_zip(extras=[("NCore/../WTF/Private.lua", b"FAKE")])
        with self.assertRaises(audit_module.AuditFailure):
            audit_module.audit(path, fixture=True)

    def test_reject_case_collision(self) -> None:
        path = self.make_zip(extras=[("ncore/ncore.toc", b"FAKE")])
        with self.assertRaises(audit_module.AuditFailure):
            audit_module.audit(path, fixture=True)

    def test_detect_corrupted_zip_payload_crc(self) -> None:
        path = self.make_zip()
        data = path.read_bytes()
        marker = b"CRC_SENTINEL_PAYLOAD_42"
        self.assertEqual(data.count(marker), 1)
        path.write_bytes(data.replace(marker, b"XRC_SENTINEL_PAYLOAD_42"))
        with self.assertRaises(zipfile.BadZipFile):
            audit_module.audit(path, fixture=True)

    def test_nonfixture_rejects_fake_named_release(self) -> None:
        path = self.make_zip()
        path.rename(self.root / audit_module.EXPECTED_FILENAME)
        with self.assertRaises(audit_module.AuditFailure):
            audit_module.audit(self.root / audit_module.EXPECTED_FILENAME)
        self.assertEqual(self.sentinel.read_bytes(), b"DO_NOT_TOUCH_SYNTHETIC_SETTINGS")


if __name__ == "__main__":
    unittest.main(verbosity=2)
