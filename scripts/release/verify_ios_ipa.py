#!/usr/bin/env python3
"""Fail-closed, read-only local verification for a Vocalart App Store IPA.

This does not upload, notarize, or replace installation on a physical device.
"""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import stat
import subprocess
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Callable

MAX_ENTRIES = 20_000
MAX_UNCOMPRESSED_BYTES = 1_000_000_000
MAX_PLIST_BYTES = 2_000_000


class VerificationError(RuntimeError):
    pass


def _required_text(mapping: dict, key: str) -> str:
    value = mapping.get(key)
    if not isinstance(value, str) or not value.strip():
        raise VerificationError(f"{key} eksik veya bos")
    return value.strip()


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


def _read_bounded(archive: zipfile.ZipFile, name: str, limit: int) -> bytes:
    info = archive.getinfo(name)
    if info.file_size > limit:
        raise VerificationError(f"{name} boyut sinirini asiyor")
    data = archive.read(name)
    if len(data) != info.file_size:
        raise VerificationError(f"{name} eksik okundu")
    return data


def decode_mobileprovision(data: bytes) -> dict:
    with tempfile.NamedTemporaryFile(suffix=".mobileprovision") as handle:
        handle.write(data)
        handle.flush()
        result = subprocess.run(
            ["/usr/bin/security", "cms", "-D", "-i", handle.name],
            check=False,
            capture_output=True,
        )
    if result.returncode != 0:
        raise VerificationError("embedded.mobileprovision dogrulanamadi")
    try:
        decoded = plistlib.loads(result.stdout)
    except Exception as error:
        raise VerificationError("provisioning profile plist okunamadi") from error
    if not isinstance(decoded, dict):
        raise VerificationError("provisioning profile sozluk degil")
    return decoded


def verify_codesign(
    archive: zipfile.ZipFile,
    app_root: str,
    expected_team_id: str,
    expected_app_id: str,
) -> dict:
    """Verify the extracted bundle's complete local code-signature chain."""
    with tempfile.TemporaryDirectory(prefix="vocalart-ipa-") as directory:
        try:
            archive.extractall(directory)
        except (OSError, zipfile.BadZipFile) as error:
            raise VerificationError("IPA gecici dogrulama icin acilamadi") from error
        app_path = Path(directory) / PurePosixPath(app_root)
        result = subprocess.run(
            [
                "/usr/bin/codesign",
                "--verify",
                "--deep",
                "--strict",
                "--verbose=2",
                str(app_path),
            ],
            check=False,
            capture_output=True,
        )
        if result.returncode != 0:
            raise VerificationError("IPA codesign --verify kapisindan gecemedi")
        details = subprocess.run(
            ["/usr/bin/codesign", "-dv", "--verbose=4", str(app_path)],
            check=False,
            capture_output=True,
            text=True,
        )
        signed_entitlements = subprocess.run(
            ["/usr/bin/codesign", "-d", "--entitlements", ":-", str(app_path)],
            check=False,
            capture_output=True,
        )
    if details.returncode != 0:
        raise VerificationError("IPA codesign kimligi okunamadi")
    if signed_entitlements.returncode != 0:
        raise VerificationError("IPA imzali entitlement bilgisi okunamadi")
    try:
        signed_entitlement_values = plistlib.loads(signed_entitlements.stdout)
    except Exception as error:
        raise VerificationError("IPA imzali entitlement plist okunamadi") from error
    if not isinstance(signed_entitlement_values, dict):
        raise VerificationError("IPA imzali entitlement bilgisi sozluk degil")
    lines = (details.stdout + details.stderr).splitlines()
    identifiers = [
        line.removeprefix("Identifier=")
        for line in lines
        if line.startswith("Identifier=")
    ]
    teams = [
        line.removeprefix("TeamIdentifier=")
        for line in lines
        if line.startswith("TeamIdentifier=")
    ]
    authorities = [
        line.removeprefix("Authority=")
        for line in lines
        if line.startswith("Authority=")
    ]
    if identifiers != [expected_app_id]:
        raise VerificationError("codesign application identifier uyusmuyor")
    if teams != [expected_team_id]:
        raise VerificationError("codesign TeamIdentifier uyusmuyor")
    if not authorities or not authorities[0].startswith("Apple Distribution:"):
        raise VerificationError("codesign Apple Distribution sertifikasi degil")
    return {
        "teamId": teams[0],
        "signingAuthority": authorities[0],
        "signedEntitlements": signed_entitlement_values,
    }


