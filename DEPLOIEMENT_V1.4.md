# Publication V1.4 — Les plus grands racontés aux plus petits

Le site principal passe en publication. Ses pages de contenu sont indexables ; les anciennes adresses, l’atelier local, la page de confirmation et le blog encore vide restent en `noindex`. Les dates manquantes ne bloquent pas la génération. Aucun classement Google ou score Lighthouse n’est promis : ils se mesurent après déploiement avec vos vraies images.

## 1. Installer sur votre PC

Décompressez le paquet **hors du projet**, puis ouvrez un terminal dans le dossier obtenu :

```bat
python installer_maj.py "C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp"
```

L’installateur prépare Pillow, sauvegarde les fichiers remplacés dans un dossier voisin, conserve votre catalogue, vos images et vos liens SumUp personnalisés, puis génère le site. Il ne pousse pas vers GitHub. Il force uniquement le passage du réglage `publication_mode` à `production` ; un domaine déjà configuré reste conservé.

Vérifiez ensuite dans le dossier habituel du site :

```bat
cd /d "C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp"
python -m http.server 8080 --bind 127.0.0.1 --directory dist
```

Ouvrez http://127.0.0.1:8080. Arrêtez le serveur avec Ctrl+C, puis publiez :

```bat
git add .
git commit -m "V1.4 - publication et referencement"
git push
```

Sur Vercel : Framework Preset **Other**, Build Command **npm run build**, Output Directory **dist**. Effacez un éventuel ancien override qui désactive le build ; utilisez les réglages de `vercel.json`. La compilation prépare les dépendances Python si nécessaire. Les pages sont régénérées à chaque déploiement GitHub, avec vos fichiers image.

## 2. Brancher votre domaine

Pour l’instant les canonical, liens de partage et sitemap utilisent **https://sitelpgrapp.vercel.app**. Ne les basculez vers un domaine que lorsqu’il est connecté.

1. Achetez le domaine chez votre prestataire.
2. Dans Vercel → projet → Settings → Domains, ajoutez le domaine et son éventuelle variante `www`.
3. Dans le gestionnaire DNS du domaine, appliquez **les valeurs indiquées par Vercel**. Attendez que Vercel valide le domaine et HTTPS.
4. Choisissez une seule adresse principale. Faites rediriger les autres variantes vers cette adresse, en conservant les chemins. Une simple redirection du nouveau domaine vers `vercel.app` ne donnera pas le résultat souhaité : il faut connecter le domaine au projet.
5. Dans Vercel → Settings → Environment Variables → **Production**, ajoutez `SITE_URL`, par exemple `https://lesplusgrandsracontes.fr` si c’est l’adresse principale retenue. Pas de chemin après le domaine.
6. Relancez un déploiement. Le site régénère tous ses canonical, URL JSON-LD, images de partage et sitemap avec cette adresse.

Vous pouvez aussi changer `site_url` dans `site-settings.json` pour vos compilations locales. La variable d’environnement `SITE_URL` a priorité ; gardez les deux valeurs cohérentes. Ne mettez jamais de clé Brevo dans ce fichier.

Les déploiements de prévisualisation Vercel (`VERCEL_ENV=preview`) restent en `noindex` pour éviter l’indexation de copies. Le déploiement de production reste indexable.

## 3. Formulaires : ce qui nécessite votre compte Brevo

Le serveur d’envoi est inclus. Il reste à fournir les identifiants et à tester une réception réelle ; aucun message de test n’a été envoyé depuis votre compte pendant cette mise à jour.

Dans Vercel → Settings → Environment Variables → Production :

| Variable | Valeur à renseigner |
|---|---|
| `BREVO_API_KEY` | Clé API Brevo, conservée côté serveur |
| `CONTACT_FROM_EMAIL` | Expéditeur vérifié dans Brevo |
| `CONTACT_TO_EMAIL` | Votre adresse de réception existante |
| `CONTACT_FROM_NAME` | Les plus grands racontés aux plus petits |
| `SITE_URL` | Adresse publique principale du site |

L’adresse `contact@lesplusgrandsracontes.fr` doit être créée chez votre prestataire de messagerie avant d’être utilisée. Vérifiez l’expéditeur et les réglages DNS demandés par Brevo. Après redéploiement, envoyez une demande depuis `/contact/`, puis une depuis `/professionnels/`, et vérifiez la réception avec ville et demande de devis. Le serveur Python local ne fait pas tourner les fonctions `/api`.

Pour activer aussi la lettre d’information : créez une liste et un modèle de double confirmation dans Brevo. Ajoutez leurs identifiants numériques dans `BREVO_NEWSLETTER_LIST_ID` et `BREVO_DOI_TEMPLATE_ID`. Le modèle doit être configuré pour la double confirmation, avec le lien de confirmation Brevo. Vérifiez ensuite réception du message, clic, ajout effectif dans la liste et désabonnement dans les campagnes. Sans ces réglages le site présente le contact comme solution de remplacement, et ne prétend pas enregistrer d’inscriptions.

## 4. SumUp et abonnements

Les dix livres disponibles ouvrent leur produit SumUp. Pour les formules groupées, renseignez les URL des produits validés dans `site-settings.json` → `offer_urls` ; les boutons correspondants ouvriront directement ces pages.

L’abonnement composé de six titres prépare une **demande détaillée** ; il ne crée pas de panier SumUp et ne prend pas de paiement. Confirmez les titres, les dates d’envoi et le montant avec le client, puis utilisez le règlement SumUp adapté. Sans API/panier SumUp configuré, nous ne présentons pas ce parcours comme un achat automatique.

