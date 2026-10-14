# Collection Livres — PWA de gestion

Socle de développement pour piloter une collection de livres jeunesse (33 tomes prévus) : catalogue, stocks par localisation, ventes et encaissements, inventaires, dons/pertes, prêts et retours, dépôts-vente et règlements de librairies, commandes et réceptions de réimpression, dépenses, contacts, CRM, événements, journal d'audit et reprise contrôlée d'Excel.

## Principes de gestion

- **Un journal de mouvements alimente le stock.** Le solde opérationnel est la somme des mouvements validés, par livre et localisation.
- **Un inventaire physique initialise ou corrige le stock.** L'écart devient une régularisation documentée, pas une vente fictive. Une validation est bloquée si le stock a changé pendant le comptage.
- **Une commande d'impression n'est pas une réception.** Seuls les exemplaires effectivement livrés entrent en stock.
- **Les ventes et paiements sont distincts.** On peut saisir une vente puis encaisser son solde ultérieurement. Les paiements excédentaires sont rejetés.
- **Dons, pertes, prêts et dépôts-vente** ont leurs propres types de mouvements. Un prêt est temporaire; le dépôt-vente reste un stock possédé localisé chez la librairie jusqu'à la vente ou au retour.
- **Traçabilité.** Les principales créations et modifications sont consignées avec auteur, date, valeurs avant/après. Les journaux métiers ne sont pas directement modifiables depuis le navigateur.

## Analyse du classeur source

Le classeur `Suivi_Collection_Livres_CRM_Stocks_PRO.xlsx` comporte 28 feuilles. Les feuilles consolidées couvrent le catalogue (33 places de tome, 11 annoncées comme publiées), les ventes (environ 143 lignes), les contacts (environ 43 fiches), les dépenses (environ 12 lignes), le CRM et les événements. Les informations de coût, financement, tarifs, communication et historique existent aussi dans plusieurs feuilles spécialisées. Le rapport détaillé est `migration/ANALYSE_CLASSEUR.md`.

**Point de contrôle majeur :** le calcul historique fait apparaître le tome 10 à −4 exemplaires; la feuille centrale `07 REIMPRESSIONS` a ses en-têtes mais pas de lignes de tirage. Par conséquent, le projet conserve les soldes Excel uniquement comme références historiques et ne crée pas de stock réel à partir de ces calculs. Un inventaire d'ouverture est nécessaire. Des ventes pro, abonnements multi-tomes et identifiants ISBN/EAN présentent également des ambiguïtés à rapprocher.

Le catalogue issu du classeur est préchargé dans `supabase/seed_catalog.sql`. Il ne contient pas de coordonnées clients; les données complètes du classeur sont fournies séparément dans l'archive privée de migration.

## Technologies

- Next.js App Router, React et TypeScript.
- Supabase PostgreSQL, Auth, RLS et fonctions transactionnelles.
- Vercel pour l'hébergement/déploiement continu.
- GitHub pour le versionnement.
- PWA installable. Le service worker met en cache uniquement des éléments statiques, jamais les données commerciales. Une connexion Internet reste nécessaire pour les données.

## Installation de la base Supabase

À faire dans un projet Supabase privé et vide, depuis **SQL Editor**, dans cet ordre :

1. `supabase/migrations/202610130001_initial_schema.sql`
2. `supabase/migrations/202610130002_transaction_functions.sql`
3. `supabase/migrations/202610130003_legacy_import_staging.sql`
4. `supabase/seed_catalog.sql`

Les migrations sont prévues pour une première installation. Ne les appliquez pas par-dessus une base contenant déjà des tables métiers sans faire une sauvegarde et adapter le plan.

Dans **Authentication → Users**, créez les deux comptes des responsables. L'inscription publique n'est pas nécessaire.

## Lancer en local

1. Node.js 22 LTS est recommandé pour Next.js 16.
2. Copiez `.env.example` vers `.env.local` et renseignez `NEXT_PUBLIC_SUPABASE_URL` et `NEXT_PUBLIC_SUPABASE_ANON_KEY` (clé publique/anon du projet).
3. Dans ce dossier :

   ```bash
   npm install
   npm run dev
   ```

4. Ouvrez l'URL affichée dans le terminal. Avant un déploiement : `npm run build` puis `npm start`.

**Ne partagez pas et n'intégrez jamais de clé `service_role` dans le code client ou une variable `NEXT_PUBLIC_*`.**

## GitHub et Vercel

1. Créez un dépôt GitHub privé et poussez le code de cette archive.
2. Importez le dépôt dans Vercel.
3. Définissez les deux variables publiques Supabase dans les paramètres Vercel (Preview et Production, selon votre stratégie).
4. Déployez en HTTPS. Connectez-vous avec un compte créé dans Supabase. Sur mobile, ouvrez le site dans le navigateur et utilisez « Ajouter à l'écran d'accueil ».

Les comptes GitHub, Supabase et Vercel restent les vôtres; ils ne sont pas préconfigurés dans cette archive.

## Reprise des données Excel : zone de staging

L'archive séparée `Collection_Livres_Migration_Privee.zip` contient le classeur source et son extraction JSON avec valeurs/formules. Ces données comprennent potentiellement des informations personnelles : conservez cette archive et le dépôt applicatif en privé.

1. Décompressez le contenu privé dans le dossier du projet de façon à obtenir `migration/private-workbook-extract.json`.
2. Copiez `.env.migration.example` vers `.env.migration`, renseignez `SUPABASE_URL` et `SUPABASE_SERVICE_ROLE_KEY`, puis chargez ces variables **dans un terminal local seulement**.
3. Exécutez `node scripts/import-legacy-staging.mjs`.
4. La page « Reprise Excel » permet d'examiner les lignes, valeurs et formules, puis de noter les décisions de rapprochement.

Le script est idempotent par fichier/feuille/ligne. Il préserve les données sources dans `legacy_import_rows`; il ne transforme pas automatiquement une donnée ambiguë en vente, encaissement, dépense ou mouvement. L'import opérationnel de l'historique nécessite encore un rapprochement contrôlé, domaine par domaine.

## Mise en service conseillée

1. Vérifier dans le catalogue les ISBN/EAN qui se contredisent et les fiches « à venir ».
2. Créer les deux comptes individuels et tester les droits RLS avec chacun d'eux.
3. Charger les données historiques en staging, rapprocher les ventes pro, abonnements multi-tomes et stocks.
4. Effectuer un **inventaire physique d'ouverture** avant toute vente réelle.
5. Tester au minimum : vente réglée et vente partiellement payée; réception partielle d'un tirage; don et casse; prêt puis retour partiel; dépôt-vente, vente déclarée, règlement et retour des invendus; régularisation d'inventaire.
6. Faire valider les exports et règles fiscales par la personne en charge de la comptabilité avant de considérer les chiffres comme une comptabilité officielle.

## Portée du livrable

Il s'agit d'un MVP de développement, pas encore d'un service en production. Le code et les scripts ont reçu un contrôle de syntaxe TypeScript/JS, mais l'environnement de création n'a pas permis d'installer toutes les dépendances npm ni d'exécuter un build Next.js complet contre une instance Supabase réelle. Il faudra donc exécuter `npm install`, `npm run build` et une recette d'intégration après installation. Les exports comptables officiels et le rapprochement intégral des transactions historiques restent à terminer et valider.
