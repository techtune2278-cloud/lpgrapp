-- LPGR'APP migration 004 — support de reprise des données initiales.
-- À appliquer une seule fois après les migrations 001, 002 et 003.

-- Un historique ne doit pas recevoir une date inventée lorsqu'Excel n'en contient pas.
alter table public.expenses alter column expense_date drop not null;
alter table public.crm_actions alter column action_date drop not null;

-- Idempotence des imports de données de référence depuis le classeur.
create unique index if not exists contacts_source_legacy_uidx
  on public.contacts(source_legacy) where source_legacy is not null;
create unique index if not exists events_source_legacy_uidx
  on public.events(source_legacy) where source_legacy is not null;
create unique index if not exists expenses_source_legacy_uidx
  on public.expenses(source_legacy) where source_legacy is not null;
create unique index if not exists crm_actions_source_legacy_uidx
  on public.crm_actions(source_legacy) where source_legacy is not null;

-- Réparer les profils manquants pour les utilisateurs Auth créés avant le trigger on_auth_user_created.
insert into public.profiles(id, full_name)
select u.id, coalesce(nullif(u.raw_user_meta_data->>'full_name',''), split_part(u.email,'@',1), '')
from auth.users u
on conflict (id) do nothing;

-- Contrôles de fin de migration.
select 'profiles' as table_name, count(*)::bigint as lignes from public.profiles
union all select 'books', count(*) from public.books
union all select 'contacts', count(*) from public.contacts
union all select 'events', count(*) from public.events;
