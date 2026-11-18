# V1.5 — abonnements et corrections du 20 octobre 2026

## Installation et publication

Décompressez ce paquet hors du projet et ouvrez un terminal dans le dossier obtenu :

```bat
python installer_maj.py "C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp"
```

L’installateur sauvegarde les fichiers remplacés dans un dossier voisin, conserve votre catalogue, les couvertures existantes et les paramètres personnalisés, ajoute les trois nouvelles photos et reconstruit le site. Il inclut le correctif Pillow/Vercel déjà livré.

Puis, depuis le dossier habituel du projet :

```bat
git add .
git commit -m "V1.5 - abonnements, photos et librairies"
git push
```

Vercel : commande `npm run build`, sortie `dist`. Le bandeau de version du pied de page affiche V1.5.0. Pour domaine et Brevo, les procédures de `DEPLOIEMENT_V1.4.md` restent applicables.

## Abonnements

Le document « formule abonnement.docx » remplace l’ancienne présentation. Les cinq paragraphes d’introduction sont repris ; les commentaires de stratégie commerciale et les idées de bonus ne sont pas des textes destinés aux visiteurs.

| Pack | Livres | Éco : 2 envois de 3 | Équilibre : 3 envois de 2 | Plaisir : 6 envois individuels |
|---|---|---:|---:|---:|
| Découverte | Rimbaud + Hugo à 9 €, plus quatre titres à 15 € : 78 € | 92 € | 99 € | 105 € |
| Passion | Six titres à 15 € : 90 € | 104 € | 111 € | 117 € |
| Frais de port en France, Lettre suivie | | 14 € | 21 € | 27 € |

Pour respecter le montant de 78 €, Découverte inclut les deux livres à 9 €. Ils sont cochés et fixes ; le visiteur choisit quatre autres titres. Passion permet six titres à 15 €. Les Collectors sont exclus. Le passage d’un pack à l’autre réinitialise le choix des titres. La formule Équilibre est sélectionnée par défaut ; tous les rythmes restent accessibles.

Chaque abonnement comprend une carte et une dédicace d’un des auteurs. La mention « au même prix » et les deux phrases relatives aux remises demandées sont retirées. Les références obsolètes à 120 € et 30 € de port d’abonnement ont disparu des pages publiques, de la FAQ et des CGV. Le calcul utilise les prix des titres cochés, vérifie leur composition et reprend pack, formule, titres et total dans la demande de contact.

Le parcours prépare une demande ; il ne réalise pas de paiement automatique. La réception réelle des demandes nécessite toujours les identifiants Brevo. Les dates sont confirmées avant paiement. Aucune avant-première, autocollant collector ni délai de deux à trois semaines n’est promis : ces idées du document restent à valider.

## Présentation et photos

- Citations recentrées avec une largeur maximale et des marges sur les pages Professionnels et Presse.
- Aucun texte « Courte citation à ajouter. ».
- Légende : « Le livre Jules Verne dans la boutique du musée de Nantes. » Le texte alternatif est corrigé également.
- Les librairies viennent avant les salons : Monocle à Pontrieux et Gwalarn à Lannion, avec adresses, téléphone cliquable et lien externe dans un nouvel onglet.
- Photo de l’enfant : bannière de la page Offrir / abonnement cadeau.
- Livres en éventail : présentation des packs d’abonnement.
- Tranches et couture : fabrication, sur l’accueil et la page de fabrication.
- Accueil : deux entrées visibles, « Offrir un abonnement » et « Acheter à l’unité ». Le menu donne accès à l’abonnement cadeau.

Les originaux fournis sont copiés sous les noms suivants, sans retouche :

- `dist/assets/photos/enfant-lecture-fauteuil.png`
- `dist/assets/photos/collection-livres-eventail.jpeg`
- `dist/assets/photos/collection-couture-bibliotheque.jpeg`

Les versions WebP adaptées sont générées automatiquement. Aucune couverture de votre catalogue n’est remplacée. Les captures d’écran des tarifs servent de référence et ne sont pas publiées comme photos du site.

## Vérifications

Tests des six tarifs, de la composition des packs, des mentions retirées, des coordonnées des librairies, de leur ordre, des photos et des liens internes ; compilation de toutes les pages. Les règles d’indexation et les métadonnées de publication sont conservées. L’aperçu Sites permet de consulter la présentation ; les fonctions d’envoi sont destinées à votre déploiement Vercel configuré. La vérification visuelle dans un navigateur n’a pas été disponible dans cet environnement.
