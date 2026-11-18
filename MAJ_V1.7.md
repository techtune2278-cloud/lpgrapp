# V1.7 — mise à jour du 3 novembre 2026

Cette version reprend les évolutions et les trois textes légaux fournis le 3 novembre, ainsi que vos dernières précisions. Les deux auteurs restent Hervélina Vyskoc et Valérie Lemoine. La navigation publique est conservée.

## Installer

Décompressez ce paquet hors du projet, puis dans le dossier décompressé :

```bat
python installer_maj.py "C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp"
```

L’installateur sauvegarde les fichiers remplacés, conserve vos descriptions, couvertures, événements et paramètres personnalisés, applique les prix Collector et les mois de parution confirmés dans votre cahier des charges, et ajoute les événements et points de vente s’ils n’existent pas déjà. Il ne fait aucun push.

Depuis le dossier habituel du site :

```bat
git add .
git commit -m "V1.7 - abonnements calendrier administration et documents legaux"
git push
```

**Important à partir de l’activation de l’administration :** elle écrit dans GitHub. Avant toute nouvelle modification locale, récupérez ses changements avec `git pull --rebase`. Si Git signale un conflit, ne l’écrasez pas : conservez les deux versions pour le résoudre.

## Abonnement et ventes

- Les achats à l’unité continuent par les fiches et SumUp, sans limite d’abonnement.
- L’abonnement propose par défaut **3 à 12 exemplaires**, et non 3 à 12 titres distincts. Plusieurs exemplaires du même livre sont possibles. Ces deux bornes peuvent être modifiées par Valérie dans l’administration.
- Chaque exemplaire a son mois et son numéro de colis. Les mois trop précoces, les colis de plus de trois exemplaires et les colis réunissant plusieurs mois sont refusés côté navigateur et côté serveur.
- La répartition initiale est automatique par mois, par trois livres maximum. Le client peut ensuite modifier chaque ligne. Le bouton « Répartir automatiquement par mois » recalcule une proposition. Un changement des quantités recalcule aussi la répartition ; les mois déjà choisis sont conservés.
- Les ouvrages parus peuvent être planifiés au mois choisi ; les titres annoncés sont commandables dès qu’un mois est connu. La limite d’attente de trois mois de l’ancien document est retirée conformément à votre dernière instruction.
- Port par colis en France métropolitaine : 4,50 € pour un exemplaire, 7 € pour deux ou trois.
- Collectors : 16,50 €. Dates : Collector 1 décembre 2026 ; Collector 2 décembre 2027 ; tomes 12–15 avril 2027 ; tomes 16–19 octobre 2027.
- Deux cases obligatoires : acceptation des CGV et compréhension de la demande sans paiement. Infolettre facultative et décochée ; elle déclenche une double confirmation séparée si Brevo est configuré.
- La demande est transmise au vendeur. Le client reçoit ensuite un accusé de réception avec le récapitulatif et les CGV/formulaire de rétractation en pièce jointe texte. Le site ne déclare pas cet accusé envoyé si le fournisseur ne l’a pas confirmé.
- Après vérification manuelle : facture valable 15 jours, paiement unique par virement. Aucun lien de paiement SumUp n’est envoyé pour l’abonnement et aucun prélèvement/règlement n’est déclenché par le formulaire.

## Administration de Valérie

Ouvrir `/administration/` sur le déploiement **Vercel** une fois configuré. Cette adresse n’est pas dans le menu public et n’est pas indexable.

Quatre rubriques : livres/parutions (dont couvertures et extraits), rencontres/salons, points de vente, bornes de l’abonnement. Un seul compte : Valérie Lemoine. Les opérations de lecture et de publication côté serveur nécessitent une session valide ; connaître l’URL ne permet pas de modifier le site.

Chaque publication crée une modification de `content.json` dans GitHub. Le dépôt et la branche reliés à Vercel doivent être configurés. L’interface distingue l’enregistrement GitHub de la fin du déploiement : elle ne prétend pas que le site est déjà actualisé avant la compilation Vercel.

Ajouter un livre : cliquer Ajouter, renseigner numéro et adresse uniques, titre, prix, nombre de pages, présentation, couverture et lien SumUp ; cocher « Livre paru » uniquement à sa disponibilité effective. Les mois s’indiquent au format du sélecteur. Une photo de moins de 1 Mo peut être téléversée ; elle est stockée dans les données puis optimisée au build. Le poids total du catalogue reste limité par l’API : si plusieurs photos rendent le catalogue trop lourd, utilisez des fichiers image dans `dist/assets` et renseignez leur chemin.

Retirer un élément demande une confirmation ; la suppression n’est effective qu’après Publier et reste récupérable dans l’historique GitHub. Le code protège contre l’écrasement d’une modification concurrente : recharger dans ce cas.

**Activation nécessaire :** renseigner le mot de passe, le secret de session et le jeton GitHub dans Vercel. La procédure complète et la liste des informations manquantes sont dans **POINTS_ADMINISTRATIFS.md**. Aucun mot de passe ou jeton réel n’est inclus dans le code. L’aperçu statique Sites et le serveur Python local ne font pas tourner les fonctions Vercel : on peut y vérifier la présentation, mais pas administrer réellement le dépôt.

## Textes et documents

- Accueil révisé, lecture accompagnée dès 5 ans et lecture autonome vers 8–9 ans selon l’enfant.
- Présentation distincte des Collectors et prix confirmé ; les fiches et le calendrier s’adaptent aux contenus disponibles.
- Citation d’Amélie Nothomb avec attribution à la ligne.
- Les trois textes légaux sont intégrés en HTML, sans résumer leurs articles. Les notes internes à compléter sont retirées des pages publiques ; le texte source complet est conservé dans `legal-documents.json`.
- Les ajustements liés à vos dernières instructions — mois choisis et suppression de l’attente maximale — sont appliqués aux CGV. Les informations juridiques d’EI sont celles des documents joints, sans retirer l’un des auteurs du site.
- Page `/retractation/`, liens de pied de page et documents téléchargeables en texte. Les versions publiées sont générées dans `dist/assets/documents/` et les CGV sont jointes à l’accusé de réception.
- Le document d’origine des salons est conservé comme référence : trois rendez-vous saisis « à confirmer », dont Plésidy pour lequel une date différente est annoncée par l’agenda départemental. Les pages non confirmées sont hors indexation ; Valérie peut compléter et confirmer depuis l’administration.

## Réglages de publication et limites vérifiées

`npm run build`, sortie `dist`, conserve le correctif Pillow isolé et génère le HTML complet, les métadonnées, les images de partage, les WebP et le sitemap. L’administration est exclue du sitemap, comme les événements non confirmés. `SITE_URL` reste le domaine effectivement configuré ; ne mettre le domaine définitif qu’après sa connexion et redéployer.

Des tests contrôlent les tarifs, quantités, dates, colis, accusés de réception, consentement newsletter, sessions admin, rejet des origines étrangères, expiration, conflits et écriture GitHub (fournisseurs simulés). La vraie publication GitHub depuis l’administration et les vrais messages Brevo restent à vérifier après la saisie de vos secrets Vercel. Aucun message réel et aucune modification de votre dépôt GitHub personnel n’ont été faits par ces tests.

La liste des démarches administratives, des éléments légaux à confirmer, du RIB, des contrats fournisseurs et des autorisations de photos/citation se trouve à la fin dans **POINTS_ADMINISTRATIFS.md**.
