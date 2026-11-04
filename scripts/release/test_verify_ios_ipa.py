#!/usr/bin/env python3

import importlib.util
import plistlib
import tempfile
import unittest
import warnings
import zipfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("verify_ios_ipa.py")
SPEC = importlib.util.spec_from_file_location("verify_ios_ipa", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class VerifyIosIpaTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.ipa = Path(self.temp.name) / "Vocalart.ipa"

    def tearDown(self):
        self.temp.cleanup()

    def _profile(
        self,
        *,
        get_task_allow=False,
        app_id="com.mennansevim.vocalart",
        team_id="L3Z9U2B39K",
    ):
        return {
            "Name": "Vocalart App Store",
            "TeamIdentifier": [team_id],
            "ExpirationDate": datetime.now(timezone.utc) + timedelta(days=30),
            "Entitlements": {
                "application-identifier": f"{team_id}.{app_id}",
                "com.apple.developer.team-identifier": team_id,
                "get-task-allow": get_task_allow,
            },
        }

    def _signature(self):
        return {
            "teamId": "L3Z9U2B39K",
            "signingAuthority": "Apple Distribution: MENNAN SEVIM (L3Z9U2B39K)",
            "signedEntitlements": {
                "application-identifier": (
                    "L3Z9U2B39K.com.mennansevim.vocalart"
                ),
                "com.apple.developer.team-identifier": "L3Z9U2B39K",
                "get-task-allow": False,
            },
        }

    def _write_ipa(self, *, app_id="com.mennansevim.vocalart", encryption=False):
        root = "Payload/Runner.app"
        info = {
            "CFBundleIdentifier": app_id,
            "CFBundleDisplayName": "Vocalart",
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "2",
            "CFBundleExecutable": "Runner",
            "MinimumOSVersion": "15.0",
            "ITSAppUsesNonExemptEncryption": encryption,
        }
        with zipfile.ZipFile(self.ipa, "w") as archive:
            archive.writestr(f"{root}/Info.plist", plistlib.dumps(info))
            archive.writestr(f"{root}/Runner", b"binary")
            archive.writestr(f"{root}/_CodeSignature/CodeResources", b"signed")
            archive.writestr(f"{root}/embedded.mobileprovision", b"profile")

    def test_accepts_expected_app_store_artifact(self):
        self._write_ipa()
        result = MODULE.verify_ipa(
            self.ipa,
            expected_app_id="com.mennansevim.vocalart",
            expected_name="Vocalart",
            expected_version="1.0.0",
            expected_build="2",
            expected_team_id="L3Z9U2B39K",
            provision_decoder=lambda _: self._profile(),
            signature_verifier=lambda *_: self._signature(),
        )
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["build"], "2")

    def test_rejects_wrong_bundle_or_encryption_declaration(self):
        self._write_ipa(app_id="com.example.wrong")
        with self.assertRaisesRegex(MODULE.VerificationError, "bundle id"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=lambda *_: self._signature(),
            )
        self._write_ipa(encryption=True)
        with self.assertRaisesRegex(MODULE.VerificationError, "sifreleme"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=lambda *_: self._signature(),
            )

    def test_rejects_development_or_expired_profile(self):
        self._write_ipa()
        with self.assertRaisesRegex(MODULE.VerificationError, "App Store"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(get_task_allow=True),
                signature_verifier=lambda *_: self._signature(),
            )

    def test_rejects_profile_owned_by_another_apple_team(self):
        self._write_ipa()
        with self.assertRaisesRegex(MODULE.VerificationError, "application-identifier"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(team_id="OTHERTEAM1"),
                signature_verifier=lambda *_: self._signature(),
            )

    def test_rejects_signature_owned_by_another_apple_team(self):
        self._write_ipa()
        wrong_signature = self._signature() | {"teamId": "OTHERTEAM1"}
        with self.assertRaisesRegex(MODULE.VerificationError, "team kimligi"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=lambda *_: wrong_signature,
            )

        wrong_entitlements = self._signature() | {
            "signedEntitlements": {
                "application-identifier": "OTHERTEAM1.com.mennansevim.vocalart",
                "com.apple.developer.team-identifier": "OTHERTEAM1",
                "get-task-allow": False,
            }
        }
        with self.assertRaisesRegex(MODULE.VerificationError, "application-identifier"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=lambda *_: wrong_entitlements,
            )
        expired = self._profile()
        expired["ExpirationDate"] = datetime.now(timezone.utc) - timedelta(days=1)
        with self.assertRaisesRegex(MODULE.VerificationError, "suresi dolmus"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: expired,
                signature_verifier=lambda *_: self._signature(),
            )

    def test_rejects_artifact_version_that_differs_from_pubspec_contract(self):
        self._write_ipa()
        with self.assertRaisesRegex(MODULE.VerificationError, "pubspec"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="3",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=lambda *_: self._signature(),
            )

    def test_requires_signature_verifier_to_succeed(self):
        self._write_ipa()

        def reject(*_):
            raise MODULE.VerificationError("signature rejected")

        with self.assertRaisesRegex(MODULE.VerificationError, "signature rejected"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=reject,
            )

    def test_rejects_duplicate_archive_path_before_extraction(self):
        self._write_ipa()
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(self.ipa, "a") as archive:
                archive.writestr("Payload/Runner.app/Runner", b"replacement")
        with self.assertRaisesRegex(MODULE.VerificationError, "duplicate path"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=lambda *_: self._signature(),
            )

    def test_reads_one_strict_pubspec_version(self):
        pubspec = Path(self.temp.name) / "pubspec.yaml"
        pubspec.write_text("name: vocalart\nversion: 1.2.3+45\n", encoding="utf-8")
        self.assertEqual(MODULE.read_pubspec_version(pubspec), ("1.2.3", "45"))
        pubspec.write_text("name: vocalart\nversion: next\n", encoding="utf-8")
        with self.assertRaisesRegex(MODULE.VerificationError, "semver"):
            MODULE.read_pubspec_version(pubspec)


if __name__ == "__main__":
    unittest.main()
