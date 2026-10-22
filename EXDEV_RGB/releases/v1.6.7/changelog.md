# EXDEV RGB 1.6.7 — Thread-Safe SMBus + Multi-Port Dual-DIMM Fix

## Cause du verrou SMBus
Le mutex Windows `Global\Access_SMBUS.HTP.Method` appartient au thread qui l'acquiert. Une goroutine Go peut migrer entre threads Windows. EXDEV pouvait donc acquérir le mutex sur un thread puis appeler `ReleaseMutex` sur un autre, laissant son propre moteur bloquer le SMBus.

## Correctifs mutex
- `runtime.LockOSThread()` pendant toute la section critique SMBus.
- `WAIT_ABANDONED` accepté pour récupérer un verrou dont le propriétaire a disparu.
- retour de `ReleaseMutex` vérifié.
- attente bornée à 8 secondes sans boucle agressive.

## Dual DIMM AMD
- scan PIIX4 port 0 **et** port 1.
- plage canonique Corsair DDR5 `0x18..0x1F`.
- aliases `0x58..0x5F` en second passage.
- déduplication canonique/alias uniquement sur un même port.
- la même adresse sur deux ports différents reste deux routes potentielles.
- récupération ciblée SMBIOS sur les deux ports.
- affichage du slot basé prioritairement sur le module SMBIOS réellement associé.
- un DIMM présent mais RGB non validé reste visible comme diagnostic dans Éclairage.

## RGB
- Direct 10 LED conservé.
- 3 zones = 3 / 4 / 3 LED.
- fallback WORD OpenRGB conservé.
- FAN LOCK inchangé.
