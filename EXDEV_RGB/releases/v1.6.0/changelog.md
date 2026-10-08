# EXDEV RGB 1.6.0 — Premium Product UI + Updater Hardening

## Interface
- Nouvelle interface Premium Product UI.
- Dashboard, page Appareils et sélecteur de profils retravaillés.
- Boutons, chevrons, bordures, espacements, hover et états actifs harmonisés.

## Mise à jour GitHub
- Comparaison sémantique corrigée entre la version locale et le canal Stable.
- `local < latest` : mise à jour disponible.
- `local == latest` : logiciel à jour.
- `local > latest` : état **EN AVANCE**, sans rétrogradation automatique.
- Vérification single-flight : une seule requête réseau active à la fois.
- Cache court de 15 secondes pour éviter le spam GitHub.
- Notifications identiques dédupliquées et limitées.
- Vérification forcée disponible depuis le bouton manuel.
- Mise à jour automatique au lancement uniquement si le canal Stable annonce réellement une version plus récente.
- Vérification SHA-256 obligatoire avant installation.

## Matériel / sécurité
- Native Lighting Engine conservé.
- Corsair DDR5, ARGB Gigabyte et AORUS RX 9070 XT conservés.
- FAN LOCK inchangé : aucun contrôle ventilateur, PWM ou pompe ajouté.
