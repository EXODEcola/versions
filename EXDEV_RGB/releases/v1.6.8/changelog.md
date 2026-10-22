# EXDEV RGB 1.6.8 — Boot-Safe RAM Discovery

## Inventaire RAM
- La présence physique des DIMM provient de SMBIOS et ne dépend plus du succès du scan RGB.
- Une barrette reste visible dans Appareils et Éclairage même si PawnIO/SMBus est occupé.
- Les états sont séparés : présent, RGB prêt, SMBus occupé ou RGB en récupération.

## Native Engine / SMBus
- Suppression du lancement d'un second bridge lorsque le Native Engine résident est seulement lent ou occupé.
- Le scan multi-passes relâche désormais le mutex global entre les passes.
- Les scans d'inventaire utilisent des fenêtres de verrou courtes et bornées.
- Le moteur conserve le mutex global Windows et la contrainte même-thread introduite en 1.6.7.
- Ports PIIX4 0 et 1 conservés.
- Routes 0x18-0x1F puis aliases 0x58-0x5F conservées.

## RGB
- Direct 10 LED conservé.
- 3 zones = 3 / 4 / 3 LED.
- fallback WORD OpenRGB conservé.
- FAN LOCK inchangé.
