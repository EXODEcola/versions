# EXDEV RGB - mises a jour depuis l'application

Depuis le client 1.6.13, les mises a jour Stable et Beta destinees aux utilisateurs sont installees depuis Parametres > Mises a jour, pas par des patchs ZIP telecharges a la main.

## Regles de publication

1. Compiler et tester la vraie version Windows (Electron + Native Engine), puis verifier l'identite du PE, pas seulement le registre Windows ou version.txt.
2. Publier le vrai installateur EXE dans une GitHub Release. Utiliser une prerelease pour Beta.
3. Verifier taille SHA-256 et URL de l'asset publie avant d'activer un canal.
4. Pour Stable, mettre a jour le manifest releases/ et latest.json apres la validation materielle et la signature ; ne jamais promouvoir une Beta par commodite.
5. Pour Beta, mettre a jour previews/ et channels/beta.json en gardant status=preview.
6. Tester la mise a jour depuis le bouton dans EXDEV RGB, puis le demarrage, les deux RAM Corsair, le GPU, D_LED1/D_LED2, les profils et le FAN LOCK.

## Client 1.6.13

- Le canal Stable / Beta est selectable et memorise.
- Le telechargement GitHub et les fichiers EXE sont verifies en taille et SHA-256 avant execution.
- Les retrogradations sont refusees. Les versions non publiees ne sont pas installables.
- Une Beta non signee exige une confirmation explicite dans l'application. Les fichiers Stable EXE non signes sont refuses.

## Limites a ne pas masquer

Le client 1.6.11 ne sait lire que le canal Stable. Son passage vers 1.6.13 necessite exceptionnellement un dernier installateur manuel. Les futures versions pourront etre gerees depuis l'interface.

Le systeme de mise a jour totalement silencieuse sans UAC recurrente necessite un service Windows securise, installe une fois et signe, qui n'est pas encore livre avec cette beta. FAN LOCK reste strictement protege.