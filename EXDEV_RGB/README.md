# EXDEV RGB — Update metadata

Ce dossier contient uniquement les métadonnées du système de mise à jour EXDEV RGB.

- `latest.json` : point d'entrée permanent pour le canal stable.
- `index.json` : historique des versions connues.
- `channels/stable.json` : version stable courante.
- `channels/beta.json` : canal bêta, désactivé tant qu'aucune bêta n'est publiée.
- `releases/vX.Y.Z/manifest.json` : métadonnées d'une version précise.
- `releases/vX.Y.Z/changelog.md` : notes de version.
- `releases/vX.Y.Z/sha256.txt` : empreinte du fichier distribué.

Les fichiers `.zip` / `.exe` ne sont volontairement pas stockés ici afin de garder le dépôt léger.
Ils doivent être distribués via GitHub Releases. `download.url` reste vide tant que l'asset n'a pas été publié.

Point d'entrée actuel :
`https://raw.githubusercontent.com/EXODEcola/versions/main/EXDEV_RGB/latest.json`
