# EXDEV RGB 1.6.0 — RAM Link Recovery Hotfix

- Restaure la liaison de contrôle RGB des RAM Corsair affectée depuis 1.4.5.
- Répare et redémarre EXDEV Native Engine si la tâche existe mais n est plus joignable.
- Valide réellement PawnIO + SmbusPIIX4 + Native Engine avant de déclarer le contrôle RAM prêt.
- Ajoute un fallback du moteur local vers le bridge direct.
- En cas d échec de mise à jour, l ancien EXDEV RGB est automatiquement relancé et restauré si nécessaire.
- Conserve l interface Premium Product UI 1.6.0.
