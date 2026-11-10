#!/usr/bin/env python3
"""Fail-closed, read-only verification for a Vocalart Android APK.

This does not upload, install, or prove Play Console acceptance. A debug-signed
artifact is accepted only with an explicit local-only flag.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import zipfile
from pathlib import Path, PurePosixPath
from typing import Callable

MAX_APK_BYTES = 250_000_000
MAX_ENTRIES = 50_000
MAX_UNCOMPRESSED_BYTES = 1_000_000_000
EXPECTED_APP_ID = "com.mennansevim.vocalart"
EXPECTED_MIN_SDK = "24"
EXPECTED_TARGET_SDK = "36"
DEBUG_CERTIFICATE_DN = "C=US, O=Android, CN=Android Debug"
EXPECTED_PERMISSIONS = frozenset(
    {
        "android.permission.RECORD_AUDIO",
        "android.permission.INTERNET",
        "android.permission.CAMERA",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.VIBRATE",
        "android.permission.POST_NOTIFICATIONS",
        f"{EXPECTED_APP_ID}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
    }
)


class VerificationError(RuntimeError):
    pass


def read_pubspec_version(path: Path) -> tuple[str, str]:
    try:
        contents = path.read_text(encoding="utf-8")
    except OSError as error:
        raise VerificationError("pubspec.yaml okunamadi") from error
    matches = re.findall(
        r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$",
        contents,
        flags=re.MULTILINE,
    )
    if len(matches) != 1:
        raise VerificationError("pubspec version tek ve semver+build olmali")
    return matches[0]


def verify_zip_contract(apk_path: Path) -> dict[str, int]:
    try:
        apk_size = apk_path.stat().st_size
    except OSError as error:
        raise VerificationError("APK okunamadi") from error
    if not apk_path.is_file() or apk_size <= 0 or apk_size > MAX_APK_BYTES:
        raise VerificationError("APK dosya boyutu gecersiz")
    try:
        with zipfile.ZipFile(apk_path) as archive:
            entries = archive.infolist()
            if not entries or len(entries) > MAX_ENTRIES:
                raise VerificationError("APK entry sayisi gecersiz")
            names: set[str] = set()
            folded_names: set[str] = set()
            total = 0
            for info in entries:
                path = PurePosixPath(info.filename)
                folded = info.filename.casefold()
                if (
                    not info.filename
                    or info.filename.startswith("/")
                    or "\\" in info.filename
                    or any(part in {"", ".", ".."} for part in path.parts)
                    or info.filename in names
                ):
                    raise VerificationError("APK guvensiz veya duplicate path iceriyor")
                names.add(info.filename)
                folded_names.add(folded)
                mode = info.external_attr >> 16
                if stat.S_ISLNK(mode) or info.flag_bits & 0x1:
                    raise VerificationError("APK symlink veya encrypted entry iceriyor")
                total += info.file_size
                if total > MAX_UNCOMPRESSED_BYTES:
                    raise VerificationError("APK acilmis boyut sinirini asiyor")
            required = {"androidmanifest.xml", "resources.arsc", "classes.dex"}
            if not required.issubset(folded_names):
                raise VerificationError("APK temel Android girdileri eksik")
            if not any(
                name.startswith("lib/") and name.endswith("/libapp.so")
                for name in folded_names
            ):
                raise VerificationError("APK Flutter release libapp.so icermiyor")
    except zipfile.BadZipFile as error:
        raise VerificationError("APK gecerli ZIP degil") from error
    return {
        "apkBytes": apk_size,
        "entries": len(entries),
        "uncompressedBytes": total,
    }


def parse_badging(output: str) -> dict[str, object]:
    package = re.search(
        r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",
        output,
        flags=re.MULTILINE,
    )
    minimum = re.search(r"^sdkVersion:'([^']+)'$", output, flags=re.MULTILINE)
    target = re.search(r"^targetSdkVersion:'([^']+)'$", output, flags=re.MULTILINE)
    if package is None or minimum is None or target is None:
        raise VerificationError("aapt badging kimlik veya SDK bilgisi eksik")
    permissions = set(
        re.findall(
            r"^uses-permission: name='([^']+)'",
            output,
            flags=re.MULTILINE,
        )
    )
    return {
        "appId": package.group(1),
        "build": package.group(2),
        "version": package.group(3),
        "minimumSdk": minimum.group(1),
        "targetSdk": target.group(1),
        "permissions": permissions,
    }


def parse_signature(output: str) -> dict[str, str]:
    if "Verifies" not in output or not re.search(
        r"^Verified using v2 scheme .*: true$", output, flags=re.MULTILINE
    ):
        raise VerificationError("APK v2 imzasi dogrulanmadi")
    signers = re.search(r"^Number of signers: ([0-9]+)$", output, re.MULTILINE)
    dn = re.search(r"^Signer #1 certificate DN: (.+)$", output, re.MULTILINE)
    digest = re.search(
        r"^Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]{64})$",
        output,
        re.MULTILINE,
    )
    if signers is None or signers.group(1) != "1" or dn is None or digest is None:
        raise VerificationError("APK signer zinciri tek ve okunabilir degil")
    return {"certificateDn": dn.group(1), "certificateSha256": digest.group(1).lower()}


def verify_launch_resources(output: str) -> None:
    required = (
        "color/launch_background",
        "#fff8f5ef",
        "#ff0f1022",
        "style/LaunchTheme",
        "@mipmap/ic_launcher_foreground",
        "@color/ic_launcher_background",
    )
    if any(item not in output for item in required):
        raise VerificationError("APK markali launch resource sozlesmesi eksik")


CommandRunner = Callable[[list[str]], str]


def _run(command: list[str]) -> str:
    try:
        completed = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            timeout=120,
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise VerificationError(f"arac calismadi: {Path(command[0]).name}") from error
    return completed.stdout + completed.stderr


def verify_apk(
    apk_path: Path,
    *,
    expected_version: str,
    expected_build: str,
    allow_debug_signing: bool,
    expected_certificate_sha256: str | None = None,
    aapt: str = "aapt",
    aapt2: str = "aapt2",
    apksigner: str = "apksigner",
    runner: CommandRunner = _run,
) -> dict[str, object]:
    archive = verify_zip_contract(apk_path)
    badging = parse_badging(runner([aapt, "dump", "badging", str(apk_path)]))
    if badging["appId"] != EXPECTED_APP_ID:
        raise VerificationError("APK applicationId uyusmuyor")
    if badging["version"] != expected_version or badging["build"] != expected_build:
        raise VerificationError("APK surumu pubspec ile uyusmuyor")
    if badging["minimumSdk"] != EXPECTED_MIN_SDK:
        raise VerificationError("APK minimum SDK sozlesmesi bozuk")
    if badging["targetSdk"] != EXPECTED_TARGET_SDK:
        raise VerificationError("APK target SDK sozlesmesi bozuk")
    permissions = badging["permissions"]
    if permissions != EXPECTED_PERMISSIONS:
        extra = sorted(permissions - EXPECTED_PERMISSIONS)
        missing = sorted(EXPECTED_PERMISSIONS - permissions)
        raise VerificationError(
            f"APK izin sozlesmesi bozuk; extra={extra}, missing={missing}"
        )

    signature = parse_signature(
        runner([apksigner, "verify", "--verbose", "--print-certs", str(apk_path)])
    )
    is_debug = signature["certificateDn"] == DEBUG_CERTIFICATE_DN
    if is_debug and not allow_debug_signing:
        raise VerificationError("Android Debug sertifikasi magazaya uygun degil")
    expected_digest = (
        expected_certificate_sha256.lower()
        if expected_certificate_sha256 is not None
        else None
    )
    if not is_debug and expected_digest is None:
        raise VerificationError("release sertifika SHA-256 beklentisi gerekli")
    if expected_digest is not None and signature["certificateSha256"] != expected_digest:
        raise VerificationError("APK sertifika SHA-256 uyusmuyor")

    resources = runner([aapt2, "dump", "resources", str(apk_path)])
    verify_launch_resources(resources)
    return {
        "status": "passed",
        **archive,
        **{key: value for key, value in badging.items() if key != "permissions"},
        "permissions": sorted(permissions),
        **signature,
        "signingMode": "local-debug" if is_debug else "release",
        "launchResourcesVerified": True,
    }


def _find_build_tool(name: str, repo_root: Path) -> str:
    found = shutil.which(name)
    if found is not None:
        return found
    sdk_candidates: list[Path] = []
    for variable in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        value = os.environ.get(variable)
        if value:
            sdk_candidates.append(Path(value))
    local_properties = repo_root / "android/local.properties"
    if local_properties.is_file():
        for line in local_properties.read_text(encoding="utf-8").splitlines():
            if line.startswith("sdk.dir="):
                sdk_candidates.append(Path(line.removeprefix("sdk.dir=")))
    for sdk in sdk_candidates:
        tools = sorted((sdk / "build-tools").glob(f"*/{name}"), reverse=True)
        if tools:
            return str(tools[0])
    raise VerificationError(f"Android build tool bulunamadi: {name}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--allow-debug-signing", action="store_true")
    parser.add_argument("--expected-certificate-sha256")
    args = parser.parse_args()
    try:
        version, build = read_pubspec_version(args.pubspec)
        root = args.pubspec.resolve().parent
        result = verify_apk(
            args.apk,
            expected_version=version,
            expected_build=build,
            allow_debug_signing=args.allow_debug_signing,
            expected_certificate_sha256=args.expected_certificate_sha256,
            aapt=_find_build_tool("aapt", root),
            aapt2=_find_build_tool("aapt2", root),
            apksigner=_find_build_tool("apksigner", root),
        )
    except VerificationError as error:
        print(json.dumps({"status": "failed", "error": str(error)}, ensure_ascii=False))
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
