#!/usr/bin/env python3

import importlib.util
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_android_delivery.py")
sys.path.insert(0, str(SCRIPT.parent))
SPEC = importlib.util.spec_from_file_location("verify_android_delivery", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class VerifyAndroidDeliveryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.apks = self.root / "delivery.apks"
        self.destination = self.root / "out/universal.apk"

    def tearDown(self):
        self.temp.cleanup()

    def _write_apks(self, extra_entries=None, include_universal=True):
        entries = {"toc.pb": b"toc"}
        if include_universal:
            entries["universal.apk"] = b"apk-bytes"
        entries.update(extra_entries or {})
        with zipfile.ZipFile(self.apks, "w") as archive:
            for name, value in entries.items():
                archive.writestr(name, value)

    @staticmethod
    def _result(**changes):
        result = {
            "status": "passed",
            "appId": "com.mennansevim.vocalart",
            "version": "1.0.0",
            "build": "12",
            "minimumSdk": "24",
            "targetSdk": "36",
            "permissions": ["android.permission.RECORD_AUDIO"],
            "certificateDn": "C=US, O=Android, CN=Android Debug",
            "certificateSha256": "a" * 64,
            "signingMode": "local-debug",
            "launchResourcesVerified": True,
        }
        result.update(changes)
        return result

    def test_extracts_only_bounded_universal_apk(self):
        self._write_apks()
        result = MODULE.extract_universal_apk(self.apks, self.destination)
        self.assertEqual(self.destination.read_bytes(), b"apk-bytes")
        self.assertEqual(result["universalApkBytes"], 9)
        self.assertEqual(result["apksEntries"], 2)

    def test_rejects_unsafe_or_incomplete_apks(self):
        self._write_apks({"../escape": b"bad"})
        with self.assertRaisesRegex(MODULE.VerificationError, "path"):
            MODULE.extract_universal_apk(self.apks, self.destination)
        self._write_apks(include_universal=False)
        with self.assertRaisesRegex(MODULE.VerificationError, "eksik"):
            MODULE.extract_universal_apk(self.apks, self.destination)

    def test_accepts_exact_aab_apk_parity(self):
        result = MODULE.verify_parity(self._result(), self._result())
        self.assertEqual(result["build"], "12")
        self.assertEqual(result["signingMode"], "local-debug")

    def test_rejects_permission_or_certificate_drift(self):
        with self.assertRaisesRegex(MODULE.VerificationError, "permissions"):
            MODULE.verify_parity(
                self._result(),
                self._result(permissions=["android.permission.READ_MEDIA_AUDIO"]),
            )
        with self.assertRaisesRegex(MODULE.VerificationError, "certificate"):
            MODULE.verify_parity(
                self._result(), self._result(certificateSha256="b" * 64)
            )

    def test_rejects_non_passing_inputs(self):
        with self.assertRaisesRegex(MODULE.VerificationError, "ayri ayri"):
            MODULE.verify_parity(self._result(status="failed"), self._result())


if __name__ == "__main__":
    unittest.main()
