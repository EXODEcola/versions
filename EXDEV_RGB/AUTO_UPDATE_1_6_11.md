# EXDEV RGB 1.6.11 — silent, unattended startup update contract

**Status: architecture + offline eligibility tests only. NOT integrated into the Windows app yet.** This repo contains update metadata and validation scripts, not the Electron app, installer or Native Engine source code. Do not advertise the 1.6.11 as Stable or silently install the prepared ZIP.

## User experience (default: automatic)

1. On Windows logon, launch one **canonical** EXDEV RGB process (single instance). Immediately check the stable channel, with a bounded timeout and no repeated download loops.
2. If offline, metadata is malformed, or the server offers an older/same version: **start the installed app normally**; never downgrade and never block lighting on network failure.
3. If a *newer, published, downloadable* release exists, stage it silently; validate its hash, archive contents and trusted publisher signature BEFORE privileged installation. A manifest alone is not sufficient authorization.
4. Safely checkpoint user settings and native RGB state, apply the complete update transactionally using the preinstalled Windows update service, verify the new executable/registry/native engine identity and start the updated app once. Preserve the active profile, ARGB/GPU/Corsair state and application settings. Preserve all previous user-selected shortcuts and startup preferences.
5. If download, signature, migration, health check or restart fails: rollback atomically to a known working package; preserve the original settings and launch the usable installed app. Record error details in a log. Display an unobtrusive status only for failures that require user action.
6. **No routine prompts**: no “Install”, “Continue”, “Repair”, confirmation dialog or per-update UAC prompt. Respect the user's configurable automatic update preference; default enabled.

## One-time privilege provisioning — Windows security boundary

The existing app lives under `C:\Program Files (x86)`, so a typical non-admin Electron process **cannot** replace its binaries there. Electron-builder per-machine NSIS updates usually require UAC; merely calling `quitAndInstall({isSilent:true})` does not remove the elevation requirement.

- Provision an **EXDEV RGB Update Service** during the first verified 1.6.11 installation with a single administrator-approved setup. No silent elevation bypass: installation of this privileged service requires explicit OS authorization once.
- Keep updater and Native RGB Engine separate; the update service may install **only** approved EXDEV RGB releases. It must not accept arbitrary user-provided paths, URLs, process commands or update packages from the UI.
- The elevated service binary and its updater policy must reside in administrator-protected directories and use hardened service configuration / restricted ACLs. Authenticate and authorize any IPC calls: an unprivileged user may request a *check for the approved Stable release*, never arbitrary privileged execution.
- Stage verified files under an access-controlled system location (e.g. `%ProgramData%\EXDEV RGB\Updates` with restrictive ACLs). Reject reparse-point/symlink attacks, traversal paths and package swaps. Do not execute packages from `Downloads`, user-writable folders or an untrusted temporary path.
- Enforce **trusted Authenticode publisher identity**, certificate-chain validity, trusted provenance, full SHA-256 integrity, fixed GitHub release source, `current` status and version monotonicity. HTTPS is required but insufficient by itself. A changed publisher or invalid signature must stop automatic elevated installation and require manual review.
- Updates to the privileged updater itself must be verified through the same or stronger trust policy. Never disable Windows UAC or weaken operating-system protections. Repair or new service provisioning may still need administrator consent.

Alternative for a future fully per-user package: per-user application updates can avoid UAC without a service, but do **not** silently downgrade security or relocate the existing machine-wide installation; retaining privileged native hardware access is a separate concern.

## Authoritative version and packaging

- Installed *EXE* version is authoritative. The Windows uninstall registry currently says **1.6.10**, but the actual executable is **1.6.8**. Log this drift and use the real executable for update comparison, not the stale registry entry.
- Existing Stable on GitHub is **1.6.0**; never downgrade the 1.6.8 automatically. The `v1.6.11` manifest is still `prepared` with `download.available=false`, so **do not install it**.
- Publish a **complete**, coherent 1.6.11 Windows installer/service/Native Engine bundle as an actual GitHub Release asset, not a partial overlay ZIP. Audit version resource, installer metadata, Uninstall registry, package manifest, running process and every Start Menu/Desktop/Run reference after installation.
- Preserve existing profile data in `%APPDATA%\exdev-rgb` (and any separately recognized locations), migrate versioned schemas and maintain reversible backups until post-install checks pass. No one-time permissions should be stored in plaintext user preferences.
- Never remove last-known-good 1.6.8 binaries before a verified 1.6.11 health check. No orphaned old process, duplicate service or stale executable path may remain active after success.

## Failure-safe acceptance tests

- Clean install: one UAC for the verified service setup; later update 1.6.11 -> next Stable without UAC, modal or installation button.
- Upgrade from 1.6.8 with Windows registry showing 1.6.10: the updater uses 1.6.8 as the actual binary version and migrates to 1.6.11; verifies all paths and versions after reboot.
- Cold boot with stable 1.6.0 currently advertised: 1.6.8 starts normally; no downgrade, no update loop and no user prompts.
- Prepared/nonexistent GitHub asset, corrupt ZIP, incorrect hash, untrusted signer, malformed metadata, downgrade, interrupted download, disk full and no Internet: no privileged install; old app remains available.
- Reboot or shutdown during update: journaled/staged transaction recovers without a half-installed 1.6.8/1.6.11 hybrid.
- Profile migration from the existing backup restores all four saved profiles and preferences; device protection (FAN LOCK) remains unchanged; two Corsair DIMMs are distinguished by channel, not by duplicate `DeviceLocator` values alone.
- User-deleted Desktop shortcut remains absent, existing shortcuts re-point to canonical executable; no duplicate Run entries; no visible CMD on boot.
- Service failure or insufficient privileges: no UAC loop. Show a single unobtrusive repair-needed notice; do not pretend silent installation succeeded.
- Logs show exactly: source version from binary, advertised version, signature, hash, install transaction ID, rollback state and launch outcome. Never log sensitive keys/tokens.

## Offline decision policy

`EXDEV_RGB/tools/update_eligibility.py` is a **pure eligibility test helper**. Its results do not authorize privileged execution. `python -m unittest discover -s EXDEV_RGB/tools/tests -v` covers wrong registry version, 1.6.0 not downgrading 1.6.8, prepared release denial, bad hashes, untrusted URLs and version comparisons.

Implementation remaining: Electron startup integration, privileged Windows Update Service, trusted publisher verification, installer transaction and cold-boot tests **require the application source tree and actual Windows installer sources**. This repository cannot by itself make the installed 1.6.8 auto-update.