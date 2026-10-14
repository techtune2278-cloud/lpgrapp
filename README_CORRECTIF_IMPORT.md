# Correctif LPGR'APP — droits de l'import Excel

## Pourquoi l'import échoue

`permission denied for table legacy_import_rows` indique que l'identité utilisée par le script n'a pas les droits d'écriture sur la table. Le script doit utiliser la clé `service_role`/secret du même projet Supabase, et la table doit autoriser ce rôle.

## Étapes

1. Dans Supabase, ouvrez **SQL Editor** et exécutez `CORRECTIF_DROITS_IMPORT_LEGACY.sql`. Les quatre colonnes de contrôle affichées à la fin doivent être `true`.
2. Remplacez `scripts/import-legacy-staging.mjs` par le script de cette archive.
3. Vérifiez le fichier local `.env.migration` :

   ```dotenv
   SUPABASE_URL=https://VOTRE_PROJET.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=VOTRE_CLE_SECRETE_SERVICE_ROLE
   ```

   N'utilisez pas une clé `anon` / `publishable`. Ne transmettez pas la clé dans un message et ne la versionnez jamais dans Git.
4. Si vous avez défini `SUPABASE_SERVICE_ROLE_KEY` dans la session PowerShell, cette variable a priorité sur `.env.migration`. Pour supprimer seulement cette surcharge de la session courante :

   ```powershell
   Remove-Item Env:SUPABASE_SERVICE_ROLE_KEY -ErrorAction SilentlyContinue
   ```

5. Relancez depuis la racine du projet :

   ```powershell
   npm run import:legacy
   ```

L'import est idempotent par fichier/feuille/ligne. Il copie les lignes sources dans la zone de reprise et ne crée pas de ventes ou mouvements de stock opérationnels.
