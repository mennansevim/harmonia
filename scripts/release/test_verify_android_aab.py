#!/usr/bin/env python3

import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_android_aab.py")
SPEC = importlib.util.spec_from_file_location("verify_android_aab", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class VerifyAndroidAabTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.aab = self.root / "Vocalart.aab"
        self._write_aab()

    def tearDown(self):
        self.temp.cleanup()

    def _write_aab(self, extra_entries=None):
        entries = {
            "BundleConfig.pb": b"config",
            "base/manifest/AndroidManifest.xml": b"manifest",
            "base/resources.pb": b"resources",
            "base/dex/classes.dex": b"dex",
            "base/lib/arm64-v8a/libapp.so": b"app",
            "META-INF/MANIFEST.MF": b"manifest",
            "META-INF/DEBUG.SF": b"signature",
            "META-INF/DEBUG.RSA": b"certificate",
        }
        entries.update(extra_entries or {})
        with zipfile.ZipFile(self.aab, "w") as archive:
            for name, value in entries.items():
                archive.writestr(name, value)

    @staticmethod
    def _manifest(*, build="12", extra_permission=None):
        permissions = set(MODULE.EXPECTED_PERMISSIONS)
        if extra_permission:
            permissions.add(extra_permission)
        nodes = "".join(
            f'<uses-permission android:name="{permission}"/>'
            for permission in sorted(permissions)
        )
        return (
            f'<manifest xmlns:android="{MODULE.ANDROID_NS}" '
            f'package="{MODULE.EXPECTED_APP_ID}" android:versionName="1.0.0" '
            f'android:versionCode="{build}">'
            f'<uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36"/>'
            f"{nodes}</manifest>"
        )

    @staticmethod
    def _certificate(*, debug=True, digest="AA" * 32):
        owner = MODULE.DEBUG_CERTIFICATE_DN if debug else "CN=Vocalart Release"
        formatted = ":".join(digest[index : index + 2] for index in range(0, 64, 2))
        return "\n".join(
            [
                "Signer #1:",
                f"Owner: {owner}",
                "Certificate fingerprints:",
                f" SHA256: {formatted}",
            ]
        )

    @staticmethod
    def _resources():
        return {
            "color/launch_background": (
                "color/launch_background (default) #f8f5ef "
                "ui_mode_night: UI_MODE_NIGHT_NIGHT #0f1022"
            ),
            "color/ic_launcher_background": "color/ic_launcher_background #f7e8d8",
            "style/LaunchTheme": "style/LaunchTheme sdk_version: 31",
            "mipmap/ic_launcher_foreground": (
                "mipmap/ic_launcher_foreground density: 160 density: 640"
            ),
        }

    def _runner(self, *, manifest=None, certificate=None, resources=None):
        resource_outputs = resources or self._resources()

        def run(command):
            if "validate" in command:
                return "App Bundle information"
            if "manifest" in command:
                return manifest or self._manifest()
            if "resources" in command:
                resource = command[command.index("--resource") + 1]
                return resource_outputs[resource]
            if Path(command[0]).name == "jarsigner":
                return "jar verified."
            if Path(command[0]).name == "keytool":
                return certificate or self._certificate()
            raise AssertionError(command)

        return run

    def test_accepts_explicit_bounded_local_debug_bundle(self):
        result = MODULE.verify_aab(
            self.aab,
            expected_version="1.0.0",
            expected_build="12",
            allow_debug_signing=True,
            bundletool="bundletool.jar",
            runner=self._runner(),
        )
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["signingMode"], "local-debug")
        self.assertEqual(result["permissions"], sorted(MODULE.EXPECTED_PERMISSIONS))
        self.assertTrue(result["launchResourcesVerified"])

    def test_rejects_stale_version_or_extra_permission(self):
        with self.assertRaisesRegex(MODULE.VerificationError, "pubspec"):
            MODULE.verify_aab(
                self.aab,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=True,
                bundletool="bundletool.jar",
                runner=self._runner(manifest=self._manifest(build="9")),
            )
        with self.assertRaisesRegex(MODULE.VerificationError, "izin"):
            MODULE.verify_aab(
                self.aab,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=True,
                bundletool="bundletool.jar",
                runner=self._runner(
                    manifest=self._manifest(
                        extra_permission="android.permission.READ_MEDIA_AUDIO"
                    )
                ),
            )

    def test_debug_requires_flag_and_release_requires_expected_digest(self):
        with self.assertRaisesRegex(MODULE.VerificationError, "Debug"):
            MODULE.verify_aab(
                self.aab,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=False,
                bundletool="bundletool.jar",
                runner=self._runner(),
            )
        with self.assertRaisesRegex(MODULE.VerificationError, "beklentisi"):
            MODULE.verify_aab(
                self.aab,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=False,
                bundletool="bundletool.jar",
                runner=self._runner(certificate=self._certificate(debug=False)),
            )
        with self.assertRaisesRegex(MODULE.VerificationError, "uyusmuyor"):
            MODULE.verify_aab(
                self.aab,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=False,
                expected_certificate_sha256="bb" * 32,
                bundletool="bundletool.jar",
                runner=self._runner(certificate=self._certificate(debug=False)),
            )

    def test_rejects_unsafe_archive_or_missing_launch_contract(self):
        self._write_aab({"../escape": b"bad"})
        with self.assertRaisesRegex(MODULE.VerificationError, "path"):
            MODULE.verify_zip_contract(self.aab)

        self._write_aab()
        resources = self._resources()
        resources["color/launch_background"] = "color/launch_background #ffffff"
        with self.assertRaisesRegex(MODULE.VerificationError, "launch"):
            MODULE.verify_aab(
                self.aab,
                expected_version="1.0.0",
                expected_build="12",
                allow_debug_signing=True,
                bundletool="bundletool.jar",
                runner=self._runner(resources=resources),
            )

    def test_bundletool_is_hash_pinned(self):
        tool = self.root / f"bundletool-all-{MODULE.BUNDLETOOL_VERSION}.jar"
        tool.write_bytes(b"tampered")
        with self.assertRaisesRegex(MODULE.VerificationError, "SHA-256"):
            MODULE._find_bundletool(self.root, tool)


if __name__ == "__main__":
    unittest.main()