def verify_ipa(
    ipa_path: Path,
    *,
    expected_app_id: str,
    expected_name: str,
    expected_version: str,
    expected_build: str,
    expected_team_id: str,
    provision_decoder: Callable[[bytes], dict] = decode_mobileprovision,
    signature_verifier: Callable[[zipfile.ZipFile, str, str, str], dict] = verify_codesign,
    now: datetime | None = None,
) -> dict:
    if not ipa_path.is_file():
        raise VerificationError("IPA dosyasi bulunamadi")
    try:
        archive = zipfile.ZipFile(ipa_path)
    except (OSError, zipfile.BadZipFile) as error:
        raise VerificationError("IPA gecerli ZIP degil") from error

    with archive:
        entries = archive.infolist()
        if not entries or len(entries) > MAX_ENTRIES:
            raise VerificationError("IPA entry sayisi gecersiz")
        entry_names = [info.filename for info in entries]
        if len(entry_names) != len(set(entry_names)):
            raise VerificationError("IPA duplicate path iceriyor")
        total = 0
        for info in entries:
            path = PurePosixPath(info.filename)
            if path.is_absolute() or ".." in path.parts:
                raise VerificationError("IPA guvensiz path iceriyor")
            mode = info.external_attr >> 16
            if stat.S_ISLNK(mode):
                raise VerificationError("IPA symlink iceriyor")
            total += info.file_size
            if total > MAX_UNCOMPRESSED_BYTES:
                raise VerificationError("IPA acilmis boyut sinirini asiyor")

        # A normal path has three components; keep this explicit to avoid
        # accepting nested extensions as the main application.
        info_paths = [
            info.filename
            for info in entries
            if len(PurePosixPath(info.filename).parts) == 3
            and PurePosixPath(info.filename).parts[0] == "Payload"
            and PurePosixPath(info.filename).parts[1].endswith(".app")
            and PurePosixPath(info.filename).parts[2] == "Info.plist"
        ]
        if len(info_paths) != 1:
            raise VerificationError("IPA tam bir ana .app/Info.plist icermeli")
        info_path = info_paths[0]
        app_root = str(PurePosixPath(info_path).parent)
        try:
            app_info = plistlib.loads(
                _read_bounded(archive, info_path, MAX_PLIST_BYTES)
            )
        except Exception as error:
            if isinstance(error, VerificationError):
                raise
            raise VerificationError("Info.plist okunamadi") from error
        if not isinstance(app_info, dict):
            raise VerificationError("Info.plist sozluk degil")

        app_id = _required_text(app_info, "CFBundleIdentifier")
        if app_id != expected_app_id:
            raise VerificationError(f"bundle id beklenenden farkli: {app_id}")
        display_name = app_info.get("CFBundleDisplayName") or app_info.get(
            "CFBundleName"
        )
        if display_name != expected_name:
            raise VerificationError("uygulama adi beklenenden farkli")
        version = _required_text(app_info, "CFBundleShortVersionString")
        build = _required_text(app_info, "CFBundleVersion")
        if version != expected_version or build != expected_build:
            raise VerificationError(
                "IPA surumu pubspec ile uyusmuyor: "
                f"{version}+{build} != {expected_version}+{expected_build}"
            )
        executable = _required_text(app_info, "CFBundleExecutable")
        minimum_os = _required_text(app_info, "MinimumOSVersion")
        if app_info.get("ITSAppUsesNonExemptEncryption") is not False:
            raise VerificationError("sifreleme beyan anahtari false degil")

        required_entries = [
            f"{app_root}/{executable}",
            f"{app_root}/_CodeSignature/CodeResources",
            f"{app_root}/embedded.mobileprovision",
        ]
        names = set(archive.namelist())
        missing = [name for name in required_entries if name not in names]
        if missing:
            raise VerificationError("imzali IPA girdileri eksik: " + ", ".join(missing))

        provision = provision_decoder(
            _read_bounded(
                archive, f"{app_root}/embedded.mobileprovision", MAX_PLIST_BYTES
            )
        )
        entitlements = provision.get("Entitlements")
        if not isinstance(entitlements, dict):
            raise VerificationError("profile entitlement bilgisi eksik")
        application_identifier = _required_text(
            entitlements, "application-identifier"
        )
        if application_identifier != f"{expected_team_id}.{expected_app_id}":
            raise VerificationError("profile application-identifier uyusmuyor")
        team_identifiers = provision.get("TeamIdentifier")
        if team_identifiers != [expected_team_id]:
            raise VerificationError("profile TeamIdentifier uyusmuyor")
        if entitlements.get("com.apple.developer.team-identifier") != expected_team_id:
            raise VerificationError("profile entitlement team kimligi uyusmuyor")
        if entitlements.get("get-task-allow") is not False:
            raise VerificationError("profile App Store dagitim profili degil")
        if provision.get("ProvisionedDevices") or provision.get("ProvisionsAllDevices"):
            raise VerificationError("profile cihaz/ad-hoc/enterprise dagitimina ait")
        expiration = provision.get("ExpirationDate")
        if not isinstance(expiration, datetime):
            raise VerificationError("profile son kullanma tarihi eksik")
        current = now or datetime.now(timezone.utc)
        if expiration.tzinfo is None:
            expiration = expiration.replace(tzinfo=timezone.utc)
        if expiration <= current:
            raise VerificationError("provisioning profile suresi dolmus")

        signature = signature_verifier(
            archive, app_root, expected_team_id, expected_app_id
        )
        if not isinstance(signature, dict):
            raise VerificationError("codesign dogrulama kaniti eksik")
        if signature.get("teamId") != expected_team_id:
            raise VerificationError("codesign kanitindaki team kimligi uyusmuyor")
        signing_authority = signature.get("signingAuthority")
        if not isinstance(signing_authority, str) or not signing_authority.startswith(
            "Apple Distribution:"
        ):
            raise VerificationError("codesign kanitinda dagitim sertifikasi eksik")
        signed_entitlements = signature.get("signedEntitlements")
        if not isinstance(signed_entitlements, dict):
            raise VerificationError("codesign kanitinda entitlement bilgisi eksik")
        if signed_entitlements.get("application-identifier") != application_identifier:
            raise VerificationError("imzali application-identifier profile ile uyusmuyor")
        if (
            signed_entitlements.get("com.apple.developer.team-identifier")
            != expected_team_id
        ):
            raise VerificationError("imzali entitlement team kimligi uyusmuyor")
        if signed_entitlements.get("get-task-allow") is not False:
            raise VerificationError("imzali entitlement App Store dagitimina ait degil")

        return {
            "status": "passed",
            "artifact": ipa_path.name,
            "appId": app_id,
            "displayName": display_name,
            "version": version,
            "build": build,
            "minimumOS": minimum_os,
            "profileName": provision.get("Name", ""),
            "profileExpiresAt": expiration.isoformat(),
            "codeSignatureVerified": True,
            "teamId": signature["teamId"],
            "signingAuthority": signing_authority,
            "signedEntitlementsVerified": True,
            "note": "Yerel artifact kapisi; upload veya fiziksel cihaz kaniti degil.",
        }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--expected-app-id", default="com.mennansevim.vocalart")
    parser.add_argument("--expected-name", default="Vocalart")
    parser.add_argument("--expected-team-id", default="L3Z9U2B39K")
    parser.add_argument(
        "--pubspec",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "pubspec.yaml",
    )
    args = parser.parse_args()
    try:
        version, build = read_pubspec_version(args.pubspec)
        result = verify_ipa(
            args.ipa,
            expected_app_id=args.expected_app_id,
            expected_name=args.expected_name,
            expected_version=version,
            expected_build=build,
            expected_team_id=args.expected_team_id,
        )
    except VerificationError as error:
        print(json.dumps({"status": "failed", "error": str(error)}, ensure_ascii=False))
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
