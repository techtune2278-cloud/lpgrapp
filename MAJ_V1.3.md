# Mise à jour V1.3.0

## Installation

Décompressez le paquet hors du dossier du site, puis lancez depuis le dossier obtenu :

    python installer_maj.py "C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp"

L’installateur sauvegarde les fichiers remplacés et conserve les images, le catalogue et les paramètres de votre site. Il ajoute le PDF et la photo du musée reçus le 20 octobre 2026. Aucun envoi Git n’est effectué par l’installateur.

Dans le dossier habituel du site, après contrôle :

    git add .
    git commit -m "V1.3 - mise en page, abonnement, documents et mentions"
    git push

## Mise en forme

Les couvertures étaient affichées dans une boîte conservant une hauteur HTML fixe de 720 px, même lorsqu’elles étaient réduites à la largeur d’une carte. La hauteur CSS est maintenant automatique, les cartes sont alignées en haut et les marges entre couverture, prix et titre sont resserrées.

Les fichiers image eux-mêmes n’ont pas été modifiés. Les photos déjà déposées sur votre PC restent en place.

## Abonnement composé par le visiteur

La page Offrir propose de cocher exactement six titres de 24 pages à 15 €. Les titres à paraître sont identifiés. Arthur Rimbaud et Victor Hugo à 9 €, ainsi que les Collectors dont le prix diffère ou reste à confirmer, sont exclus.

Trois rythmes pour la France :

| Envois | Livres | Port et emballage | Total |
|---|---:|---:|---:|
| 6 envois d’un livre | 90 € | 30 € | 120 € |
| 3 envois de deux livres | 90 € | 21 € | 111 € |
| 2 envois de trois livres | 90 € | 14 € | 104 € |

Carte et dédicace d’un des auteurs pour l’abonnement cadeau, au même prix. Paiement en une fois, sans prélèvement récurrent. Aucune remise sur les livres.

Le bouton prépare une demande avec les six titres, le regroupement, le total et l’option cadeau. Il ouvre le formulaire de contact prérempli. La sélection n’effectue pas de paiement et ne crée pas de panier SumUp. Les modalités de règlement et le calendrier restent à confirmer avant paiement. Le formulaire nécessite toujours la configuration Brevo pour envoyer réellement la demande.

Les informations sont temporairement transférées entre les pages par sessionStorage ; si ce stockage n’est pas disponible, un récapitulatif copiable est affiché. Aucun nom de bénéficiaire ni adresse n’est demandé à ce stade.

Les CGV reprennent le paiement unique, les frais, la carte et la dédicace, la confirmation des dates avant paiement, le remboursement du solde si un titre n’est pas livré et le droit de rétractation de 14 jours. Les dates réelles ne sont pas inventées. Les autres clauses restent à finaliser.

## Mentions et libellés

Identité fournie intégrée : Sur le Chemin des Arts, SIRET 953 755 477 00015, 22 Rue de Lassun, 64800 Montaut, directeur de la publication Hervélina Vyskoc-Lemoine, TVA non applicable article 293 B du CGI.

L’hébergeur indiqué dans votre message est OVH. Le site consultable aujourd’hui est cependant déployé sur Vercel : les mentions distinguent Vercel pour cette version et OVH comme hébergement à confirmer à la migration, afin de ne pas présenter la migration comme déjà réalisée.

La citation d’Amélie Nothomb est signée « écrivain ». Chaque fiche pratique affiche explicitement Auteurs et Édition.

Le lien vers l’Atelier de contenu est retiré du pied de page. Cet outil du prototype ne publie pas directement et n’est pas une rubrique destinée aux visiteurs. Sa page technique reste accessible à son ancienne adresse pour conserver votre travail local ; elle n’est pas dans le sitemap.

## Professionnels et médias

Aucun taux de remise n’est affiché sur la page Professionnels. Les conditions commerciales sont sur demande. Pour les musées, la vente ferme est indiquée, sans dépôt.

La photo du musée est livrée ici :

    dist/assets/photos/musee-jules-verne-nantes.jpg

Le dossier PDF original est livré sans modification ici :

    dist/assets/documents/dossier-alliances-francaises-lpgrapp.pdf

Il est proposé au téléchargement dans la section Alliances françaises et dans les documents professionnels.

Les liens externes s’ouvrent dans un nouvel onglet, ainsi que les liens PDF (le navigateur peut télécharger directement le PDF selon ses réglages). La navigation entre les pages du site reste dans le même onglet.

Le lien du bonus Molière est conservé vers :
https://www.lescompagnonsderoute.com/les-bonus-de-la-collection-lpgrapp

## Fichiers

- page_helpers.py : règles des liens et HTML de l’abonnement.
- dist/subscription.js : sélection et calcul des frais.
- editorial_pages.py : rubriques, fiches, professionnels et mentions.
- build.py : génération et navigation commune.
- dist/style.css : corrections d’espacement et présentation du sélecteur.
- dist/app.js : préremplissage du contact à partir de la sélection.

Après toute modification : python build.py avant le push.

## Vérification

16 tests Python et 12 tests JavaScript passent : liens, documents, identité, fidélité des textes non modifiés, formulaires et calculs 120/111/104 €. Aucun e-mail réel n’est envoyé par les tests. L’intégration est contrôlée avec le PDF et la photo d’origine, et un essai de l’installateur conserve les données existantes. Les espacements sont corrigés dans le code ; leur rendu sur votre ordinateur reste à contrôler avec vos couvertures réelles.
