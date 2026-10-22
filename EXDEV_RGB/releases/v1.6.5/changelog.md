# EXDEV RGB 1.6.5 — SMBus Busy Recovery

## Cause identifiée
Le message `DeviceIoControl 0xA1B22104: The requested resource is in use` correspond à `EXECUTE_FN` de PawnIO et, sur `SmbusPIIX4.bin`, au cas où le contrôleur AMD SMBus reste occupé (`STATUS_DEVICE_BUSY`).

## Correctifs
- Les appels PawnIO `EXECUTE_FN` retentent uniquement `ERROR_BUSY` avec un backoff borné.
- Les erreurs CRC, périphérique absent, protocole invalide ou accès refusé ne sont pas masquées.
- Le scan Corsair utilise en priorité le Native Engine résident.
- Scan, zones RAM et effets RAM sont sérialisés dans une seule file native afin d'éviter une course interne EXDEV.
- Le scan dual-DIMM multi-passes reste actif.
- Le mode Direct Corsair protocole 4 reste `10 LED + RGB + CRC-8`.
- Le fallback WORD_DATA OpenRGB reste disponible si SMBUS_BLOCK_DATA est refusé.

## Sécurité
- 44/44 fichiers du manifeste de sécurité validés.
- FAN LOCK inchangé.
- Aucun accès ventilateur, PWM ou pompe.
