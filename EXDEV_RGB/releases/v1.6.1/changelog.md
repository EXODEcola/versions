# EXDEV RGB 1.6.1 — Per-DIMM RGB Zones + Safe SMBus

## RAM Corsair DDR5
- Chaque barrette physique est maintenant exposée séparément.
- Les Vengeance RGB DDR5 utilisent leurs 10 LED adressables.
- Trois modes statiques : **Unie**, **3 zones** (3 + 4 + 3 LED) et **Dégradé**.
- La prévisualisation du sélecteur de couleur reste fluide dans l’interface sans spammer le SMBus.
- Une seule trame RGB directe est envoyée par barrette lors de **Appliquer**.
- CRC-8, validation de la route physique SMBus et attente du bit BUSY après commit.
- Les effets matériels Corsair peuvent être appliqués à une seule barrette.

## Cibles indépendantes
- Barrette 1 et Barrette 2 peuvent être cochées séparément.
- D_LED1 et D_LED2 peuvent être cochés séparément.
- Le GPU est une cible distincte des câbles ARGB.

## GPU AORUS
- Le contrôle global RGB validé est conservé.
- Le protocole RGB Fusion 2 sait gérer plusieurs zones, mais l’option multi-zone reste volontairement désactivée par défaut en Stable jusqu’à validation sur la RX 9070 XT réelle.

## Sécurité
- FAN LOCK inchangé.
- Aucun contrôle ventilateur, PWM ou pompe ajouté.
- Manifeste SHA-256 interne recalculé et installateur recompilé.
