# EXDEV RGB 1.6.11 — official Windows release acceptance contract

**Release state: prepared, not shipped.** This repository holds version metadata only; the Windows app/Native Engine source and installed binary are not included here. No manifest is to be advanced until the real 1.6.11 installation package is built and tested on Windows.

## Install and startup — hard requirements

- One canonical installed application identified by the uninstall registry record (do not assume x86/x64 directory). One canonical per-user startup registration. No parallel EXDEV 1.6.8, boot tasks or Run entries launching stale executables.
- Stage a **full package** on the same volume, verify file hashes, close app and native processes safely, swap to the new version, health-check and only then discard stale application binaries. Preserve an immediately recoverable rollback copy until the new application has successfully started.
- Enumerate and migrate only **EXDEV RGB application startup** entries whose target is positively identified. Avoid touching the elevated `EXDEV RGB Native Engine` service/task when cleaning legacy launchers. Never delete unrelated vendor files.
- User profiles/prefs must remain in a version-independent user directory (for example `%APPDATA%\EXDEV RGB`); the update must not remove this directory. Make a timestamped backup of user data and record the exact schema version. Reopen a saved profile after migration; if migration/health checks fail, restore both binaries and settings.
- Persist, at minimum: custom profiles, active profile, LED/zone mappings, per-device effect, RGB colors and brightness, startup preferences, global synchronization settings, updater channel, display theme, device aliases, and hardware protection policies.
- Keep a full native Windows process: no visible console at boot, taskbar and system tray controls, one application instance, deterministic app <-> daemon startup, privilege checks for the native engine, no unexpected second RAM scan during profile restoration.
- Display independent status for **Detected**, **Native engine ready**, **RGB writable**, and **Applying**. Never represent SMBIOS-only Corsair RAM detection or `pawnio-driver-required` as RGB-controllable.
- On the user's 2x Corsair Vengeance DDR5 setup, identify DIMMs by distinct physical SMBIOS/SMBus slot and stable identity; do not render both as Slot 1. Avoid duplicate proxy devices. Respect real LED/zone configuration and perform a cold-boot check.
- `FAN LOCK` is a non-negotiable safety boundary: control RGB only. Do not read/write thermal regulation, fan PWM, pumps, NZXT/Kraken controls, CPU/GPU frequencies, voltages, firmware or OC interfaces.

## Design — EXDEV RGB Studio direction

Turn the current generic dashboard into a hardware lighting studio, keeping the EXDEV black/navy/violet brand without generic large welcome tiles or repetitive card grids.

1. **Lighting workspace (primary):** large visual device/zone topology; selectable motherboard ARGB headers, GPU, and independent Corsair DIMMs; device LED visualization reflecting actual editable zones. Right-hand effect inspector contains effect-specific controls, not decorative labels. Bottom timeline/layers allow custom effects only where hardware really supports them.
2. **Device inventory:** compact sortable hardware rows with separate capability/status, driver info, transport (SMBus/ARGB/AMD I²C), selected zone and last-write acknowledgement. Hardware errors become contextual diagnostics, never false green "Connecté" badges.
3. **Profiles:** dense, directly editable preset library with actual animation previews, favorite slots, import/export, duplication and last successful application. No oversized blank thumbnails.
4. **Home/diagnostics:** replace static hero with a useful single glance: live readiness, active profile, selected color/effect, hardware state, driver/engine, previous applied configuration, last failure and repair action.
5. **Settings/updates:** one canonical installed version, verified stable version, digital signature / hash, installation directory, updater logs, migration and rollback state. Show not-published development builds as "local build", not "Stable".

### UI quality gates

- Persistent navigation with compact/expanded mode; no duplicated actions or categories.
- Pixel-consistent 4/8 px spacing, typography levels, focus/keyboard support, genuine scroll confinement, no broken wrapping (e.g. current global sync caption), no microtext on 49-inch ultrawide or Windows scaling 125/150/200%.
- **Real** responsive behavior at 1280x720, 1920x1080, 2560x1440, and ultrawide; overlay/dropdown menus fit the viewport and scroll internally.
- Respect `prefers-reduced-motion` / Windows motion settings, and throttled animation/telemetry to avoid load from the GUI itself. Preserve existing functional native bridge rather than rewrite hardware drivers during visual work.

## Release gate (do not skip)

- Run `python EXDEV_RGB/tools/release_guard.py validate --root .` on every change to metadata.
- Build a complete Windows ZIP including `EXDEV_RGB_INSTALLER.exe`, native engine and all required assets; sign binaries when signing credentials are available, calculate SHA-256 and exact size.
- Test installer **clean install**, **upgrade 1.6.8 -> 1.6.11**, **reboot auto-start**, **profiles/settings preservation**, **uninstall/repair**, **rollback**, **two Corsair DIMMs**, GPU, D_LED1/D_LED2 and FAN LOCK on real hardware.
- Upload the actual ZIP to a GitHub Release asset, then run `python EXDEV_RGB/tools/release_guard.py verify-remote --root . --version 1.6.11` and require success before changing `EXDEV_RGB/latest.json`, `EXDEV_RGB/channels/stable.json` and `EXDEV_RGB.json`.
- Never point clients to a `prepared` manifest or claim an untested Windows build is a verified Stable update.