Les CGV reprennent les modalités d’abonnement confirmées et renvoient aux conditions de vente de la boutique pour les achats. Les informations inconnues ne sont pas inventées. Les coordonnées du médiateur, les modalités de retour et les conditions complètes de la boutique doivent être renseignées/vérifiées par l’éditeur dans SumUp. Le choix du forfait Vercel et de ses conditions d’usage appartient au titulaire du compte.

## 5. Mettre les contenus à jour plus tard

| Élément | Emplacement à modifier |
|---|---|
| Livre, ISBN, statut, prix, description, lien SumUp | `content.json` → `books` |
| Couvertures | `dist/assets/couvertures/` : noms actuels conservés, ou champ `cover` du livre |
| Photos Hervélina et Valérie | `dist/assets/photos/` : noms des auteurs |
| Coupures de presse | `dist/assets/presse/` : nom contenant Trégor, Flâneur, Ouest-France ou Pyrénées |
| Extraits à feuilleter | `dist/assets/extraits/<slug-du-livre>/` : `01.jpg`, `02.jpg`, etc., ou tableau `excerpts` dans le livre |
| Texte exact des rubriques | `textes-brief.json` et `editorial_pages.py` ; les notes entre crochets restent dans la source et sont retirées à la publication |
| Tarifs, liens, bonus, domaine | `site-settings.json` |
| Présentation | `dist/style.css` |
| Calendrier | `content.json` → `events` |
| Actualités | `content.json` → `news` |

Exemple d’une entrée dans `events` (remplacez les valeurs par les vraies informations) :

```json
{
  "slug": "nom-de-la-rencontre",
  "title": "Nom de la rencontre",
  "start_date": "2027-01-20",
  "place": "Nom du lieu",
  "city": "Ville",
  "description": "Texte de présentation."
}
```

Champs facultatifs : `end_date`, `street`, `postal_code`, `country` (FR par défaut), `image` (chemin `/assets/...`). Une rencontre sans date, titre, lieu ou ville reste masquée. Un événement complet génère sa page, sa carte dans l’agenda et ses données structurées Event. Utilisez les dates réelles ; l’exemple n’est pas publié.

Exemple d’actualité dans `news` :

```json
{
  "slug": "titre-de-la-nouvelle",
  "title": "Titre de votre actualité",
  "date": "2027-01-20",
  "description": "Résumé pour les résultats de recherche.",
  "text": "Votre texte intégral.\n\nUn autre paragraphe."
}
```

Les textes ne sont pas résumés automatiquement. Le blog vide n’est pas dans le sitemap ; lorsqu’une actualité complète est ajoutée, l’index du blog devient indexable. L’atelier historique reste un outil local, sans publication automatique et sans lien dans le pied de page.

Après modification locale :

```bat
python build.py
```

Puis vérification et les trois commandes Git ci-dessus. Si une dépendance manque : `python -m pip install -r requirements.txt`. Vous pouvez aussi pousser les sources directement : Vercel reconstruira `dist`.

## 6. Référencement et vérifications après mise en ligne

Déjà livré : titles et descriptions par page, H1 unique, canonical, Open Graph et cartes de partage 1200 × 630, JSON-LD Book/Product, Organization, WebSite, BookSeries, Person et fil d’Ariane ; Event à l’ajout de dates réelles ; sitemap et robots ; favicons ; polices Poppins et Parisienne auto-hébergées ; images WebP avec variantes, dimensions et chargement différé. La première image utile se charge immédiatement. Les originaux sont conservés. Le socle Python existant est conservé avec votre catalogue JSON ; le HTML est complet dès la compilation. Il n’y a pas eu de migration vers le socle Astro/Markdown suggéré dans le brief initial.

À faire depuis vos comptes, après connexion du domaine :

- Déclarer le domaine dans Google Search Console et Bing Webmaster Tools, puis soumettre `https://VOTRE-DOMAINE/sitemap.xml`. Les champs `google_site_verification` et `bing_site_verification` dans `site-settings.json` acceptent les codes de validation si vous choisissez la méthode par balise ; la méthode DNS est aussi possible.
- Compléter votre fiche Google Business Profile si elle est adaptée à votre activité et admissible.
- Pour une audience sans cookie : activer Vercel Web Analytics dans le tableau de bord, puis mettre `analytics_enabled` à `true` dans `site-settings.json` et redéployer. Le script et le texte de confidentialité se mettent alors en place. Tant que ce réglage est faux, aucun script d’audience n’est chargé.
- Mesurer PageSpeed/Lighthouse mobile sur l’accueil, le catalogue et une fiche avec vos vraies images. L’objectif du brief est > 90 ; il n’a pas été mesuré dans cet environnement.
- Configurer les anciennes redirections **sur lescompagnonsderoute.com**, depuis son propre hébergeur. Les règles de ce nouveau dépôt ne peuvent pas rediriger un site qu’il n’héberge pas. Préserver les QR imprimés et leur accès aux bonus. Les liens croisés et les anciennes adresses internes connues sont déjà pris en charge dans le nouveau site.

`seo-report.json` est régénéré à la racine : il récapitule les pages indexables, leurs métadonnées et les éventuels avertissements image. Il n’est pas publié dans `dist`. Les tests contrôlent aussi les liens, les schémas, les calculs d’abonnement et les réponses des API avec un fournisseur simulé. Ils ne remplacent pas la réception réelle d’un e-mail ni une mesure de performance sur le site public.
