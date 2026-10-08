# EXDEV RGB 1.4.4 — GitHub Auto Update Ready

Cette version devient le client permanent de mise à jour d’EXDEV RGB.

- Point d’entrée fixe : `EXDEV_RGB/latest.json`.
- Résolution du manifest versionné sous `EXDEV_RGB/releases/vX.Y.Z/manifest.json`.
- Support natif des assets GitHub Releases du dépôt `EXODEcola/versions`.
- SHA-256 obligatoire avant extraction et lancement de l’installateur.
- Hôtes, dépôt et chemins des manifests strictement allowlistés.
- Vérification automatique au démarrage et manuelle depuis Paramètres > Mises à jour.
- Aucun GitHub Actions requis pour le canal de mise à jour.

Le binaire de cette version n’est volontairement pas publié comme asset GitHub depuis cette opération. La prochaine version peut être distribuée en créant une Release `vX.Y.Z` avec l’archive correspondante, puis en mettant à jour les petits fichiers JSON du dépôt `versions`.
