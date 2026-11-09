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
            "architectures": {
                ".": ["arm64"],
                "Frameworks/App.framework": ["arm64"],
            },
            "platforms": {
                ".": {"platform": "IOS", "minimumOS": "15.0"},
                "Frameworks/App.framework": {
                    "platform": "IOS",
                    "minimumOS": "13.0",
                },
            },
        }

    def _privacy_manifest(self):
        return {
            "NSPrivacyTracking": False,
            "NSPrivacyTrackingDomains": [],
            "NSPrivacyCollectedDataTypes": [],
            "NSPrivacyAccessedAPITypes": [
                {
                    "NSPrivacyAccessedAPIType": (
                        "NSPrivacyAccessedAPICategoryFileTimestamp"
                    ),
                    "NSPrivacyAccessedAPITypeReasons": ["C617.1"],
                }
            ],
        }

    def _write_ipa(
        self,
        *,
        app_id="com.mennansevim.vocalart",
        encryption=False,
        privacy_manifest="default",
        embedded_privacy_manifest=None,
        info_overrides=None,
        include_localizations=True,
    ):
        root = "Payload/Runner.app"
        info = {
            "CFBundleIdentifier": app_id,
            "CFBundleDisplayName": "Vocalart",
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "2",
            "CFBundleExecutable": "Runner",
            "MinimumOSVersion": "15.0",
            "ITSAppUsesNonExemptEncryption": encryption,
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "DTPlatformName": "iphoneos",
            "DTSDKName": "iphoneos27.0",
            "LSRequiresIPhoneOS": True,
            "UIRequiredDeviceCapabilities": ["arm64"],
            "CFBundleLocalizations": ["en", "tr"],
            "NSMicrophoneUsageDescription": MODULE.MICROPHONE_DESCRIPTIONS["tr"],
        }
        if info_overrides:
            info.update(info_overrides)
        with zipfile.ZipFile(self.ipa, "w") as archive:
            archive.writestr(f"{root}/Info.plist", plistlib.dumps(info))
            archive.writestr(f"{root}/Runner", b"binary")
            archive.writestr(f"{root}/_CodeSignature/CodeResources", b"signed")
            archive.writestr(f"{root}/embedded.mobileprovision", b"profile")
            if privacy_manifest is not None:
                value = (
                    self._privacy_manifest()
                    if privacy_manifest == "default"
                    else privacy_manifest
                )
                archive.writestr(
                    f"{root}/PrivacyInfo.xcprivacy", plistlib.dumps(value)
                )
            if embedded_privacy_manifest is not None:
                archive.writestr(
                    f"{root}/Example.bundle/PrivacyInfo.xcprivacy",
                    plistlib.dumps(embedded_privacy_manifest),
                )
            if include_localizations:
                for language, description in MODULE.MICROPHONE_DESCRIPTIONS.items():
                    archive.writestr(
                        f"{root}/{language}.lproj/InfoPlist.strings",
                        plistlib.dumps(
                            {"NSMicrophoneUsageDescription": description}
                        ),
                    )

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
        self.assertTrue(result["privacyManifestVerified"])
        self.assertTrue(result["deviceArchitecturesVerified"])
        self.assertEqual(result["verifiedMachOBundles"], 2)
        self.assertTrue(result["devicePlatformsVerified"])
        self.assertEqual(result["verifiedPrivacyManifests"], 1)
        self.assertTrue(result["permissionDeclarationsVerified"])

    def test_rejects_simulator_platform_or_unexpected_background_mode(self):
        self._write_ipa(info_overrides={"DTPlatformName": "iphonesimulator"})
        with self.assertRaisesRegex(MODULE.VerificationError, "SDK platformu"):
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

        self._write_ipa(info_overrides={"UIBackgroundModes": ["audio"]})
        with self.assertRaisesRegex(MODULE.VerificationError, "background mode"):
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

    def test_rejects_missing_or_changed_localized_microphone_description(self):
        self._write_ipa(include_localizations=False)
        with self.assertRaisesRegex(MODULE.VerificationError, "localized mikrofon"):
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

        self._write_ipa(
            info_overrides={"NSMicrophoneUsageDescription": "Microphone required"}
        )
        with self.assertRaisesRegex(MODULE.VerificationError, "varsayilan mikrofon"):
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

    def test_rejects_embedded_tracking_or_malformed_required_reason_manifest(self):
        tracking = self._privacy_manifest() | {"NSPrivacyTracking": True}
        self._write_ipa(embedded_privacy_manifest=tracking)
        with self.assertRaisesRegex(MODULE.VerificationError, "tracking iceriyor"):
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

        malformed = self._privacy_manifest() | {
            "NSPrivacyAccessedAPITypes": [
                {"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults"}
            ]
        }
        self._write_ipa(embedded_privacy_manifest=malformed)
        with self.assertRaisesRegex(MODULE.VerificationError, "beyanı eksik"):
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

    def test_rejects_missing_or_simulator_architecture_evidence(self):
        self._write_ipa()
        missing = self._signature() | {"architectures": {}}
        with self.assertRaisesRegex(MODULE.VerificationError, "mimari bilgisi"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=lambda *_: missing,
            )

        simulator = self._signature() | {
            "architectures": {".": ["arm64", "x86_64"]}
        }
        with self.assertRaisesRegex(MODULE.VerificationError, "device-only arm64"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=lambda *_: simulator,
            )

    def test_rejects_simulator_or_incompatible_macho_platform(self):
        self._write_ipa()
        simulator = self._signature()
        simulator["platforms"] = {
            ".": {"platform": "IOSSIMULATOR", "minimumOS": "15.0"},
            "Frameworks/App.framework": {
                "platform": "IOS",
                "minimumOS": "13.0",
            },
        }
        with self.assertRaisesRegex(MODULE.VerificationError, "device IOS"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=lambda *_: simulator,
            )

        incompatible = self._signature()
        incompatible["platforms"] = {
            ".": {"platform": "IOS", "minimumOS": "15.0"},
            "Frameworks/App.framework": {
                "platform": "IOS",
                "minimumOS": "16.0",
            },
        }
        with self.assertRaisesRegex(MODULE.VerificationError, "daha yeni OS"):
            MODULE.verify_ipa(
                self.ipa,
                expected_app_id="com.mennansevim.vocalart",
                expected_name="Vocalart",
                expected_version="1.0.0",
                expected_build="2",
                expected_team_id="L3Z9U2B39K",
                provision_decoder=lambda _: self._profile(),
                signature_verifier=lambda *_: incompatible,
            )

    def test_rejects_missing_or_tracking_privacy_manifest(self):
        self._write_ipa(privacy_manifest=None)
        with self.assertRaisesRegex(MODULE.VerificationError, "PrivacyInfo"):
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

        tracking = self._privacy_manifest() | {"NSPrivacyTracking": True}
        self._write_ipa(privacy_manifest=tracking)
        with self.assertRaisesRegex(MODULE.VerificationError, "tracking=false"):
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

    def test_rejects_collected_data_or_wrong_required_reason(self):
        collected = self._privacy_manifest() | {
            "NSPrivacyCollectedDataTypes": [
                {"NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeName"}
            ]
        }
        self._write_ipa(privacy_manifest=collected)
        with self.assertRaisesRegex(MODULE.VerificationError, "veri toplama"):
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

        wrong_reason = self._privacy_manifest()
        wrong_reason["NSPrivacyAccessedAPITypes"][0][
            "NSPrivacyAccessedAPITypeReasons"
        ] = ["CA92.1"]
        self._write_ipa(privacy_manifest=wrong_reason)
        with self.assertRaisesRegex(MODULE.VerificationError, "C617.1"):
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
