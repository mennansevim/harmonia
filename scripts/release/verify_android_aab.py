#!/usr/bin/env python3
"""Fail-closed, read-only verification for a Vocalart Android App Bundle.

This validates a local AAB only. It does not upload, install, generate APKs or
prove Google Play acceptance. Debug signing is local evidence and requires an
explicit flag.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path, PurePosixPath
from typing import Callable

MAX_AAB_BYTES = 250_000_000
MAX_ENTRIES = 50_000
MAX_UNCOMPRESSED_BYTES = 1_000_000_000
EXPECTED_APP_ID = "com.mennansevim.vocalart"
EXPECTED_MIN_SDK = "24"
EXPECTED_TARGET_SDK = "36"
DEBUG_CERTIFICATE_DN = "C=US, O=Android, CN=Android Debug"
EXPECTED_PERMISSIONS = frozenset(
    {
        "android.permission.RECORD_AUDIO",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.VIBRATE",
        "android.permission.POST_NOTIFICATIONS",
        f"{EXPECTED_APP_ID}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
    }
)
BUNDLETOOL_VERSION = "1.18.3"
BUNDLETOOL_SHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
ANDROID_NS = "http://schemas.android.com/apk/res/android"


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


def verify_zip_contract(aab_path: Path) -> dict[str, int]:
    try:
        aab_size = aab_path.stat().st_size
    except OSError as error:
        raise VerificationError("AAB okunamadi") from error
    if not aab_path.is_file() or aab_size <= 0 or aab_size > MAX_AAB_BYTES:
        raise VerificationError("AAB dosya boyutu gecersiz")
    try:
        with zipfile.ZipFile(aab_path) as archive:
            entries = archive.infolist()
            if not entries or len(entries) > MAX_ENTRIES:
                raise VerificationError("AAB entry sayisi gecersiz")
            names: set[str] = set()
            folded_names: set[str] = set()
            total = 0
            for info in entries:
                path = PurePosixPath(info.filename)
                if (
                    not info.filename
                    or info.filename.startswith("/")
                    or "\\" in info.filename
                    or any(part in {"", ".", ".."} for part in path.parts)
                    or info.filename in names
                ):
                    raise VerificationError("AAB guvensiz veya duplicate path iceriyor")
                names.add(info.filename)
                folded_names.add(info.filename.casefold())
                mode = info.external_attr >> 16
                if stat.S_ISLNK(mode) or info.flag_bits & 0x1:
                    raise VerificationError("AAB symlink veya encrypted entry iceriyor")
                total += info.file_size
                if total > MAX_UNCOMPRESSED_BYTES:
                    raise VerificationError("AAB acilmis boyut sinirini asiyor")
            required = {
                "bundleconfig.pb",
                "base/manifest/androidmanifest.xml",
                "base/resources.pb",
                "base/dex/classes.dex",
                "meta-inf/manifest.mf",
            }
            if not required.issubset(folded_names):
                raise VerificationError("AAB temel Android girdileri eksik")
            if not any(
                name.startswith("base/lib/") and name.endswith("/libapp.so")
                for name in folded_names
            ):
                raise VerificationError("AAB Flutter release libapp.so icermiyor")
            signer_blocks = [
                name
                for name in folded_names
                if name.startswith("meta-inf/")
                and name.endswith((".rsa", ".dsa", ".ec"))
            ]
            signature_files = [
                name
                for name in folded_names
                if name.startswith("meta-inf/") and name.endswith(".sf")
            ]
            if len(signer_blocks) != 1 or len(signature_files) != 1:
                raise VerificationError("AAB JAR signer girdileri tek olmali")
    except zipfile.BadZipFile as error:
        raise VerificationError("AAB gecerli ZIP degil") from error
    return {
        "aabBytes": aab_size,
        "entries": len(entries),
        "uncompressedBytes": total,
    }


def parse_manifest(output: str) -> dict[str, object]:
    try:
        root = ET.fromstring(output)
    except ET.ParseError as error:
        raise VerificationError("AAB manifest XML okunamadi") from error
    if root.tag != "manifest":
        raise VerificationError("AAB manifest root gecersiz")
    uses_sdk = root.find("uses-sdk")
    if uses_sdk is None:
        raise VerificationError("AAB uses-sdk eksik")
    attr = lambda name: f"{{{ANDROID_NS}}}{name}"
    permissions = {
        node.get(attr("name"))
        for node in root.findall("uses-permission")
        if node.get(attr("name")) is not None
    }
    return {
        "appId": root.get("package"),
        "version": root.get(attr("versionName")),
        "build": root.get(attr("versionCode")),
        "minimumSdk": uses_sdk.get(attr("minSdkVersion")),
        "targetSdk": uses_sdk.get(attr("targetSdkVersion")),
        "permissions": permissions,
    }


def parse_certificate(output: str) -> dict[str, str]:
    if output.count("Signer #") != 1:
        raise VerificationError("AAB signer zinciri tek olmali")
    owner = re.search(r"^Owner: (.+)$", output, flags=re.MULTILINE)
    digest = re.search(
        r"^\s*SHA256:\s*((?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2})$",
        output,
        flags=re.MULTILINE,
    )
    if owner is None or digest is None:
        raise VerificationError("AAB signer sertifikasi okunamadi")
    return {
        "certificateDn": owner.group(1),
        "certificateSha256": digest.group(1).replace(":", "").lower(),
    }


def verify_launch_resources(outputs: dict[str, str]) -> None:
    required = {
        "launchColor": ("color/launch_background", "#f8f5ef", "#0f1022"),
        "iconColor": ("color/ic_launcher_background", "#f7e8d8"),
        "launchStyle": ("style/LaunchTheme", "sdk_version: 31"),
        "foreground": (
            "mipmap/ic_launcher_foreground",
            "density: 160",
            "density: 640",
        ),
    }
    for key, needles in required.items():
        output = outputs.get(key, "").lower()
        if any(needle.lower() not in output for needle in needles):
            raise VerificationError("AAB markali launch resource sozlesmesi eksik")


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


def verify_aab(
    aab_path: Path,
    *,
    expected_version: str,
    expected_build: str,
    allow_debug_signing: bool,
    expected_certificate_sha256: str | None = None,
    bundletool: str,
    java: str = "java",
    jarsigner: str = "jarsigner",
    keytool: str = "keytool",
    runner: CommandRunner = _run,
) -> dict[str, object]:
    archive = verify_zip_contract(aab_path)
    runner([java, "-jar", bundletool, "validate", "--bundle", str(aab_path)])
    manifest = parse_manifest(
        runner(
            [
                java,
                "-jar",
                bundletool,
                "dump",
                "manifest",
                "--bundle",
                str(aab_path),
                "--module",
                "base",
            ]
        )
    )
    if manifest["appId"] != EXPECTED_APP_ID:
        raise VerificationError("AAB applicationId uyusmuyor")
    if manifest["version"] != expected_version or manifest["build"] != expected_build:
        raise VerificationError("AAB surumu pubspec ile uyusmuyor")
    if manifest["minimumSdk"] != EXPECTED_MIN_SDK:
        raise VerificationError("AAB minimum SDK sozlesmesi bozuk")
    if manifest["targetSdk"] != EXPECTED_TARGET_SDK:
        raise VerificationError("AAB target SDK sozlesmesi bozuk")
    permissions = manifest["permissions"]
    if permissions != EXPECTED_PERMISSIONS:
        extra = sorted(permissions - EXPECTED_PERMISSIONS)
        missing = sorted(EXPECTED_PERMISSIONS - permissions)
        raise VerificationError(
            f"AAB izin sozlesmesi bozuk; extra={extra}, missing={missing}"
        )

    jar_output = runner([jarsigner, "-verify", str(aab_path)])
    if "jar verified." not in jar_output.lower():
        raise VerificationError("AAB JAR imzasi dogrulanmadi")
    signature = parse_certificate(
        runner(
            [
                keytool,
                "-J-Duser.language=en",
                "-J-Duser.country=US",
                "-printcert",
                "-jarfile",
                str(aab_path),
            ]
        )
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
        raise VerificationError("AAB sertifika SHA-256 uyusmuyor")

    resource_specs = {
        "launchColor": "color/launch_background",
        "iconColor": "color/ic_launcher_background",
        "launchStyle": "style/LaunchTheme",
        "foreground": "mipmap/ic_launcher_foreground",
    }
    resources = {
        key: runner(
            [
                java,
                "-jar",
                bundletool,
                "dump",
                "resources",
                "--bundle",
                str(aab_path),
                "--resource",
                resource,
                "--values",
            ]
        )
        for key, resource in resource_specs.items()
    }
    verify_launch_resources(resources)
    return {
        "status": "passed",
        **archive,
        **{key: value for key, value in manifest.items() if key != "permissions"},
        "permissions": sorted(permissions),
        **signature,
        "signingMode": "local-debug" if is_debug else "release",
        "bundletoolVersion": BUNDLETOOL_VERSION,
        "launchResourcesVerified": True,
    }


def _find_program(name: str) -> str:
    found = shutil.which(name)
    if found is None:
        raise VerificationError(f"gerekli arac bulunamadi: {name}")
    return found


def _find_bundletool(repo_root: Path, explicit: Path | None) -> str:
    candidates: list[Path] = []
    if explicit is not None:
        candidates.append(explicit)
    configured = os.environ.get("BUNDLETOOL_JAR")
    if configured:
        candidates.append(Path(configured))
    candidates.append(
        repo_root / "build/tools" / f"bundletool-all-{BUNDLETOOL_VERSION}.jar"
    )
    for candidate in candidates:
        if not candidate.is_file():
            continue
        try:
            digest_builder = hashlib.sha256()
            with candidate.open("rb") as source:
                while chunk := source.read(1024 * 1024):
                    digest_builder.update(chunk)
            digest = digest_builder.hexdigest()
        except OSError as error:
            raise VerificationError("bundletool okunamadi") from error
        if digest != BUNDLETOOL_SHA256:
            raise VerificationError("bundletool SHA-256 uyusmuyor")
        return str(candidate)
    raise VerificationError(
        f"bundletool-all-{BUNDLETOOL_VERSION}.jar bulunamadi; --bundletool gerekli"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("aab", type=Path)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--bundletool", type=Path)
    parser.add_argument("--allow-debug-signing", action="store_true")
    parser.add_argument("--expected-certificate-sha256")
    args = parser.parse_args()
    try:
        version, build = read_pubspec_version(args.pubspec)
        root = args.pubspec.resolve().parent
        result = verify_aab(
            args.aab,
            expected_version=version,
            expected_build=build,
            allow_debug_signing=args.allow_debug_signing,
            expected_certificate_sha256=args.expected_certificate_sha256,
            bundletool=_find_bundletool(root, args.bundletool),
            java=_find_program("java"),
            jarsigner=_find_program("jarsigner"),
            keytool=_find_program("keytool"),
        )
    except VerificationError as error:
        print(json.dumps({"status": "failed", "error": str(error)}, ensure_ascii=False))
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
