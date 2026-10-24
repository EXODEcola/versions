#!/usr/bin/env python3
"""Fail-closed release metadata validation for EXDEV RGB (stdlib only).

Does not install software or change user files. A release is not promoted until
its real GitHub asset is accessible, has the recorded SHA-256, and is a ZIP.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from urllib.parse import urlparse
from zipfile import ZipFile, BadZipFile

VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
SHA_RE = re.compile(r"^[0-9a-fA-F]{64}$")
REPO = "EXODEcola/versions"


class ReleaseError(Exception):
    pass


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        raise ReleaseError(f"Cannot read valid JSON at {path}: {exc}") from exc


def semver(v: str) -> tuple[int, int, int]:
    if not isinstance(v, str) or not VERSION_RE.fullmatch(v):
        raise ReleaseError(f"Invalid numeric EXDEV RGB version: {v!r}")
    return tuple(int(p) for p in v.split("."))


def release_dir(root: Path, version: str) -> Path:
    semver(version)
    return root / "EXDEV_RGB" / "releases" / f"v{version}"


def check_hash_metadata(manifest: dict, base: Path) -> None:
    v = manifest["version"]
    asset = manifest.get("download") or {}
    checksum = asset.get("sha256", "")
    size = asset.get("size", 0)
    if not SHA_RE.fullmatch(str(checksum)) or not isinstance(size, int) or size <= 0:
        raise ReleaseError(f"v{v}: invalid archive sha256 or size")
    filename = asset.get("asset", "")
    if not filename.endswith(".zip") or Path(filename).name != filename:
        raise ReleaseError(f"v{v}: expected a safe .zip filename")
    checksum_file = base / manifest.get("checksum_file", "sha256.txt")
    if not checksum_file.exists():
        raise ReleaseError(f"v{v}: missing checksum file")
    rows = [line.split() for line in checksum_file.read_text(encoding="utf-8").splitlines() if line.strip()]
    # One release can publish both a minimal updater ZIP and a full ZIP.
    matches = [parts[0] for parts in rows if len(parts) == 2 and parts[1] == filename]
    if len(matches) != 1 or matches[0].upper() != checksum.upper():
        raise ReleaseError(f"v{v}: checksum file disagrees with manifest")


def validate(root: Path) -> str:
    latest = read_json(root / "EXDEV_RGB" / "latest.json")
    stable = read_json(root / "EXDEV_RGB" / "channels" / "stable.json")
    legacy = read_json(root / "EXDEV_RGB.json")
    index = read_json(root / "EXDEV_RGB" / "index.json")
    version = latest.get("latest", "")
    semver(version)
    if (stable.get("latest") != version or legacy.get("version") != version or
            latest.get("channel") != "stable" or stable.get("channel") != "stable"):
        raise ReleaseError("Stable channels and legacy updater disagree on version")
    expected = f"releases/v{version}/manifest.json"
    if latest.get("manifest") != expected or stable.get("manifest") != "../" + expected:
        raise ReleaseError("Stable channels point to different manifests")
    manifest = read_json(release_dir(root, version) / "manifest.json")
    if manifest.get("version") != version or manifest.get("status") != "current":
        raise ReleaseError("Stable manifest is not the published current release")
    download = manifest.get("download", {})
    if download.get("available") is not True or not download.get("url"):
        raise ReleaseError("Stable manifest has no available download URL")
    if legacy.get("download_url") != download.get("url"):
        raise ReleaseError("Legacy updater disagrees on download URL")
    if legacy.get("sha256", "").upper() != download.get("sha256", "").upper():
        raise ReleaseError("Legacy updater disagrees on SHA-256")
    if latest.get("manifest_url") != stable.get("manifest_url"):
        raise ReleaseError("Stable manifests do not share a canonical URL")
    check_hash_metadata(manifest, release_dir(root, version))
    current = []
    seen = set()
    for item in index.get("versions", []):
        v = item.get("version")
        semver(v)
        if v in seen:
            raise ReleaseError(f"Duplicate release version {v}")
        seen.add(v)
        if item.get("manifest") != f"releases/v{v}/manifest.json":
            raise ReleaseError(f"v{v}: non-canonical manifest path")
        m = read_json(release_dir(root, v) / "manifest.json")
        if m.get("version") != v:
            raise ReleaseError(f"v{v}: version in index differs from release manifest")
        # Old immutable release metadata may still say current; the index is
        # authoritative for historical superseded versions.
        if item.get("status") in {"current", "prepared"} and item.get("status") != m.get("status"):
            raise ReleaseError(f"v{v}: index status and active/prepared manifest disagree")
        if item.get("status") == "current":
            current.append(v)
        if item.get("status") == "prepared":
            if m.get("download", {}).get("available") or m.get("download", {}).get("url"):
                raise ReleaseError(f"v{v}: prepared version must not be distributed")
    if current != [version]:
        raise ReleaseError(f"Expected only {version} current, got {current}")
    return f"OK: stable {version}, {len(seen)} indexed versions, no premature promotion"


def verify_archive(path: Path, manifest: dict) -> str:
    download = manifest.get("download", {})
    if not path.is_file():
        raise ReleaseError(f"Archive missing: {path}")
    size = path.stat().st_size
    if size != download.get("size"):
        raise ReleaseError(f"Archive size mismatch: expected {download.get('size')}, got {size}")
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1048576), b""):
            h.update(block)
    if h.hexdigest().upper() != download.get("sha256", "").upper():
        raise ReleaseError("Archive SHA-256 mismatch: release must NOT be published")
    try:
        with ZipFile(path, "r") as z:
            if not z.namelist() or z.testzip() is not None:
                raise ReleaseError("Corrupt or empty ZIP")
            files = {p.replace("\\", "/").lower().split("/")[-1] for p in z.namelist()}
            # An official Windows package requires an actual application installer,
            # not only an updater patch or bare metadata.
            if "exdev_rgb_installer.exe" not in files:
                raise ReleaseError("Full release ZIP lacks EXDEV_RGB_INSTALLER.exe")
            for entry in z.namelist():
                p = entry.replace("\\", "/")
                if p.startswith("/") or ".." in p.split("/") or re.match(r"^[A-Za-z]:", p):
                    raise ReleaseError("Unsafe ZIP entry path")
    except BadZipFile as exc:
        raise ReleaseError(f"Not a valid ZIP: {exc}") from exc
    return f"Verified: {path.name}, {size} bytes, SHA-256 {h.hexdigest().upper()}"


def remote_release_asset(version: str, asset: str) -> str:
    return f"https://github.com/{REPO}/releases/download/v{version}/{asset}"


def verify_remote(root: Path, version: str) -> str:
    m = read_json(release_dir(root, version) / "manifest.json")
    if m.get("version") != version or m.get("status") not in {"prepared", "current"}:
        raise ReleaseError("Version not a valid prepared/current release")
    download = m.get("download") or {}
    if download.get("provider") != "github-release" or download.get("repository") != REPO:
        raise ReleaseError("Unknown release artifact source")
    url = remote_release_asset(version, download["asset"])
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / download["asset"]
        req = Request(url, headers={"User-Agent": "EXDEV-RGB-release-guard/1.0"})
        try:
            with urlopen(req, timeout=45) as response, path.open("wb") as dest:
                if urlparse(response.url).scheme != "https":
                    raise ReleaseError("Release redirected to non-HTTPS transport")
                while block := response.read(1048576):
                    dest.write(block)
                    if dest.tell() > download.get("size", 0):
                        raise ReleaseError("Remote archive larger than recorded size")
        except (HTTPError, URLError, TimeoutError) as exc:
            raise ReleaseError(f"Release asset is not downloadable ({url}): {exc}") from exc
        return verify_archive(path, m)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("action", choices=["validate", "verify-archive", "verify-remote"])
    p.add_argument("--root", type=Path, default=Path.cwd())
    p.add_argument("--version", help="Release version, e.g. 1.6.11")
    p.add_argument("--archive", type=Path, help="Local full release ZIP")
    args = p.parse_args(argv)
    try:
        if args.action == "validate":
            print(validate(args.root))
        else:
            if not args.version:
                raise ReleaseError("--version required")
            if args.action == "verify-remote":
                print(verify_remote(args.root, args.version))
            else:
                if not args.archive:
                    raise ReleaseError("--archive required")
                m = read_json(release_dir(args.root, args.version) / "manifest.json")
                print(verify_archive(args.archive, m))
    except ReleaseError as exc:
        print(f"EXDEV RGB RELEASE BLOCKED: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())