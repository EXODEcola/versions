# EXDEV RGB 1.6.4 — Installer + Dual-DIMM Fix

## Cause confirmée
Le package 1.6.3 contenait bien le scanner multi-passes et le bridge récents, mais l'interface d'installation conservait une ancienne version codée en dur (`1.6.1`). Une mise à jour depuis 1.6.1 pouvait donc considérer le runtime comme déjà courant et sauter sa reconstruction.

## Correctifs installateur
- La version est lue depuis `Lib/version.txt`.
- Le marqueur `Lib/AppRuntime/version.txt` doit correspondre à la version du package, sinon le runtime est reconstruit.
- Le badge de l'installateur utilise la version réelle du package.
- `/autoupdate` est transmis à l'interface via `-AutoStart`.

## Dual DIMM
- Le scanner multi-passes 1.6.3 est conservé.
- Ports PIIX4 0 et 1.
- Plages 0x58–0x5F et 0x18–0x1F.
- Retries signature + Device Info/CRC.
- Pacing 10 ms entre les adresses.
- Direct 10 LED et fallback WORD conservés.

## Sécurité
- 44/44 fichiers du manifeste de sécurité validés.
- FAN LOCK inchangé.
- Aucun accès ventilateur, PWM ou pompe.
