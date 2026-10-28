# EXDEV RGB — plan de diffusion Stable, Bêta et retour arrière

**But validé :** `1.6.13` devient la première version publique **Stable** dotée du choix Stable/Bêta, puis les développements suivants sont publiés exclusivement en Bêta jusqu'à validation. **État actuel (28 octobre 2026) : cet objectif n'est pas encore atteint** ; la seule 1.6.13 effectivement publiée est une *prérelease* (`v1.6.13-beta`), construite sans signature Windows et non validée sur les deux Corsair du PC utilisateur. Le manifeste Stable pointe toujours vers `1.6.0`. Ne pas modifier ces métadonnées avant validation.

## Règles produit

1. **Stable par défaut** : aucune notification ni téléchargement Bêta pour les utilisateurs Stable, aucune régression vers une ancienne version lorsque le canal est changé.
2. **Bêta sur opt-in explicite** : activation dans `Paramètres > Mises à jour`; choix mémorisé et réversible. Afficher un avertissement clair sur le risque matériel/profils; les Bêtas sont isolées dans le catalogue et ne changent jamais `latest.json` ou `channels/stable.json`.
3. **Versions distinctes** : après Stable `1.6.13`, publier des builds de développement par exemple `1.6.14-beta.1`, `1.6.14-beta.2`, puis `1.6.14` Stable après validation. Une version déjà installée ne doit jamais être confondue avec son étiquette de canal ; vérifier le numéro de version de l'exécutable et l'identité du paquet, pas seulement `version.txt` ou la valeur du registre Windows.
4. **Désactiver Bêta ≠ rétrograder** : revenir au canal Stable désactive la recherche des Bêtas, mais conserve le binaire installé s'il est plus récent que la Stable. Afficher « Version Bêta installée, Stable plus ancienne » et proposer séparément une restauration contrôlée.
5. **Retour arrière** : `Paramètres > Mises à jour > Historique et restauration`. Afficher les versions réellement *sauvegardées et vérifiées* ; bouton « Revenir à la version précédente » avec dialogue de confirmation et détails sur les profils. Interdire l'installation d'un ZIP arbitraire ou d'un binaire non vérifié.
6. **Transaction** : sauvegarder le runtime Windows, le moteur natif et les paramètres/schémas avant mise à jour; vérifier checksum et signature; installer sans toucher aux pompes/ventilateurs (FAN LOCK), faire des health checks (application 1.6.x réelle, daemon prêt, deux DIMMs correctement identifiées lorsque disponibles, profils restaurés), finaliser; sinon restaurer binaires **et** paramètres cohérents. Retenir une sauvegarde connue fonctionnelle et gérer l'espace disque.
7. **Sécurité** : Stable nécessite des binaires signés et testés ; une Bêta non signée exige confirmation explicite et ne doit jamais être auto-installée avec des privilèges élevés. Pour ne plus solliciter UAC à chaque version, terminer un service Windows de mise à jour à privilèges restreints et audité — aucune désactivation ou contournement d'UAC.

## Phase de lancement public 1.6.13

- [ ] Construire un paquet **Stable signé** à partir du code du système de mise à jour ; corriger les failles de privilèges et terminer les fonctions réelles de rollback (pas seulement les décisions).
- [ ] Tester sur Windows mise à jour depuis 1.6.11, réparation et redémarrage à froid : 2 Corsair Vengeance RGB, D_LED1/D_LED2, RX 9070 XT AORUS et protection FAN LOCK.
- [ ] Vérifier que le paquet peut être téléchargé et installé depuis l'ancienne 1.6.11 ou, si son ancien protocole ne permet pas de gérer le paquet 1.6.13, documenter **une seule installation de transition** et ne pas prétendre que l'ancienne interface peut déjà le faire.
- [ ] Publier `v1.6.13` **non-prerelease** avec un asset réellement disponible, signé, de taille et SHA-256 vérifiés ; ensuite uniquement avancer `EXDEV_RGB/releases/v1.6.13/manifest.json`, `latest.json`, `channels/stable.json`, `EXDEV_RGB.json` et l'index, en passant les garde-fous CI. Garder `v1.6.13-beta` isolée.
- [ ] Tester une future `1.6.14-beta.1` via l'interface opt-in et un retour vers la dernière version stable vérifiée, profils compris.

## État de réalisation

`EXDEV_RGB/tools/channel_transition_guard.py` est un **moteur de décision pur** avec tests unitaires (versions et canaux, opt-in, refus des rétrogradations implicites, signatures, confirmation Bêta, sauvegardes). Il n'effectue aucun rollback Windows et n'est pas encore raccordé au client Electron. **Ne pas annoncer le retour arrière comme déjà fonctionnel.**