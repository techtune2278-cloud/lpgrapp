-- Collection Livres — socle transactionnel Supabase / PostgreSQL.
-- Appliquer dans un projet Supabase vide, puis exécuter seed_catalog.sql.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create or replace function public.set_updated_at() returns trigger language plpgsql set search_path=public as $$ begin new.updated_at=now(); return new; end $$;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','')) on conflict(id) do nothing; return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create table if not exists public.contacts (
 id uuid primary key default gen_random_uuid(), name text not null,
 contact_type text not null default 'autre' check(contact_type in ('particulier','librairie','ecole','musee','association','editeur','presse','imprimeur','fournisseur','autre')),
 email text, phone text, address text, postal_code text, city text, website text, notes text, source_legacy text,
 is_active boolean not null default true, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.books (
 id uuid primary key default gen_random_uuid(), tome_number integer not null unique check(tome_number between 1 and 33),
 title text not null, subtitle text, status text not null default 'a_venir' check(status in ('publie','a_venir','suspendu','epuise')),
 isbn text, ean text, publisher text, publication_date date, legal_deposit_date date, youth_commission_date date,
 price_public numeric(10,2), price_reduced numeric(10,2), vat_rate numeric(5,4) not null default 0.0550,
 reorder_threshold integer not null default 10 check(reorder_threshold>=0), critical_threshold integer not null default 5 check(critical_threshold>=0),
 legacy_initial_stock integer, legacy_stock_reference integer, legacy_stock_note text, illustrator_cost numeric(12,2), printer_cost numeric(12,2), notes text,
 created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(price_public is null or price_public>=0), check(price_reduced is null or price_reduced>=0)
);
create table if not exists public.locations (
 id uuid primary key default gen_random_uuid(), name text not null,
 location_type text not null check(location_type in ('warehouse','consignment','loan','damaged','other')),
 contact_id uuid references public.contacts(id) on delete restrict, is_default boolean not null default false,
 is_active boolean not null default true, notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create unique index if not exists one_default_warehouse on public.locations(is_default) where is_default and location_type='warehouse';
insert into public.locations(name,location_type,is_default,notes) select 'Stock principal','warehouse',true,'À initialiser au comptage physique' where not exists(select 1 from public.locations where location_type='warehouse' and is_default);

create table if not exists public.stock_documents (
 id uuid primary key default gen_random_uuid(), document_number bigint generated always as identity unique,
 document_type text not null check(document_type in ('opening_inventory','inventory_adjustment','print_receipt','sale','donation','loss','loan','loan_return','consignment','consignment_sale','consignment_return','correction','transfer')),
 document_date date not null default current_date, status text not null default 'validated' check(status in ('draft','validated','cancelled')),
 contact_id uuid references public.contacts(id) on delete restrict, reference text, note text, inventory_session_id uuid,
 created_by uuid references auth.users(id), validated_by uuid references auth.users(id), created_at timestamptz not null default now(), validated_at timestamptz
);
create table if not exists public.stock_movements (
 id uuid primary key default gen_random_uuid(), group_id uuid not null default gen_random_uuid(), document_id uuid not null references public.stock_documents(id) on delete restrict,
 book_id uuid not null references public.books(id) on delete restrict, location_id uuid not null references public.locations(id) on delete restrict,
 movement_type text not null check(movement_type in ('opening','print_receipt','sale','donation','loan_out','loan_return','consignment_out','consignment_sale','consignment_return','inventory_adjustment','loss','transfer_in','transfer_out','correction')),
 quantity_delta integer not null check(quantity_delta<>0), unit_cost numeric(12,4), unit_price numeric(12,2), inventory_session_id uuid,
 contact_id uuid references public.contacts(id) on delete restrict, reference text, note text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create index if not exists stock_movements_book_location on public.stock_movements(book_id,location_id,created_at);
create index if not exists stock_movements_document on public.stock_movements(document_id);

create table if not exists public.sales (
 id uuid primary key default gen_random_uuid(), sale_number bigint generated always as identity unique, sale_date date not null default current_date,
 contact_id uuid references public.contacts(id) on delete restrict, channel text not null default 'direct',
 status text not null default 'recorded' check(status in ('recorded','cancelled')), gross_amount numeric(12,2) not null default 0,
 shipping_charged numeric(12,2) not null default 0, note text, document_id uuid references public.stock_documents(id) on delete restrict,
 created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.sale_items (
 id uuid primary key default gen_random_uuid(), sale_id uuid not null references public.sales(id) on delete restrict,
 book_id uuid not null references public.books(id) on delete restrict, quantity integer not null check(quantity>0),
 unit_price numeric(12,2) not null check(unit_price>=0), discount_amount numeric(12,2) not null default 0 check(discount_amount>=0),
 line_total numeric(12,2) not null check(line_total>=0), created_at timestamptz not null default now()
);
create table if not exists public.payments (
 id uuid primary key default gen_random_uuid(), sale_id uuid not null references public.sales(id) on delete restrict,
 payment_date date not null default current_date, amount numeric(12,2) not null check(amount>0), payment_method text not null default 'autre',
 reference text, note text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);

create table if not exists public.inventory_sessions (
 id uuid primary key default gen_random_uuid(), inventory_number bigint generated always as identity unique, inventory_date date not null default current_date,
 location_id uuid not null references public.locations(id) on delete restrict, status text not null default 'in_progress' check(status in ('in_progress','validated','cancelled')),
 note text, created_by uuid references auth.users(id), validated_by uuid references auth.users(id), created_at timestamptz not null default now(), validated_at timestamptz
);
create table if not exists public.inventory_lines (
 id uuid primary key default gen_random_uuid(), inventory_session_id uuid not null references public.inventory_sessions(id) on delete restrict,
 book_id uuid not null references public.books(id) on delete restrict, location_id uuid not null references public.locations(id) on delete restrict,
 theoretical_quantity integer not null default 0, counted_quantity integer check(counted_quantity is null or counted_quantity>=0), difference integer, note text,
 unique(inventory_session_id,book_id,location_id)
);
alter table public.stock_documents drop constraint if exists stock_documents_inventory_session_fk;
alter table public.stock_documents add constraint stock_documents_inventory_session_fk foreign key(inventory_session_id) references public.inventory_sessions(id) on delete restrict;
alter table public.stock_movements drop constraint if exists stock_movements_inventory_session_fk;
alter table public.stock_movements add constraint stock_movements_inventory_session_fk foreign key(inventory_session_id) references public.inventory_sessions(id) on delete restrict;

create table if not exists public.loans (
 id uuid primary key default gen_random_uuid(), loan_number bigint generated always as identity unique,
 contact_id uuid not null references public.contacts(id) on delete restrict, loan_date date not null default current_date, due_date date, returned_date date,
 status text not null default 'open' check(status in ('open','partial_return','returned','cancelled')),
 location_id uuid references public.locations(id) on delete restrict, document_id uuid references public.stock_documents(id) on delete restrict,
 note text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.loan_items (
 id uuid primary key default gen_random_uuid(), loan_id uuid not null references public.loans(id) on delete restrict,
 book_id uuid not null references public.books(id) on delete restrict, quantity integer not null check(quantity>0),
 returned_quantity integer not null default 0 check(returned_quantity>=0 and returned_quantity<=quantity), note text, unique(loan_id,book_id)
);
create table if not exists public.consignments (
 id uuid primary key default gen_random_uuid(), consignment_number bigint generated always as identity unique,
 contact_id uuid not null references public.contacts(id) on delete restrict, deposit_date date not null default current_date, closed_date date,
 commission_rate numeric(5,2) not null default 30 check(commission_rate>=0 and commission_rate<=100),
 status text not null default 'open' check(status in ('open','closed','cancelled')), location_id uuid references public.locations(id) on delete restrict,
 document_id uuid references public.stock_documents(id) on delete restrict, note text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.consignment_items (
 id uuid primary key default gen_random_uuid(), consignment_id uuid not null references public.consignments(id) on delete restrict,
 book_id uuid not null references public.books(id) on delete restrict, quantity_deposited integer not null check(quantity_deposited>0),
 quantity_sold integer not null default 0 check(quantity_sold>=0), quantity_returned integer not null default 0 check(quantity_returned>=0),
 unit_price numeric(12,2) not null check(unit_price>=0), unique(consignment_id,book_id), check(quantity_sold+quantity_returned<=quantity_deposited)
);
create table if not exists public.consignment_sales (
 id uuid primary key default gen_random_uuid(), consignment_id uuid not null references public.consignments(id) on delete restrict,
 book_id uuid not null references public.books(id) on delete restrict, sale_date date not null default current_date,
 quantity integer not null check(quantity>0), unit_price numeric(12,2) not null check(unit_price>=0), gross_amount numeric(12,2) not null,
 commission_rate numeric(5,2) not null, commission_amount numeric(12,2) not null, net_amount_due numeric(12,2) not null,
 note text, document_id uuid references public.stock_documents(id) on delete restrict, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.consignment_payments (
 id uuid primary key default gen_random_uuid(), consignment_sale_id uuid not null references public.consignment_sales(id) on delete restrict,
 payment_date date not null default current_date, amount numeric(12,2) not null check(amount>0), payment_method text not null default 'virement',
 reference text, note text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);

create table if not exists public.expenses (
 id uuid primary key default gen_random_uuid(), expense_date date not null default current_date, category text not null default 'autre',
 book_id uuid references public.books(id) on delete restrict, object text, supplier text, amount numeric(12,2) not null check(amount>=0),
 paid_by text, payment_method text, receipt_reference text, status text not null default 'paid' check(status in ('paid','to_pay','cancelled')),
 notes text, source_legacy text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.crm_actions (
 id uuid primary key default gen_random_uuid(), contact_id uuid not null references public.contacts(id) on delete restrict,
 action_date date not null default current_date, channel text not null default 'email', summary text not null, response text, next_action text,
 due_date date, status text not null default 'done' check(status in ('planned','done','waiting','cancelled')),
 source_legacy text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.events (
 id uuid primary key default gen_random_uuid(), name text not null, event_type text not null default 'salon', city_region text,
 start_date date, end_date date, audience text, website text, organizer text, contact_email text, notes text, follow_up text,
 cost numeric(12,2), status text not null default 'to_review' check(status in ('to_review','to_contact','applied','confirmed','declined','completed','cancelled')),
 source_legacy text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(end_date is null or start_date is null or end_date>=start_date)
);
create table if not exists public.print_runs (
 id uuid primary key default gen_random_uuid(), print_run_number bigint generated always as identity unique,
 supplier_contact_id uuid references public.contacts(id) on delete restrict, order_date date not null default current_date, expected_date date,
 status text not null default 'ordered' check(status in ('draft','ordered','partially_received','received','cancelled')),
 supplier_reference text, note text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.print_run_items (
 id uuid primary key default gen_random_uuid(), print_run_id uuid not null references public.print_runs(id) on delete restrict,
 book_id uuid not null references public.books(id) on delete restrict, quantity_ordered integer not null check(quantity_ordered>0),
 quantity_received integer not null default 0 check(quantity_received>=0 and quantity_received<=quantity_ordered),
 unit_cost numeric(12,4) not null default 0 check(unit_cost>=0), note text, unique(print_run_id,book_id)
);
create table if not exists public.audit_logs (
 id bigint generated always as identity primary key, table_name text not null, record_id text, action text not null check(action in ('INSERT','UPDATE','DELETE')),
 actor_id uuid references auth.users(id), occurred_at timestamptz not null default now(), old_data jsonb, new_data jsonb
);
create index if not exists audit_logs_time on public.audit_logs(occurred_at desc);

-- Historique de toutes les modifications (y compris corrections, sans écrasement silencieux du journal de stock).
create or replace function public.audit_row_change() returns trigger language plpgsql security definer set search_path=public as $$
declare v_old jsonb; v_new jsonb; v_id text;
begin
 if tg_op='INSERT' then v_new=to_jsonb(new); v_id=v_new->>'id';
 elsif tg_op='UPDATE' then v_old=to_jsonb(old); v_new=to_jsonb(new); v_id=coalesce(v_new->>'id',v_old->>'id');
 else v_old=to_jsonb(old); v_id=v_old->>'id'; end if;
 insert into public.audit_logs(table_name,record_id,action,actor_id,old_data,new_data) values(tg_table_name,v_id,tg_op,auth.uid(),v_old,v_new);
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
do $$ declare t text; begin foreach t in array array['profiles','contacts','books','locations','stock_documents','stock_movements','sales','sale_items','payments','inventory_sessions','inventory_lines','loans','loan_items','consignments','consignment_items','consignment_sales','consignment_payments','expenses','crm_actions','events','print_runs','print_run_items'] loop
 execute format('drop trigger if exists audit_%I on public.%I',t,t); execute format('create trigger audit_%I after insert or update or delete on public.%I for each row execute function public.audit_row_change()',t,t); end loop; end $$;
create trigger profiles_updated before update on public.profiles for each row execute function public.set_updated_at();
create trigger contacts_updated before update on public.contacts for each row execute function public.set_updated_at();
create trigger books_updated before update on public.books for each row execute function public.set_updated_at();
create trigger expenses_updated before update on public.expenses for each row execute function public.set_updated_at();
create trigger crm_actions_updated before update on public.crm_actions for each row execute function public.set_updated_at();
create trigger events_updated before update on public.events for each row execute function public.set_updated_at();
create trigger print_runs_updated before update on public.print_runs for each row execute function public.set_updated_at();
create or replace function public.lock_stock_location_before_movement() returns trigger language plpgsql security definer set search_path=public as $$
begin perform 1 from public.locations where id=new.location_id for update; if not found then raise exception 'Localisation de stock introuvable.'; end if; return new; end $$;
create trigger stock_movements_lock_location before insert on public.stock_movements for each row execute function public.lock_stock_location_before_movement();

create or replace view public.v_book_stock with(security_invoker=true) as
select b.id book_id,
 coalesce(sum(m.quantity_delta) filter(where l.location_type='warehouse'),0)::integer warehouse_stock,
 coalesce(sum(m.quantity_delta) filter(where l.location_type='consignment'),0)::integer consignment_stock,
 coalesce(sum(m.quantity_delta) filter(where l.location_type='loan'),0)::integer loaned_stock,
 coalesce(sum(m.quantity_delta) filter(where l.location_type='damaged'),0)::integer damaged_stock,
 coalesce(sum(m.quantity_delta),0)::integer owned_stock
from public.books b left join public.stock_movements m on m.book_id=b.id left join public.locations l on l.id=m.location_id group by b.id;

-- RLS: lecture partagée entre utilisateurs authentifiés, mutations de stock uniquement via fonctions transactionnelles.
do $$ declare t text; begin foreach t in array array['profiles','contacts','books','locations','stock_documents','stock_movements','sales','sale_items','payments','inventory_sessions','inventory_lines','loans','loan_items','consignments','consignment_items','consignment_sales','consignment_payments','expenses','crm_actions','events','print_runs','print_run_items','audit_logs'] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;
do $$ declare t text; begin foreach t in array array['locations','stock_documents','stock_movements','sales','sale_items','payments','inventory_sessions','inventory_lines','loans','loan_items','consignments','consignment_items','consignment_sales','consignment_payments','print_runs','print_run_items','audit_logs'] loop
 execute format('drop policy if exists authenticated_read on public.%I',t); execute format('create policy authenticated_read on public.%I for select to authenticated using(auth.uid() is not null)',t); end loop; end $$;
create policy profiles_read on public.profiles for select to authenticated using(auth.uid() is not null);
create policy profiles_update_self on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy contacts_read on public.contacts for select to authenticated using(auth.uid() is not null);
create policy contacts_insert on public.contacts for insert to authenticated with check(auth.uid() is not null);
create policy contacts_update on public.contacts for update to authenticated using(auth.uid() is not null) with check(auth.uid() is not null);
create policy books_read on public.books for select to authenticated using(auth.uid() is not null);
create policy books_insert on public.books for insert to authenticated with check(auth.uid() is not null);
create policy books_update on public.books for update to authenticated using(auth.uid() is not null) with check(auth.uid() is not null);
create policy expenses_read on public.expenses for select to authenticated using(auth.uid() is not null);
create policy expenses_insert on public.expenses for insert to authenticated with check(auth.uid() is not null);
create policy expenses_update on public.expenses for update to authenticated using(auth.uid() is not null) with check(auth.uid() is not null);
create policy crm_read on public.crm_actions for select to authenticated using(auth.uid() is not null);
create policy crm_insert on public.crm_actions for insert to authenticated with check(auth.uid() is not null);
create policy crm_update on public.crm_actions for update to authenticated using(auth.uid() is not null) with check(auth.uid() is not null);
create policy events_read on public.events for select to authenticated using(auth.uid() is not null);
create policy events_insert on public.events for insert to authenticated with check(auth.uid() is not null);
create policy events_update on public.events for update to authenticated using(auth.uid() is not null) with check(auth.uid() is not null);
create policy print_runs_no_direct_write on public.print_runs for select to authenticated using(auth.uid() is not null);
create policy print_run_items_no_direct_write on public.print_run_items for select to authenticated using(auth.uid() is not null);

grant usage on schema public to authenticated;
grant select,insert,update on public.books,public.contacts,public.expenses,public.crm_actions,public.events to authenticated;
grant select on public.profiles,public.locations,public.stock_documents,public.stock_movements,public.sales,public.sale_items,public.payments,public.inventory_sessions,public.inventory_lines,public.loans,public.loan_items,public.consignments,public.consignment_items,public.consignment_sales,public.consignment_payments,public.print_runs,public.print_run_items,public.audit_logs,public.v_book_stock to authenticated;
grant usage,select on all sequences in schema public to authenticated;
-- Physical deletes and direct edits to journals are deliberately unavailable.
revoke delete on public.books,public.contacts,public.expenses,public.crm_actions,public.events from anon,authenticated;
revoke insert,update,delete on public.stock_documents,public.stock_movements,public.sales,public.sale_items,public.payments,public.inventory_sessions,public.inventory_lines,public.loans,public.loan_items,public.consignments,public.consignment_items,public.consignment_sales,public.consignment_payments,public.print_runs,public.print_run_items,public.audit_logs,public.locations from anon,authenticated;
