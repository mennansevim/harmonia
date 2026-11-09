#!/usr/bin/env python3

import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_android_apk.py")
SPEC = importlib.util.spec_from_file_location("verify_android_apk", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class VerifyAndroidApkTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.apk = self.root / "Vocalart.apk"
        self._write_apk()

    def tearDown(self):
        self.temp.cleanup()

    def _write_apk(self, extra_entries=None):
        entries = {
            "AndroidManifest.xml": b"manifest",
            "resources.arsc": b"resources",
            "classes.dex": b"dex",
            "lib/arm64-v8a/libapp.so": b"app",
            "lib/arm64-v8a/libflutter.so": b"flutter",
        }
        entries.update(extra_entries or {})
        with zipfile.ZipFile(self.apk, "w") as archive:
            for name, value in entries.items():
                archive.writestr(name, value)

    def _badging(self, *, version="1.0.0", build="12", extra_permission=None):
        permissions = set(MODULE.EXPECTED_PERMISSIONS)
        if extra_permission:
            permissions.add(extra_permission)
        lines = [
            "package: name='com.mennansevim.vocalart' "
            f"versionCode='{build}' versionName='{version}'",
            "sdkVersion:'24'",
            "targetSdkVersion:'36'",
        ]
        lines.extend(
            f"uses-permission: name='{permission}'" for permission in sorted(permissions)
        )
        return "\n".join(lines)

    @staticmethod
    def _signature(*, debug=True, digest="a" * 64, v2=True):
        dn = MODULE.DEBUG_CERTIFICATE_DN if debug else "CN=Vocalart Release"
        return "\n".join(
            [
                "Verifies",
                f"Verified using v2 scheme (APK Signature Scheme v2): {str(v2).lower()}",
                "Number of signers: 1",
                f"Signer #1 certificate DN: {dn}",
                f"Signer #1 certificate SHA-256 digest: {digest}",
            ]
        )

    @staticmethod
    def _resources():
        return " ".join(
            [
                "color/launch_background",
                "#fff8f5ef",
                "#ff0f1022",
                "style/LaunchTheme",
                "@mipmap/ic_launcher_foreground",
                "@color/ic_launcher_background",
            ]
        )

    def _runner(self, *, badging=None, signature=None, resources=None):
        outputs = {
            "aapt": badging or self._badging(),
            "apksigner": signature or self._signature(),
            "aapt2": resources or self._resources(),
        }

        def run(command):
            return outputs[command[0]]

        return run

    def test_accepts_bounded_local_debug_artifact_only_when_explicit(self):
        result = MODULE.verify_apk(
            self.apk,
            expected_version="1.0.0",
            expected_build="12",
            allow_debug_signing=True,
            runner=self._runner(),
        )
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["signingMode"], "local-debug")
        self.assertEqual(result["permissions"], sorted(MODULE.EXPECTED_PERMISSIONS))
        self.assertTrue(result["launchResourcesVerified"])

    def test_rejects_stale_version_or_extra_permission(self):
        with self.assertRaisesRegex(MODULE.VerificationError, "pubspec"):
            MODULE.verify_apk(
                self.apk,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=True,
                runner=self._runner(badging=self._badging(build="9")),
            )
        with self.assertRaisesRegex(MODULE.VerificationError, "izin"):
            MODULE.verify_apk(
                self.apk,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=True,
                runner=self._runner(
                    badging=self._badging(
                        extra_permission="android.permission.READ_MEDIA_AUDIO"
                    )
                ),
            )

    def test_debug_requires_flag_and_release_requires_expected_digest(self):
        with self.assertRaisesRegex(MODULE.VerificationError, "Debug"):
            MODULE.verify_apk(
                self.apk,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=False,
                runner=self._runner(),
            )
        with self.assertRaisesRegex(MODULE.VerificationError, "beklentisi"):
            MODULE.verify_apk(
                self.apk,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=False,
                runner=self._runner(signature=self._signature(debug=False)),
            )
        with self.assertRaisesRegex(MODULE.VerificationError, "uyusmuyor"):
            MODULE.verify_apk(
                self.apk,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=False,
                expected_certificate_sha256="b" * 64,
                runner=self._runner(signature=self._signature(debug=False)),
            )

    def test_rejects_unsafe_archive_or_missing_launch_contract(self):
        self._write_apk({"../escape": b"bad"})
        with self.assertRaisesRegex(MODULE.VerificationError, "path"):
            MODULE.verify_zip_contract(self.apk)

        self._write_apk()
        with self.assertRaisesRegex(MODULE.VerificationError, "launch"):
            MODULE.verify_apk(
                self.apk,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=True,
                runner=self._runner(resources="style/LaunchTheme"),
            )

    def test_pubspec_version_is_strict(self):
        pubspec = self.root / "pubspec.yaml"
        pubspec.write_text("name: vocalart\nversion: 1.0.0+12\n", encoding="utf-8")
        self.assertEqual(MODULE.read_pubspec_version(pubspec), ("1.0.0", "12"))
        pubspec.write_text("version: latest\n", encoding="utf-8")
        with self.assertRaises(MODULE.VerificationError):
            MODULE.read_pubspec_version(pubspec)


if __name__ == "__main__":
    unittest.main()
