-- Zone de reprise du classeur. Elle conserve toutes les feuilles/lignes, valeurs et formules avant rapprochement.
create table if not exists public.legacy_import_rows(
 id uuid primary key default gen_random_uuid(),source_file text not null,sheet_name text not null,row_number integer not null check(row_number>0),source_address text,
 row_values jsonb not null default '[]'::jsonb,row_formulas jsonb not null default '[]'::jsonb,row_hash text not null,
 review_status text not null default 'to_review' check(review_status in('to_review','reviewing','accepted','ignored','needs_clarification')),
 review_note text,imported_at timestamptz not null default now(),reviewed_by uuid references auth.users(id),reviewed_at timestamptz,
 unique(source_file,sheet_name,row_number)
);
create index if not exists legacy_import_review_idx on public.legacy_import_rows(review_status,sheet_name,row_number);
alter table public.legacy_import_rows enable row level security;
create policy legacy_import_rows_read on public.legacy_import_rows for select to authenticated using(auth.uid() is not null);
grant select on public.legacy_import_rows to authenticated;
create or replace function public.review_legacy_import_row(p_row_id uuid,p_status text,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;
 if p_status not in('to_review','reviewing','accepted','ignored','needs_clarification') then raise exception 'Statut de revue invalide.';end if;
 update public.legacy_import_rows set review_status=p_status,review_note=nullif(trim(coalesce(p_note,'')),''),reviewed_by=case when p_status in('accepted','ignored') then auth.uid() else null end,reviewed_at=case when p_status in('accepted','ignored') then now() else null end where id=p_row_id;
 if not found then raise exception 'Ligne source introuvable.';end if;
end $$;
grant execute on function public.review_legacy_import_row(uuid,text,text) to authenticated;
revoke insert,update,delete on public.legacy_import_rows from anon,authenticated;
