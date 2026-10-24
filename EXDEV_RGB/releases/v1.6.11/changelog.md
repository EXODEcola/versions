# EXDEV RGB 1.6.11 — Canonical Windows Startup Fix

- Répare les anciennes entrées Windows `Run` dédiées à EXDEV qui lançaient des versions obsolètes après mise à jour.
- Migre les anciens raccourcis de démarrage EXDEV vers le chemin canonique de la nouvelle installation.
- Désactive seulement les tâches planifiées EXDEV applicatives obsolètes; ne touche pas à `EXDEV RGB Native Engine`.
- Priorité à l'installation canonique inscrite au registre Windows pour `app.setLoginItemSettings`.
- Ajout de diagnostics `launchExecutable` et `canonicalExecutable` dans `state:get`.
- Conservation de Boot Sequencer 1.6.10, Native Bridge Windows GUI, Corsair DDR5 10 LED/3 zones, SMBus et FAN LOCK.

**Statut prepared** : Windows logon et distribution binaire non validés. Ne pas avancer Stable sans fichier distant vérifié et test de redémarrage réel.
