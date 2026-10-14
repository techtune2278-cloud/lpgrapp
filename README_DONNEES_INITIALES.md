# LPGR'APP — données initiales et reprise Excel

## Pourquoi la base semblait vide ?

Les migrations 001 à 003 créent les tables et les fonctions, mais ne chargent pas les lignes métier. Dans l'archive MVP précédente, le fichier `supabase/seed_catalog.sql` cité dans le README n'avait pas été livré. Cette version ajoute le seed des 33 tomes ainsi que les données de référence issues du classeur.

## Ordre à suivre dans Supabase SQL Editor

Si tu as déjà exécuté les migrations 001, 002 et 003 sur cette base :

1. Exécute `supabase/migrations/202610140004_legacy_seed_support.sql`.
2. Exécute `supabase/seed_catalog.sql` pour créer/mettre à jour les 33 tomes.
3. Dans l'archive privée `LPGRAPP_Donnees_Initiales_Prives.zip`, exécute `seed_reference_data.sql` pour charger les contacts, événements, dépenses et actions CRM.
4. Vérifie les décomptes affichés à la fin du script.

**Ne rejoue pas les migrations 001 à 003** si elles sont déjà appliquées. Les fichiers `seed_catalog.sql` et `seed_reference_data.sql` sont idempotents grâce aux clés source et peuvent être relancés sans dupliquer les lignes importées par ces scripts.

## Reprise complète des données source

Le fichier privé `migration/private-workbook-extract.json` est une copie des valeurs ET formules de toutes les feuilles utilisées du classeur Excel. Le classeur source est fourni sous `migration/private-workbook-source.xlsx`. Il est conservé à part du code car il contient des coordonnées et informations commerciales.

1. Copie `migration/private-workbook-extract.json` dans le dossier `migration` du projet local.
2. Copie `.env.migration.example` vers `.env.migration` et renseigne l'URL Supabase et la clé `service_role` depuis les paramètres du projet. **Ne communique jamais cette clé et ne la place jamais dans GitHub.** Le `.gitignore` du projet doit contenir `.env.migration` et `migration/private-*`.
3. Dans un terminal local, exécute `npm run import:legacy`.
4. Ouvre LPGR'APP → **Reprise Excel** pour examiner toutes les lignes source. L'import conserve les valeurs et les formules de toutes les feuilles dans `legacy_import_rows`. Les fichiers `migration/private-*` sont ignorés par Git dans le `.gitignore` du projet.

L'import « staging » conserve la source, mais ne convertit pas automatiquement les anciennes ventes ou les anciennes valeurs de stock en opérations comptables. Cela est intentionnel : le classeur contient des abonnements à ventiler, des ventes incomplètes et des références de stock négatives. Il faut valider ces rapprochements avant de créer des ventes/paiements/mouvements opérationnels.

## Profil / journal d'audit

La migration 004 crée les profils manquants pour les comptes qui existaient avant l'installation du trigger Auth. L'ancienne requête `UPDATE profiles ... FROM auth.users` ne créait pas de profil : elle ne modifiait qu'une ligne déjà existante. Vérifie le profil avec :

```sql
select u.email, p.id, p.full_name
from auth.users u
left join public.profiles p on p.id = u.id
where lower(u.email) = lower('gaelvali@gmail.com');
```

Le journal d'audit se remplit lorsque les tables suivies sont modifiées. Les lignes sources simplement placées dans `legacy_import_rows` et les données importées peuvent aussi laisser des traces si leurs tables possèdent des triggers d'audit; l'import SQL exécuté par un administrateur peut afficher un acteur système plutôt que la personne connectée dans l'interface.
