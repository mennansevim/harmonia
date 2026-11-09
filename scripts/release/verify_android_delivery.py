#!/usr/bin/env python3
"""Materialize and verify a local universal APK from a Vocalart AAB.

This is a local delivery-parity check. It never installs or uploads anything,
and the generated universal APK is not a substitute for Play server/device QA.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import stat
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath
from typing import Callable


def _load_sibling(name: str):
    path = Path(__file__).with_name(f"{name}.py")
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"release verifier yuklenemedi: {name}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


aab_verifier = _load_sibling("verify_android_aab")
apk_verifier = _load_sibling("verify_android_apk")

MAX_APKS_BYTES = 300_000_000
MAX_UNIVERSAL_APK_BYTES = 250_000_000
MAX_ENTRIES = 10_000


class VerificationError(RuntimeError):
    pass


CommandRunner = Callable[[list[str]], str]


def _run(command: list[str]) -> str:
    try:
        completed = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            timeout=180,
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise VerificationError(f"arac calismadi: {Path(command[0]).name}") from error
    return completed.stdout + completed.stderr


def materialize_universal_apks(
    aab_path: Path,
    output_path: Path,
    *,
    bundletool: str,
    java: str,
    debug_keystore: Path,
    runner: CommandRunner = _run,
) -> None:
    if not debug_keystore.is_file():
        raise VerificationError("yerel Android debug keystore bulunamadi")
    runner(
        [
            java,
            "-jar",
            bundletool,
            "build-apks",
            "--bundle",
            str(aab_path),
            "--output",
            str(output_path),
            "--mode",
            "universal",
            "--ks",
            str(debug_keystore),
            "--ks-key-alias",
            "androiddebugkey",
            "--ks-pass",
            "pass:android",
            "--key-pass",
            "pass:android",
            "--overwrite",
        ]
    )


def extract_universal_apk(apks_path: Path, destination: Path) -> dict[str, int]:
    try:
        apks_size = apks_path.stat().st_size
    except OSError as error:
        raise VerificationError("APKS okunamadi") from error
    if not apks_path.is_file() or apks_size <= 0 or apks_size > MAX_APKS_BYTES:
        raise VerificationError("APKS dosya boyutu gecersiz")
    try:
        with zipfile.ZipFile(apks_path) as archive:
            entries = archive.infolist()
            if not entries or len(entries) > MAX_ENTRIES:
                raise VerificationError("APKS entry sayisi gecersiz")
            names: set[str] = set()
            for info in entries:
                path = PurePosixPath(info.filename)
                mode = info.external_attr >> 16
                if (
                    not info.filename
                    or info.filename.startswith("/")
                    or "\\" in info.filename
                    or any(part in {"", ".", ".."} for part in path.parts)
                    or info.filename in names
                    or stat.S_ISLNK(mode)
                    or info.flag_bits & 0x1
                ):
                    raise VerificationError("APKS guvensiz veya duplicate path iceriyor")
                names.add(info.filename)
            if "toc.pb" not in names or "universal.apk" not in names:
                raise VerificationError("APKS universal teslim girdileri eksik")
            universal = archive.getinfo("universal.apk")
            if (
                universal.file_size <= 0
                or universal.file_size > MAX_UNIVERSAL_APK_BYTES
            ):
                raise VerificationError("universal APK boyutu gecersiz")
            destination.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(universal) as source, destination.open("wb") as target:
                copied = 0
                while chunk := source.read(1024 * 1024):
                    copied += len(chunk)
                    if copied > MAX_UNIVERSAL_APK_BYTES:
                        raise VerificationError("universal APK boyut sinirini asti")
                    target.write(chunk)
            if copied != universal.file_size:
                raise VerificationError("universal APK eksik okundu")
    except zipfile.BadZipFile as error:
        raise VerificationError("APKS gecerli ZIP degil") from error
    return {
        "apksBytes": apks_size,
        "apksEntries": len(entries),
        "universalApkBytes": copied,
    }


def verify_parity(
    aab_result: dict[str, object], apk_result: dict[str, object]
) -> dict[str, object]:
    fields = (
        "appId",
        "version",
        "build",
        "minimumSdk",
        "targetSdk",
        "permissions",
        "certificateDn",
        "certificateSha256",
        "signingMode",
        "launchResourcesVerified",
    )
    mismatches = [field for field in fields if aab_result.get(field) != apk_result.get(field)]
    if mismatches:
        raise VerificationError(f"AAB-universal APK parity bozuk: {mismatches}")
    if aab_result.get("status") != "passed" or apk_result.get("status") != "passed":
        raise VerificationError("AAB ve universal APK ayri ayri gecmeli")
    return {field: apk_result[field] for field in fields}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("aab", type=Path)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--bundletool", type=Path)
    parser.add_argument(
        "--debug-keystore",
        type=Path,
        default=Path.home() / ".android/debug.keystore",
    )
    parser.add_argument("--allow-debug-signing", action="store_true")
    args = parser.parse_args()
    if not args.allow_debug_signing:
        print(
            json.dumps(
                {
                    "status": "failed",
                    "error": "yerel delivery kontrolu debug imza flag'i gerektirir",
                },
                ensure_ascii=False,
            )
        )
        return 1
    try:
        version, build = aab_verifier.read_pubspec_version(args.pubspec)
        root = args.pubspec.resolve().parent
        bundletool = aab_verifier._find_bundletool(root, args.bundletool)
        java = aab_verifier._find_program("java")
        aab_result = aab_verifier.verify_aab(
            args.aab,
            expected_version=version,
            expected_build=build,
            allow_debug_signing=True,
            bundletool=bundletool,
            java=java,
            jarsigner=aab_verifier._find_program("jarsigner"),
            keytool=aab_verifier._find_program("keytool"),
        )
        with tempfile.TemporaryDirectory(prefix="vocalart-delivery-") as temp:
            temp_root = Path(temp)
            apks_path = temp_root / "vocalart.apks"
            apk_path = temp_root / "universal.apk"
            materialize_universal_apks(
                args.aab,
                apks_path,
                bundletool=bundletool,
                java=java,
                debug_keystore=args.debug_keystore,
            )
            archive = extract_universal_apk(apks_path, apk_path)
            apk_result = apk_verifier.verify_apk(
                apk_path,
                expected_version=version,
                expected_build=build,
                allow_debug_signing=True,
                aapt=apk_verifier._find_build_tool("aapt", root),
                aapt2=apk_verifier._find_build_tool("aapt2", root),
                apksigner=apk_verifier._find_build_tool("apksigner", root),
            )
            parity = verify_parity(aab_result, apk_result)
    except (
        VerificationError,
        aab_verifier.VerificationError,
        apk_verifier.VerificationError,
    ) as error:
        print(json.dumps({"status": "failed", "error": str(error)}, ensure_ascii=False))
        return 1
    print(
        json.dumps(
            {
                "status": "passed",
                **archive,
                **parity,
                "deliveryMode": "local-universal-debug",
                "installed": False,
                "uploaded": False,
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
