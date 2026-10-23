# EXDEV RGB 1.6.10 — Boot Sequencer + Silent Native Engine

## Démarrage Windows
- Le renderer et `applySavedLighting()` partagent désormais **le même scan natif**.
- EXDEV attend que le Native Engine élevé soit joignable avant de sonder la RAM.
- Si SMBIOS annonce deux DIMM mais que le scan RGB en valide moins, EXDEV refait automatiquement plusieurs scans sur **le même daemon** avec backoff.
- Plus de second bridge PawnIO lancé simplement parce que la tâche planifiée est encore en train de démarrer.
- Le fallback one-shot n'est utilisé qu'après expiration complète de la fenêtre de démarrage du daemon.

## Native Engine
- `/v1/status` expose `engineReady` et `uptimeMs`.
- Les capacités RAM / ARGB / GPU sont retournées directement par le moteur résident.
- `EXDEV_RGB_BRIDGE.exe` reste un binaire Windows GUI/background : aucun CMD au login.

## RAM
- Conserve le chemin validé en 1.6.8 : dual DIMM, 10 LED par barrette, 3 zones 3/4/3.
- Conserve SMBus Block + fallback WORD.
- L'inventaire SMBIOS reste indépendant de l'état RGB.

## Sécurité
- 44/44 fichiers du manifeste interne validés.
- FAN LOCK inchangé.
- Aucun contrôle ventilateur, PWM, pompe ou NZXT.
