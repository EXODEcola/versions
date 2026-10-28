"""Pure channel/rollback acceptance logic, NOT an update installer.

The Windows client/native updater must eventually enforce equivalent rules.
No network, filesystem modification, registry access, or elevation occurs here.
"""
from __future__ import annotations
from dataclasses import dataclass
import re

VERSION = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-beta\.(0|[1-9]\d*))?$")
CHANNELS = {"stable", "beta"}


def version_key(value: str) -> tuple[int, int, int, int, int]:
    m = VERSION.fullmatch(value)
    if m is None:
        raise ValueError(f"Unsupported version: {value!r}")
    major, minor, patch, beta_seq = m.groups()
    # SemVer: 1.6.14-beta.1 < 1.6.14 stable.
    return (int(major), int(minor), int(patch), 0 if beta_seq is not None else 1,
            int(beta_seq) if beta_seq is not None else 0)


@dataclass(frozen=True)
class Decision:
    allowed: bool
    action: str
    reason: str


def assess_transition(*, installed_version: str, installed_channel: str,
                      target_version: str, target_channel: str,
                      beta_opt_in: bool, trusted_asset: bool, signed_asset: bool,
                      backup_ready: bool, explicit_rollback: bool = False,
                      rollback_snapshot_compatible: bool = False,
                      unsigned_beta_confirmed: bool = False) -> Decision:
    """Decide only. Actual signature/hash checks & transactions live in Windows app."""
    if installed_channel not in CHANNELS or target_channel not in CHANNELS:
        return Decision(False, "blocked", "invalid-channel")
    try:
        current = version_key(installed_version)
        target = version_key(target_version)
    except ValueError:
        return Decision(False, "blocked", "invalid-version")
    if target_channel == "stable" and "-beta." in target_version:
        return Decision(False, "blocked", "prerelease-in-stable")
    if target_channel == "beta" and not beta_opt_in and not explicit_rollback:
        return Decision(False, "blocked", "beta-opt-in-required")
    if not trusted_asset:
        return Decision(False, "blocked", "unverified-release")
    if target_channel == "stable" and not signed_asset:
        return Decision(False, "blocked", "unsigned-stable")
    if target_channel == "beta" and not signed_asset and not unsigned_beta_confirmed:
        return Decision(False, "blocked", "unsigned-beta-confirmation-required")
    if target == current and target_channel == installed_channel and not explicit_rollback:
        return Decision(False, "up-to-date", "already-installed")
    # A channel toggle is NOT permission to rewrite installed binaries.
    if target < current and not explicit_rollback:
        return Decision(False, "blocked", "downgrade-needs-explicit-rollback")
    if target == current and target_channel != installed_channel and not explicit_rollback:
        return Decision(False, "blocked", "same-version-cross-channel-needs-explicit-action")
    if not backup_ready:
        return Decision(False, "blocked", "backup-required")
    if target < current or explicit_rollback:
        if not explicit_rollback:
            return Decision(False, "blocked", "downgrade-needs-explicit-rollback")
        if not rollback_snapshot_compatible:
            return Decision(False, "blocked", "rollback-snapshot-incompatible")
        return Decision(True, "restore", "explicit-restoration-from-trusted-package")
    return Decision(True, "upgrade", "signed-and-verified-or-explicit-beta")