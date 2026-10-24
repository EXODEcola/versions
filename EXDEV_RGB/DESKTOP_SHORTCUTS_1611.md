# EXDEV RGB 1.6.11 — Desktop shortcut contract

After the **verified** 1.6.11 Windows application has successfully been installed, the installer/updater must reconcile the user's pre-existing Windows shortcuts. The helper `tools/windows/05_Maintenir_Raccourcis_Bureau.ps1` is a standalone, manually available migration utility, not proof that the native installer already invokes it.

- Scan the user's actual/redirected Windows Desktop and Public Desktop `.lnk` files; **never assume** `C:\Users\...\Desktop` (OneDrive redirection is possible).
- If a desktop shortcut targets a recognizable EXDEV RGB executable, retarget the **same shortcut** to the canonical verified installation's `EXDEV RGB.exe`, set a valid working directory and repair its icon if the icon was EXDEV-owned.
- Preserve shortcut name, description, hotkey, placement, and unrelated custom icons. Prevent stale Electron/Companion command-line arguments from leaking into the new app.
- Never recreate a shortcut when none exists: the user may have deliberately removed it. New installations may offer an explicit `Create desktop shortcut` opt-in, distinct from migration.
- Preserve unrelated shortcuts, including coincidentally named shortcuts to a different application. Also avoid changing Start menu or pinned Taskbar shortcuts by guessing their physical files. They require their own validated installation-time handling.
- Back up original `.lnk` content (SHA-256) and create a JSON rollback manifest **before** writing; support restoration, verify that a shortcut has not been modified by another program since the migration, and do not write when the installed canonical executable is absent.
- Use a least-privilege user context for the user's Desktop; changes to Public Desktop may require administrator consent. If permission is denied, keep original shortcuts and report the incomplete operation.
- A release acceptance test must cover upgrade 1.6.8 → 1.6.11, redirected Desktop, existing/missing shortcuts, version rollback, old icon path removal, manual custom icon preservation, and successive 1.6.11 → future version upgrades.

## Preview (safe, no changes)

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\05_Maintenir_Raccourcis_Bureau.ps1
```

## Apply **only after** official application upgrade succeeds

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\05_Maintenir_Raccourcis_Bureau.ps1 -Apply
```

Run with `-Restore -BackupFile <path-to-shortcuts-backup.json>` to restore from the verified backup if necessary.

**Do not run `-Apply` on the current 1.6.8 executable thinking it will install 1.6.11.** This helper changes `.lnk` targets only; it does not modify application binaries or GitHub update manifests.