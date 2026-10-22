# EXDEV RGB 1.6.9 — Silent Native Engine

## Native Engine
- `EXDEV_RGB_BRIDGE.exe` est compilé avec le sous-système Windows GUI/background.
- La tâche planifiée `EXDEV RGB Native Engine` ne crée plus de fenêtre console au login.
- Le moteur HTTP local `127.0.0.1:47651` reste inchangé.
- Les appels one-shot utilisés par Electron restent compatibles avec stdout/stderr redirigés.

## Installation
- Suppression des pipes stdout/stderr pouvant se remplir pendant `npm` ou `electron-builder`.
- Les sorties sont redirigées vers des fichiers temporaires puis copiées dans `Lib/Logs/installer.log`.
- Cela évite le deadlock possible à l'étape Compilation vers 91 %.
- Le démarrage du moteur pendant la préparation est borné et invisible.

## Conservé
- Boot-Safe RAM Discovery.
- Dual-DIMM / PIIX4 ports 0 et 1.
- Direct 10 LED et 3 zones.
- Global SMBus mutex et FAN LOCK.
