# V1.6 — abonnement libre et adresse de contact

## Installation

Décompressez ce paquet hors du projet, puis depuis le dossier décompressé :

```bat
python installer_maj.py "C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp"
```

Le script conserve le catalogue, les textes de vos livres, les images et les réglages personnalisés. Une sauvegarde des fichiers remplacés est créée dans un dossier voisin. Les anciennes pages générées de titres sans couverture ni description sont retirées ; elles seront régénérées lorsque le contenu sera fourni.

Dans le dossier habituel du projet :

```bat
git add .
git commit -m "V1.6 - abonnement libre et reservations"
git push
```

Vercel : `npm run build`, sortie `dist`. Le correctif d’isolation de Pillow est conservé.

## Ce qui change

- Accueil : « Offrir un abonnement » vers `/offrir/`, « Acheter » vers `/livres/`.
- Page Offrir : titre, description, H1 et textes de votre message du 21 octobre. Le délai indiqué entre crochets est repris à **10 jours** ; faites confirmer ce délai et les clauses contractuelles avant encaissement.
- Les packs Découverte / Passion et les offres groupées de l’ancienne page sont remplacés par le formulaire libre.
- Choix des livres parus, des six prochains dont la date est confirmée et réservations sans paiement pour les titres plus lointains ou sans date confirmée.
- De 1 à N envois, N étant le nombre de livres retenus au paiement. Les réservations sont exclues du calcul et de cette limite.
- Répartition équilibrée, dans l’ordre des parutions : chaque colis affiche les titres, le port et l’attente du dernier titre à paraître. La composition est confirmée avec le client avant le règlement.
- Grille France par colis : 1 livre 4,50 € ; 2–3 livres 7 € ; 4–6 livres 9 € ; 7–12 livres 11 € ; au-delà de 12 livres par colis sur devis, avec port et total explicitement non chiffrés.
- Coordonnées de l’acheteur, adresse du destinataire, mot pour la carte et consentement.
- Formulaire direct d’abonnement via `/api/subscription`, avec recalcul du montant côté serveur et envoi à **contact@lesplusgrandsracontes.fr**. Aucune demande n’effectue un paiement. Le lien SumUp est envoyé manuellement par les auteurs.
- Solutions de remplacement : préparer un e-mail dans la messagerie du visiteur, ou télécharger son récapitulatif. Ces actions ne prétendent pas envoyer un message depuis le site.
- Chaque « Voir le livre » dans le formulaire ouvre un nouvel onglet et conserve ainsi la sélection.
- Catalogue : les titres à paraître affichent « Me prévenir ». Une fiche n’existe que pour les livres parus ou les titres ayant déjà une couverture ou une description. Aucun faux extrait ni mois de parution n’est créé.
- Adresse de contact visible dans le pied de page, la page Contact, les mentions et les CGV ; également dans les données structurées de l’éditeur.

La photo de la petite fille est conservée avec le texte alternatif demandé. Conservez l’accord écrit des parents dans vos documents ; il n’est pas publié sur le site. La photo des livres en éventail est déplacée vers le catalogue. Les autres corrections V1.5 restent intégrées.

## Renseigner les mois de parution

Dans `content.json`, un livre peut recevoir les champs suivants :

```json
"status": "prochain",
"release_month": "2027-02"
```

**Cette date est un exemple de format ; elle n’a pas été ajoutée au catalogue.**

Statuts acceptés : `paru`, `prochain`, `plus_tard`.

- `available: true` signifie paru.
- Sans statut explicite, les six premiers titres non parus hors Collectors deviennent les prochains. Actuellement : n° 12 à 17.
- Vous pouvez désigner explicitement jusqu’à six prochains titres. Les autres sont `plus_tard`.
- Un prochain titre sans `release_month` reste réservable sans paiement. Dès qu’un mois valide `AAAA-MM` est ajouté et le site reconstruit, il devient sélectionnable dans la partie abonnement à confirmer avant paiement.
- Un titre `plus_tard` reste une réservation, même si un mois est renseigné.
- À la parution : passez `available` à `true`, ajoutez couverture, description et URL SumUp ; le site le présente comme paru.

Les statuts calculés ne réécrivent pas votre fichier source. Le build publie le catalogue enrichi dans `dist/content.json`, utilisé par le navigateur et la fonction Vercel afin qu’ils calculent les mêmes montants. Les descriptions et prix personnalisés sont conservés.

## Activer l’envoi sur Vercel

Dans Settings → Environment Variables → Production :

```text
BREVO_API_KEY=la clé de votre compte Brevo
CONTACT_FROM_EMAIL=votre expéditeur vérifié dans Brevo
CONTACT_TO_EMAIL=contact@lesplusgrandsracontes.fr
CONTACT_FROM_NAME=Les plus grands racontés aux plus petits
```

Ne mettez jamais la clé API dans `content.json`, `site-settings.json` ou `dist`. L’adresse d’abonnement est fixée côté serveur à contact@ ; la variable `CONTACT_TO_EMAIL` continue de régler les autres formulaires. Si l’adresse est différente dans votre configuration actuelle, mettez-la à jour.

Redéployez, puis testez une réception réelle avec votre adresse d’acheteur et vérifiez le contenu reçu : sélection, réservations, colis, montants, destinataire et carte. Le serveur Python local et l’aperçu statique Sites ne font pas tourner les fonctions Vercel : ils affichent les solutions e-mail et téléchargement. Les tests livrés utilisent un fournisseur simulé ; aucun message réel n’a été envoyé pendant la réalisation.

Le formulaire n’enregistre pas les adresses dans localStorage ou sessionStorage. La saisie reste sur la page après un échec réseau. Les demandes ne créent ni commande payée ni inscription à une newsletter.

## Contrats et traitement manuel

Avant d’envoyer le lien de paiement, confirmez par écrit le montant, les titres, le mois annoncé, le contenu de chaque colis et la part de port remboursable en cas d’annulation d’un titre. Les réservations plus lointaines restent sans paiement jusqu’à confirmation de leur date. Les notifications de retard, remboursements et liens de paiement sont gérés manuellement ; cette version ne contient pas de robot de relance ni de gestionnaire de remboursements.

Les CGV et la page Offrir reprennent votre engagement de remboursement d’un titre ayant plus d’un mois de retard et le droit de rétractation mentionné. Le cas d’un abonnement à livraisons régulières doit être distingué d’une commande de plusieurs biens livrés séparément ; faites valider la qualification et les conditions applicables à votre offre, y compris la dédicace et les retours. Source de référence : https://www.service-public.gouv.fr/particuliers/vosdroits/F10485.

## Fichiers utiles

| Contenu | Fichier |
|---|---|
| Textes précis, H1 et métadonnées Offrir, construction du formulaire | `subscription_content.py` |
| Statuts, mois, prix, descriptions et images des livres | `content.json` |
| Calcul partagé du port et détail des colis | `lib/subscription-rules.js` |
| Interaction du formulaire | `dist/subscription.js` |
| Vérification et préparation du message côté serveur | `lib/subscription-service.js` et `api/subscription.js` |
| Parcours du catalogue et autres pages | `build.py` et `editorial_pages.py` |
| Apparence | `dist/style.css` |

Le script `build.py` copie le calcul partagé dans `dist/subscription-rules.js`. Ne modifiez pas cette copie générée directement. Le nombre de pages diminue lorsque les fiches à paraître sans contenu sont retirées ; c’est le comportement demandé et le sitemap suit les pages réellement publiées.
