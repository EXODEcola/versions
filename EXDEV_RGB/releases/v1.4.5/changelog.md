# EXDEV RGB 1.4.5 — UI Polish & Automatic Startup Update

## Interface
- Polish global de la topbar, sidebar, Dashboard, Appareils, Éclairage, Profils, Surveillance et Paramètres.
- Centre de mises à jour enrichi.
- Toggle « Mises à jour automatiques » activé par défaut.

## Mise à jour automatique
- Vérification du canal Stable au lancement.
- Si une nouvelle version publiée est disponible, EXDEV RGB l annonce dans un overlay dédié.
- Téléchargement automatique après un court compte à rebours avec possibilité de reporter pour la session.
- Progression visible pendant le téléchargement et la vérification.
- L installateur est lancé en mode `/autoupdate` et démarre l installation sans clic supplémentaire après l élévation UAC.
- Redémarrage d EXDEV RGB après installation.

## Sécurité
- HTTPS et hôtes GitHub allowlistés.
- Empreinte SHA-256 obligatoire avant extraction.
- Manifest d intégrité de l installateur verrouillé.
- FAN LOCK conservé : aucun contrôle ventilateur, PWM ou pompe ajouté.

## Publication
Le canal `latest.json` ne doit pointer vers 1.4.5 qu une fois l asset GitHub Release réellement publié.
