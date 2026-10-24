# EXDEV RGB 1.6.11 — kit de contrôle Windows

**État : contrôle préparatoire, PAS installateur 1.6.11.** Le dépôt `EXODEcola/versions` contient des manifestes et un garde-fou de publication, pas le code source Electron / moteur natif complet. GitHub n'annonce toujours officiellement que la Stable `1.6.0`. Les versions 1.6.8–1.6.11 sont en `prepared` ; la vraie release `v1.6.11` n'est pas encore distribuée.

## Étape 0 — NE RIEN EFFACER

Ne désinstallez PAS la 1.6.8 avant sauvegarde vérifiée. Ne supprimez pas `C:\Program Files (x86)\EXDEV RGB\Lib`, les services/pilotes Native Engine, ni les paramètres utilisateur. Ne lancez jamais un patch ZIP juste parce qu'un manifeste mentionne `1.6.11` : le ZIP doit avoir son SHA-256 et contenir un installateur utilisable.

## Étape 1 — diagnostiquer le PC actuel (lecture seule)

1. Extrayez ce kit dans un dossier de votre choix.
2. Ouvrez Windows PowerShell **ordinaire** (sans administrateur).
3. Exécutez :

```powershell
cd "$env:USERPROFILE\Downloads\EXDEV_RGB_1611_TEST_KIT"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\01_Audit_EXDEV_RGB.ps1
```

Remplacez le chemin du `cd` par le dossier réel. Le dossier `EXDEV_RGB_Diagnostics\<date>` sur le Bureau contient `audit.json` et `LIRE-MOI.txt`. Le script n'altère aucun service, pilote, tâche, programme, profil ou registre.

**À vérifier dans `audit.json` :** `Executables` et `Processes` (quel .exe tourne vraiment ?), `RegistryAutoruns`/`StartupShortcuts`/`ScheduledTasks` (anciens démarrages multiples), `ServicesAndDrivers` (PawnIO et moteur natif), `PhysicalDIMMs` (deux positions réellement distinctes), `SettingsDirectories`, `NativeLogs`. Le rapport peut contenir des chemins locaux : relisez-le avant partage.

## Étape 2 — sauvegarder les profils avant toute installation

Quittez complètement EXDEV RGB via la zone de notification, puis exécutez :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\02_Sauvegarde_Profils.ps1
```

Vérifiez l'existence du ZIP `EXDEV_RGB_Sauvegardes\EXDEV_RGB_profils_...zip` sur le Bureau. Il contient seulement les emplacements `%APPDATA%`/`%LOCALAPPDATA%` connus. Si l'application stocke ses préférences ailleurs, la sauvegarde est **incomplète** : ne désinstallez pas avant identification. Conservez une copie du ZIP sur un autre support.

## Étape 3 — vérifier le vrai package 1.6.11, lorsqu'il sera disponible

Téléchargez uniquement l'asset de la release officielle `EXODEcola/versions`, jamais un lien fabriqué. Le manifeste préparé annonce actuellement :

- nom : `EXDEV_RGB_v1.6.11_CANONICAL_STARTUP_FIX.zip`
- taille : `5966175` octets
- SHA-256 : `E1FF4F31D7DA73D6F514F61AFE9F559D11F4CC7985B1CA5865DA2E0881D48535`

À ce jour, **l'asset n'est pas publié**. Une fois l'archive réellement disponible :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\03_Verifier_Paquet_1611.ps1 -ZipPath "$env:USERPROFILE\Downloads\EXDEV_RGB_v1.6.11_CANONICAL_STARTUP_FIX.zip"
```

Ce script refuse une archive de mauvaise taille/empreinte ou privée de `EXDEV_RGB_INSTALLER.exe`. Il ne garantit pas qu'elle fonctionnera sous Windows : il faut impérativement exécuter ensuite les tests d'installation en personne. Une signature Authenticode valide est recommandée avant diffusion large.

## Étape 4 — recette du logiciel officiel (après livraison Windows)

| Test | Résultat attendu |
|---|---|
| Migration depuis **1.6.8** | Installation 1.6.11 **unique**, sans second ancien exécutable ou ancienne tâche applicative |
| Redémarrage complet Windows (pas simple relance) | Pas de fenêtre CMD, processus 1.6.11 unique, moteur Native prêt |
| Profil Gaming RGB | Profil, couleur, effet, luminosité, synchronisation et réglages restaurés |
| Deux barrettes Corsair `CMH32GX5M2B5200Z40` | Deux slots/identifiants physiques distincts, deux zones réellement modifiables ; jamais `Slot 1` deux fois |
| Driver / SMBus | Plus de `pawnio-driver-required` si pilote réellement actif ; sinon état de panne explicite, jamais fausse disponibilité |
| D_LED1 et D_LED2 | LED ARGB pilotables indépendamment, résultat réellement visible |
| AORUS Radeon RX 9070 XT | RGB modifiable sans toucher aux courbes de ventilation |
| FAN LOCK | Ventilation, PWM, NZXT Kraken et pompe exclus des commandes, quelle que soit l'interface |
| Profil personnalisé | Enregistrer, fermer, redémarrer, sélectionner : paramètres strictement préservés |
| Réparation | Ne recrée pas d'ancien raccourci/tâche ni ne remplace 1.6.11 par 1.6.8 |
| Désinstallation (seulement après sauvegarde) | Anciennes installations nettoyées, préférences conservées ou suppression explicitement proposée |
| Mise à jour | GitHub annonce une version seulement si le ZIP existe, correspond à son hash et peut être installé |
| UI | Aucun débordement, double carte fictive ou statut « connecté » trompeur ; tests 1280x720/1920x1080/2560x1440/49 pouces |

**Important** : une première vérification après lancement manuel n'est pas équivalente à un vrai test à froid au démarrage Windows. Conserver les logs natifs (`ram-smbus-debug.log`, `hardware-status.json`) si l'une des deux RAM reste inaccessible.

## Pour terminer effectivement la release

L'étape manquante est le **projet source complet** (Electron/React, installateur, Native Engine et bridge C++/autres sources). Aucun script de ce kit ne remplace cette compilation. Il faut obtenir ce dépôt/source ou ZIP source, modifier le code, construire le package Windows, exécuter les tests sur le PC concerné puis publier seulement après validation dans GitHub Releases.

## Étape complémentaire — Raccourcis Bureau après une mise à jour officielle

Consultez `EXDEV_RGB/DESKTOP_SHORTCUTS_1611.md`. Le script `05_Maintenir_Raccourcis_Bureau.ps1` vérifie en **aperçu seul** les raccourcis Bureau existants et les répare uniquement après installation vérifiée avec `-Apply`. Il sauvegarde les .lnk originaux et permet la restauration. **Il ne recrée jamais un raccourci volontairement supprimé et n'installe aucun binaire.** Cette procédure doit être intégrée et validée dans le futur installateur officiel; elle n'est pas automatique dans la 1.6.8 actuelle.

## Future 1.6.11 auto-update policy

Automatic updates without per-launch admin dialogs require the one-time administrator-approved installation of a secure EXDEV RGB Update Service. No such service is bundled by this metadata repository; the existing 1.6.8 install **will not** become self-updating from these scripts alone. After the actual native application build is provided, the installer must implement and test the contract in `EXDEV_RGB/AUTO_UPDATE_1_6_11.md` before publishing 1.6.11.
