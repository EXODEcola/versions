#!/usr/bin/env python3
"""Pure, offline update eligibility gate for the future EXDEV RGB updater.

This module NEVER downloads, installs, elevates, or modifies Windows state.
The privileged Windows service must additionally verify package integrity and
publisher signature and complete atomic installation/rollback before launch.
"""
from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Any, Mapping

_REPOSITORY = "EXODEcola/versions"
_VERSION = re.compile(r"^\d+\.\d+\.\d+$")
_ASSET = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*\.zip$")
_SHA256 = re.compile(r"^[A-Fa-f0-9]{64}$")


@dataclass(frozen=True)
class Eligibility:
    should_update: bool
    reason: str
    installed_version: str
    latest_version: str | None
    registry_version_mismatch: bool


def _version(value: Any) -> tuple[int, int, int]:
    if not isinstance(value, str) or not _VERSION.fullmatch(value):
        raise ValueError("invalid version")
    return tuple(int(x) for x in value.split("."))


def _result(reason: str, installed: str, latest: str | None, drift: bool = False) -> Eligibility:
    return Eligibility(reason == "ready_for_verified_service_install", reason, installed, latest, drift)


def evaluate(
    installed_binary_version: str,
    latest_feed: Mapping[str, Any],
    release_manifest: Mapping[str, Any] | None,
    registry_version: str | None = None,
) -> Eligibility:
    """Reject stale/unpublished/unsafe releases without a prompt or downgrade.

    The installed *binary* version is authoritative: a stale Windows uninstall
    registry record must not stop a genuine newer, verified upgrade.
    The result is only ELIGIBILITY; it is never an instruction to elevate or
    execute downloaded bytes. Authenticode validation is done by the service.
    """
    try:
        installed = _version(installed_binary_version)
    except ValueError:
        return _result("invalid_installed_binary_version_manual_repair", installed_binary_version, None)
    drift = registry_version is not None and registry_version != installed_binary_version

    if latest_feed.get("product") != "EXDEV RGB" or latest_feed.get("channel") != "stable":
        return _result("untrusted_feed", installed_binary_version, None, drift)
    latest = latest_feed.get("latest")
    try:
        newest = _version(latest)
    except ValueError:
        return _result("invalid_remote_version", installed_binary_version, None, drift)

    if newest <= installed:
        return _result("up_to_date_or_remote_older_no_downgrade", installed_binary_version, latest, drift)

    if not release_manifest or (
        release_manifest.get("product") != "EXDEV RGB"
        or release_manifest.get("channel") != "stable"
        or release_manifest.get("status") != "current"
        or release_manifest.get("version") != latest
    ):
        return _result("not_published_or_manifest_mismatch", installed_binary_version, latest, drift)

    download = release_manifest.get("download")
    if not isinstance(download, Mapping) or download.get("available") is not True:
        return _result("asset_not_available", installed_binary_version, latest, drift)

    asset = download.get("asset")
    if not isinstance(asset, str) or not _ASSET.fullmatch(asset):
        return _result("unsafe_archive_name", installed_binary_version, latest, drift)
    trusted_url = f"https://github.com/{_REPOSITORY}/releases/download/v{latest}/{asset}"
    if (
        download.get("provider") != "github-release"
        or download.get("repository") != _REPOSITORY
        or download.get("tag") != f"v{latest}"
        or download.get("url") != trusted_url
    ):
        return _result("untrusted_release_source", installed_binary_version, latest, drift)
    if not _SHA256.fullmatch(str(download.get("sha256", ""))):
        return _result("invalid_sha256_metadata", installed_binary_version, latest, drift)
    if type(download.get("size")) is not int or download["size"] <= 0:
        return _result("invalid_archive_size", installed_binary_version, latest, drift)

    return _result("ready_for_verified_service_install", installed_binary_version, latest, drift)