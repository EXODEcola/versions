# EXDEV RGB 1.6.2 — Corsair DDR5 Direct Hotfix

## RAM Corsair Vengeance RGB DDR5
- Suppression du commit d'effet **Static** avant une écriture Direct.
- Le mode Direct suit maintenant le comportement OpenRGB : envoi immédiat de la trame LED sans sauvegarde préalable dans le contrôleur.
- Trame protocole 4 : `LED count + 10 × RGB + CRC-8` = 32 octets.
- Tentative `SMBUS_BLOCK_DATA` sur le registre `0x31`.
- Fallback `SMBUS_WORD_DATA` avec le codage `0x90/0xA0` utilisé par OpenRGB lorsque les block writes sont indisponibles.
- Le verrou SMBus et la sélection du port PIIX4 restent actifs.
- L'interface affiche maintenant la route qui échoue et le chemin d'écriture utilisé.

## Sécurité
- FAN LOCK inchangé.
- Aucun accès ventilateur, PWM ou pompe.
- Manifeste de sécurité interne recalculé et installateur recompilé.
