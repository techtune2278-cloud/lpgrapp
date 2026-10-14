-- LPGR'APP — Correctif des droits pour l'import Excel en zone de reprise.
-- À exécuter dans Supabase > SQL Editor avec un compte administrateur.
-- Ce script donne les droits d'écriture à service_role uniquement ; il ne donne
-- pas de droits d'écriture aux utilisateurs authentifiés de l'application.

grant usage on schema public to service_role;
grant select, insert, update, delete on table public.legacy_import_rows to service_role;

-- Contrôle : les quatre valeurs doivent être TRUE.
select
  has_table_privilege('service_role', 'public.legacy_import_rows', 'SELECT') as service_role_can_select,
  has_table_privilege('service_role', 'public.legacy_import_rows', 'INSERT') as service_role_can_insert,
  has_table_privilege('service_role', 'public.legacy_import_rows', 'UPDATE') as service_role_can_update,
  has_table_privilege('service_role', 'public.legacy_import_rows', 'DELETE') as service_role_can_delete;
