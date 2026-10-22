# EXDEV RGB 1.6.3 — Dual-DIMM Scan Hotfix

## Corsair Vengeance RGB DDR5
- Corrige le cas où une seule des deux barrettes apparaît alors que le kit comporte deux DIMM.
- Le scan de l'interface utilise désormais la même découverte multi-passes que le chemin d'écriture.
- Chaque route SMBus est revalidée en lecture seule avant d'être abandonnée.
- Trois essais maximum sur les signatures Corsair 0x43/0x44.
- Deux essais maximum sur le bloc Device Info + CRC.
- Temporisation de 10 ms entre les adresses, comme le détecteur Corsair DRAM d'OpenRGB.
- Jusqu'à cinq passes pour retrouver les deux DIMM avant d'exposer une topologie incomplète.

## RGB
- Le mode Direct 10 LED de la 1.6.2 est conservé.
- SMBUS_BLOCK_DATA puis fallback WORD OpenRGB.
- Aucun commit Static préalable.
- Unie / 3 zones / Dégradé restent indépendants par barrette.

## Sécurité
- Les retries supplémentaires sont en lecture seule.
- FAN LOCK inchangé.
- Aucun accès ventilateur, PWM ou pompe.
