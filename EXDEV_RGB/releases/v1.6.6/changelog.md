# EXDEV RGB 1.6.6 — Slot-Aware Dual-DIMM Recovery

## Dual DIMM
- Croise Windows SMBIOS `Win32_PhysicalMemory` avec les contrôleurs RGB Corsair réellement validés.
- Le profil matériel exact 2×16 Go sur AM5 utilise A2/B2 comme indices de récupération lecture-seule : `0x19` et `0x1B`.
- Un DIMM physique ne disparaît plus de l'interface uniquement parce que son contrôleur RGB n'a pas encore répondu.
- Les routes candidates sont validées par 0x43/0x44, bloc Device Info, CRC-8, VID Corsair, PID Vengeance et protocole >= 4 avant toute écriture.

## SMBus / PawnIO
- Mutex partagé corrigé : `Global\Access_SMBUS.HTP.Method`.
- Ouverture PawnIO prioritaire via `\\?\GLOBALROOT\Device\PawnIO`, avec fallback `\\.\PawnIO`.
- `ioctl_set_sleep_mode(2)` appliqué au module SmbusPIIX4.
- Scan standard aligné sur les implémentations Corsair DDR5 modernes : port PIIX4 primaire, adresses `0x18..0x1F`.
- L'alias `0x58..0x5F` n'est utilisé qu'en récupération ciblée si la route canonique ne valide pas.

## RGB
- Direct 10 LED conservé.
- 3 zones = 3 / 4 / 3 LED.
- Fallback WORD OpenRGB conservé.
- FAN LOCK inchangé.
