-- Fonctions atomiques des flux opérationnels. Aucune écriture directe dans le journal de stock depuis le client.
create or replace function public.create_sale(
 p_sale_date date,p_contact_id uuid,p_channel text,p_payment_method text,p_payment_amount numeric,p_shipping_charged numeric,p_note text,p_items jsonb
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_sale uuid;v_doc uuid;v_wh uuid;v_item jsonb;v_book uuid;v_qty integer;v_price numeric;v_available integer;v_total numeric:=0;
begin
 if auth.uid() is null then raise exception 'Authentification requise.'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'La vente doit comporter au moins un livre.'; end if;
 if coalesce(p_shipping_charged,0)<0 or coalesce(p_payment_amount,0)<0 then raise exception 'Un montant ne peut pas être négatif.'; end if;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_qty:=(v_item->>'quantity')::integer;v_price:=(v_item->>'unit_price')::numeric;
  if v_qty<=0 or v_price<0 then raise exception 'Quantité ou prix invalide.'; end if;v_total:=v_total+round(v_qty*v_price,2);
 end loop;
 if coalesce(p_payment_amount,0)>v_total+coalesce(p_shipping_charged,0)+0.001 then raise exception 'L’encaissement dépasse le montant total de la vente.'; end if;
 select id into v_wh from public.locations where location_type='warehouse' and is_default and is_active limit 1 for update;
 if v_wh is null then raise exception 'Stock principal introuvable.'; end if;
 insert into public.stock_documents(document_type,document_date,status,contact_id,note,created_by,validated_by,validated_at)
 values('sale',coalesce(p_sale_date,current_date),'validated',p_contact_id,p_note,auth.uid(),auth.uid(),now()) returning id into v_doc;
 insert into public.sales(sale_date,contact_id,channel,gross_amount,shipping_charged,note,document_id,created_by)
 values(coalesce(p_sale_date,current_date),p_contact_id,coalesce(nullif(p_channel,''),'direct'),v_total,coalesce(p_shipping_charged,0),p_note,v_doc,auth.uid()) returning id into v_sale;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_book:=(v_item->>'book_id')::uuid;v_qty:=(v_item->>'quantity')::integer;v_price:=(v_item->>'unit_price')::numeric;
  if not exists(select 1 from public.books where id=v_book and status='publie') then raise exception 'Livre introuvable ou non publié.'; end if;
  select coalesce(sum(quantity_delta),0)::integer into v_available from public.stock_movements where book_id=v_book and location_id=v_wh;
  if v_available<v_qty then raise exception 'Stock insuffisant pour le livre (disponible %, demandé %).',v_available,v_qty; end if;
  insert into public.sale_items(sale_id,book_id,quantity,unit_price,line_total) values(v_sale,v_book,v_qty,v_price,round(v_qty*v_price,2));
  insert into public.stock_movements(document_id,book_id,location_id,movement_type,quantity_delta,unit_price,contact_id,note,created_by)
  values(v_doc,v_book,v_wh,'sale',-v_qty,v_price,p_contact_id,'Vente V-'||(select sale_number from public.sales where id=v_sale),auth.uid());
 end loop;
 if coalesce(p_payment_amount,0)>0 then insert into public.payments(sale_id,payment_date,amount,payment_method,note,created_by)
 values(v_sale,coalesce(p_sale_date,current_date),p_payment_amount,coalesce(nullif(p_payment_method,''),'autre'),p_note,auth.uid()); end if;
 return v_sale;
end $$;

create or replace function public.record_sale_payment(p_sale_id uuid,p_payment_date date,p_amount numeric,p_payment_method text,p_reference text default null,p_note text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_sale public.sales%rowtype;v_total numeric;v_paid numeric;v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentification requise.'; end if;if p_amount is null or p_amount<=0 then raise exception 'Le règlement doit être positif.';end if;
 select * into v_sale from public.sales where id=p_sale_id for update;
 if not found or v_sale.status<>'recorded' then raise exception 'Vente introuvable ou non active.';end if;
 v_total:=v_sale.gross_amount+v_sale.shipping_charged;select coalesce(sum(amount),0) into v_paid from public.payments where sale_id=p_sale_id;
 if p_amount>v_total-v_paid+0.001 then raise exception 'Le règlement dépasse le solde restant de la vente (% €).',round(v_total-v_paid,2);end if;
 insert into public.payments(sale_id,payment_date,amount,payment_method,reference,note,created_by) values(p_sale_id,coalesce(p_payment_date,current_date),p_amount,coalesce(nullif(p_payment_method,''),'autre'),p_reference,p_note,auth.uid()) returning id into v_id;return v_id;
end $$;

create or replace function public.create_stock_operation(p_movement_type text,p_book_id uuid,p_quantity integer,p_contact_id uuid,p_movement_date date,p_reference text,p_note text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_wh uuid;v_doc uuid;v_available integer;v_delta integer;
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;
 if p_movement_type not in ('donation','loss') then raise exception 'Utilisez uniquement Don ou Perte/Casse ici.';end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'La quantité doit être positive.';end if;
 select id into v_wh from public.locations where location_type='warehouse' and is_default and is_active limit 1 for update;
 if v_wh is null then raise exception 'Stock principal introuvable.';end if;
 select coalesce(sum(quantity_delta),0)::integer into v_available from public.stock_movements where book_id=p_book_id and location_id=v_wh;
 if v_available<p_quantity then raise exception 'Stock insuffisant (disponible %, demandé %).',v_available,p_quantity;end if;
 insert into public.stock_documents(document_type,document_date,status,contact_id,reference,note,created_by,validated_by,validated_at)
 values(p_movement_type,coalesce(p_movement_date,current_date),'validated',p_contact_id,p_reference,p_note,auth.uid(),auth.uid(),now()) returning id into v_doc;
 v_delta:=-p_quantity;
 insert into public.stock_movements(document_id,book_id,location_id,movement_type,quantity_delta,contact_id,reference,note,created_by)
 values(v_doc,p_book_id,v_wh,p_movement_type,v_delta,p_contact_id,p_reference,p_note,auth.uid());return v_doc;
end $$;

create or replace function public.start_inventory(p_location_id uuid default null,p_inventory_date date default current_date,p_note text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;v_location uuid;
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;v_location:=p_location_id;
 if v_location is null then select id into v_location from public.locations where location_type='warehouse' and is_default and is_active limit 1;end if;
 if v_location is null then raise exception 'Stock principal introuvable.';end if;
 insert into public.inventory_sessions(inventory_date,location_id,status,note,created_by) values(coalesce(p_inventory_date,current_date),v_location,'in_progress',p_note,auth.uid()) returning id into v_id;
 insert into public.inventory_lines(inventory_session_id,book_id,location_id,theoretical_quantity)
 select v_id,b.id,v_location,coalesce((select sum(m.quantity_delta)::integer from public.stock_movements m where m.book_id=b.id and m.location_id=v_location),0)
 from public.books b where b.status<>'suspendu';return v_id;
end $$;
create or replace function public.save_inventory_counts(p_inventory_id uuid,p_counts jsonb) returns void language plpgsql security definer set search_path=public as $$
declare v_item jsonb;v_book uuid;v_count integer;
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;
 if not exists(select 1 from public.inventory_sessions where id=p_inventory_id and status='in_progress') then raise exception 'Cet inventaire n’est pas modifiable.';end if;
 if jsonb_typeof(p_counts)<>'array' then raise exception 'Comptage invalide.';end if;
 for v_item in select value from jsonb_array_elements(p_counts) loop v_book:=(v_item->>'book_id')::uuid;v_count:=(v_item->>'counted_quantity')::integer;
  if v_count<0 then raise exception 'La quantité comptée ne peut être négative.';end if;
  update public.inventory_lines set counted_quantity=v_count,note=nullif(v_item->>'note','') where inventory_session_id=p_inventory_id and book_id=v_book;
  if not found then raise exception 'Livre non associé à cet inventaire.';end if;
 end loop;
end $$;
create or replace function public.validate_inventory(p_inventory_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare v_session public.inventory_sessions%rowtype;v_doc uuid;v_line record;v_diff integer;v_current integer;v_opening boolean;v_tome integer;
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;
 select * into v_session from public.inventory_sessions where id=p_inventory_id for update;
 if not found or v_session.status<>'in_progress' then raise exception 'Inventaire introuvable ou déjà validé.';end if;
 perform 1 from public.locations where id=v_session.location_id for update;
 if exists(select 1 from public.inventory_lines where inventory_session_id=p_inventory_id and counted_quantity is null) then raise exception 'Tous les livres doivent être comptés, y compris les zéros.';end if;
 v_opening:=not exists(select 1 from public.stock_movements where location_id=v_session.location_id);
 for v_line in select * from public.inventory_lines where inventory_session_id=p_inventory_id loop
  select coalesce(sum(quantity_delta),0)::integer into v_current from public.stock_movements where book_id=v_line.book_id and location_id=v_line.location_id;
  if v_current<>v_line.theoretical_quantity then select tome_number into v_tome from public.books where id=v_line.book_id;raise exception 'Le stock du tome % a changé depuis le début du comptage. Annulez et recommencez l’inventaire.',v_tome;end if;
 end loop;
 insert into public.stock_documents(document_type,document_date,status,note,inventory_session_id,created_by,validated_by,validated_at)
 values(case when v_opening then 'opening_inventory' else 'inventory_adjustment' end,v_session.inventory_date,'validated',coalesce(v_session.note,'Inventaire')||' — INV-'||v_session.inventory_number,p_inventory_id,auth.uid(),auth.uid(),now()) returning id into v_doc;
 for v_line in select * from public.inventory_lines where inventory_session_id=p_inventory_id loop
  v_diff:=v_line.counted_quantity-v_line.theoretical_quantity;update public.inventory_lines set difference=v_diff where id=v_line.id;
  if v_diff<>0 then insert into public.stock_movements(document_id,book_id,location_id,movement_type,quantity_delta,inventory_session_id,note,created_by)
   values(v_doc,v_line.book_id,v_line.location_id,case when v_opening then 'opening' else 'inventory_adjustment' end,v_diff,p_inventory_id,coalesce(nullif(v_line.note,''),case when v_opening then 'Stock initial constaté par inventaire physique' else 'Écart d’inventaire' end),auth.uid());end if;
 end loop;
 update public.inventory_sessions set status='validated',validated_by=auth.uid(),validated_at=now() where id=p_inventory_id;
end $$;
create or replace function public.cancel_inventory(p_inventory_id uuid,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null then raise exception 'Authentification requise.';end if;update public.inventory_sessions set status='cancelled',note=concat_ws(' — ',nullif(note,''),nullif(trim(coalesce(p_note,'')),'')) where id=p_inventory_id and status='in_progress';if not found then raise exception 'Seul un inventaire en cours peut être annulé.';end if;end $$;

create or replace function public.create_loan(p_contact_id uuid,p_loan_date date,p_due_date date,p_note text,p_items jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare v_loan uuid;v_loc uuid;v_doc uuid;v_wh uuid;v_item jsonb;v_book uuid;v_qty integer;v_avail integer;v_num bigint;v_group uuid;
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Ajoutez au moins un livre.';end if;
 select id into v_wh from public.locations where location_type='warehouse' and is_default and is_active limit 1 for update;if v_wh is null then raise exception 'Stock principal introuvable.';end if;
 insert into public.loans(contact_id,loan_date,due_date,status,note,created_by) values(p_contact_id,coalesce(p_loan_date,current_date),p_due_date,'open',p_note,auth.uid()) returning id,loan_number into v_loan,v_num;
 insert into public.locations(name,location_type,contact_id,notes,created_by) values('Prêt PR-'||v_num,'loan',p_contact_id,p_note,auth.uid()) returning id into v_loc;update public.loans set location_id=v_loc where id=v_loan;
 insert into public.stock_documents(document_type,document_date,status,contact_id,note,created_by,validated_by,validated_at) values('loan',coalesce(p_loan_date,current_date),'validated',p_contact_id,p_note,auth.uid(),auth.uid(),now()) returning id into v_doc;update public.loans set document_id=v_doc where id=v_loan;
 for v_item in select value from jsonb_array_elements(p_items) loop v_book:=(v_item->>'book_id')::uuid;v_qty:=(v_item->>'quantity')::integer;if v_qty<=0 then raise exception 'Quantité de prêt invalide.';end if;
  select coalesce(sum(quantity_delta),0)::integer into v_avail from public.stock_movements where book_id=v_book and location_id=v_wh;if v_avail<v_qty then raise exception 'Stock insuffisant pour ce prêt (disponible %, demandé %).',v_avail,v_qty;end if;
  insert into public.loan_items(loan_id,book_id,quantity) values(v_loan,v_book,v_qty);v_group:=gen_random_uuid();
  insert into public.stock_movements(group_id,document_id,book_id,location_id,movement_type,quantity_delta,contact_id,note,created_by) values(v_group,v_doc,v_book,v_wh,'loan_out',-v_qty,p_contact_id,'Sortie en prêt PR-'||v_num,auth.uid());
  insert into public.stock_movements(group_id,document_id,book_id,location_id,movement_type,quantity_delta,contact_id,note,created_by) values(v_group,v_doc,v_book,v_loc,'loan_out',v_qty,p_contact_id,'Localisation prêt PR-'||v_num,auth.uid());
 end loop;return v_loan;
end $$;
create or replace function public.return_loan(p_loan_id uuid,p_items jsonb,p_return_date date default current_date,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
declare v_loan public.loans%rowtype;v_wh uuid;v_doc uuid;v_item jsonb;v_book uuid;v_qty integer;v_remaining integer;v_group uuid;
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;select * into v_loan from public.loans where id=p_loan_id for update;if not found or v_loan.status in('returned','cancelled') then raise exception 'Prêt introuvable ou clôturé.';end if;
 select id into v_wh from public.locations where location_type='warehouse' and is_default and is_active limit 1 for update;
 insert into public.stock_documents(document_type,document_date,status,contact_id,note,created_by,validated_by,validated_at) values('loan_return',coalesce(p_return_date,current_date),'validated',v_loan.contact_id,p_note,auth.uid(),auth.uid(),now()) returning id into v_doc;
 for v_item in select value from jsonb_array_elements(p_items) loop v_book:=(v_item->>'book_id')::uuid;v_qty:=(v_item->>'quantity')::integer;
  select quantity-returned_quantity into v_remaining from public.loan_items where loan_id=p_loan_id and book_id=v_book for update;if v_remaining is null or v_qty<=0 or v_qty>v_remaining then raise exception 'Quantité retournée invalide.';end if;
  update public.loan_items set returned_quantity=returned_quantity+v_qty where loan_id=p_loan_id and book_id=v_book;v_group:=gen_random_uuid();
  insert into public.stock_movements(group_id,document_id,book_id,location_id,movement_type,quantity_delta,contact_id,note,created_by) values(v_group,v_doc,v_book,v_loan.location_id,'loan_return',-v_qty,v_loan.contact_id,'Retour de prêt PR-'||v_loan.loan_number,auth.uid());
  insert into public.stock_movements(group_id,document_id,book_id,location_id,movement_type,quantity_delta,contact_id,note,created_by) values(v_group,v_doc,v_book,v_wh,'loan_return',v_qty,v_loan.contact_id,'Retour de prêt PR-'||v_loan.loan_number,auth.uid());
 end loop;
 if not exists(select 1 from public.loan_items where loan_id=p_loan_id and returned_quantity<quantity) then update public.loans set status='returned',returned_date=coalesce(p_return_date,current_date) where id=p_loan_id;else update public.loans set status='partial_return' where id=p_loan_id;end if;
end $$;

create or replace function public.create_consignment(p_contact_id uuid,p_deposit_date date,p_commission_rate numeric,p_note text,p_items jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare v_con uuid;v_loc uuid;v_doc uuid;v_wh uuid;v_item jsonb;v_book uuid;v_qty integer;v_price numeric;v_avail integer;v_num bigint;v_group uuid;
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;if p_commission_rate<0 or p_commission_rate>100 then raise exception 'Commission entre 0 et 100 %.';end if;if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Ajoutez au moins un livre au dépôt.';end if;
 select id into v_wh from public.locations where location_type='warehouse' and is_default and is_active limit 1 for update;if v_wh is null then raise exception 'Stock principal introuvable.';end if;
 insert into public.consignments(contact_id,deposit_date,commission_rate,status,note,created_by) values(p_contact_id,coalesce(p_deposit_date,current_date),p_commission_rate,'open',p_note,auth.uid()) returning id,consignment_number into v_con,v_num;
 insert into public.locations(name,location_type,contact_id,notes,created_by) values('Dépôt-vente DV-'||v_num,'consignment',p_contact_id,p_note,auth.uid()) returning id into v_loc;update public.consignments set location_id=v_loc where id=v_con;
 insert into public.stock_documents(document_type,document_date,status,contact_id,note,created_by,validated_by,validated_at) values('consignment',coalesce(p_deposit_date,current_date),'validated',p_contact_id,p_note,auth.uid(),auth.uid(),now()) returning id into v_doc;update public.consignments set document_id=v_doc where id=v_con;
 for v_item in select value from jsonb_array_elements(p_items) loop v_book:=(v_item->>'book_id')::uuid;v_qty:=(v_item->>'quantity')::integer;v_price:=(v_item->>'unit_price')::numeric;if v_qty<=0 or v_price<0 then raise exception 'Quantité ou prix invalide.';end if;
  select coalesce(sum(quantity_delta),0)::integer into v_avail from public.stock_movements where book_id=v_book and location_id=v_wh;if v_avail<v_qty then raise exception 'Stock insuffisant pour dépôt-vente (disponible %, demandé %).',v_avail,v_qty;end if;
  insert into public.consignment_items(consignment_id,book_id,quantity_deposited,unit_price) values(v_con,v_book,v_qty,v_price);v_group:=gen_random_uuid();
  insert into public.stock_movements(group_id,document_id,book_id,location_id,movement_type,quantity_delta,contact_id,unit_price,note,created_by) values(v_group,v_doc,v_book,v_wh,'consignment_out',-v_qty,p_contact_id,v_price,'Sortie vers DV-'||v_num,auth.uid());
  insert into public.stock_movements(group_id,document_id,book_id,location_id,movement_type,quantity_delta,contact_id,unit_price,note,created_by) values(v_group,v_doc,v_book,v_loc,'consignment_out',v_qty,p_contact_id,v_price,'Localisation dépôt-vente DV-'||v_num,auth.uid());
 end loop;return v_con;
end $$;
create or replace function public.record_consignment_sale(p_consignment_id uuid,p_book_id uuid,p_quantity integer,p_unit_price numeric,p_sale_date date default current_date,p_note text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare v_con public.consignments%rowtype;v_line public.consignment_items%rowtype;v_doc uuid;v_sale uuid;v_remaining integer;v_gross numeric;v_fee numeric;v_net numeric;
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;select * into v_con from public.consignments where id=p_consignment_id for update;if not found or v_con.status<>'open' then raise exception 'Dépôt introuvable ou clôturé.';end if;
 select * into v_line from public.consignment_items where consignment_id=p_consignment_id and book_id=p_book_id for update;if not found then raise exception 'Livre non présent dans ce dépôt.';end if;
 v_remaining:=v_line.quantity_deposited-v_line.quantity_sold-v_line.quantity_returned;if p_quantity<=0 or p_quantity>v_remaining or p_unit_price<0 then raise exception 'Quantité de vente invalide (reste %).',v_remaining;end if;
 v_gross:=round(p_quantity*p_unit_price,2);v_fee:=round(v_gross*v_con.commission_rate/100,2);v_net:=v_gross-v_fee;
 insert into public.stock_documents(document_type,document_date,status,contact_id,note,created_by,validated_by,validated_at) values('consignment_sale',coalesce(p_sale_date,current_date),'validated',v_con.contact_id,p_note,auth.uid(),auth.uid(),now()) returning id into v_doc;
 insert into public.stock_movements(document_id,book_id,location_id,movement_type,quantity_delta,contact_id,unit_price,note,created_by) values(v_doc,p_book_id,v_con.location_id,'consignment_sale',-p_quantity,v_con.contact_id,p_unit_price,'Vente déclarée chez le dépositaire',auth.uid());
 update public.consignment_items set quantity_sold=quantity_sold+p_quantity where id=v_line.id;
 insert into public.consignment_sales(consignment_id,book_id,sale_date,quantity,unit_price,gross_amount,commission_rate,commission_amount,net_amount_due,note,document_id,created_by) values(p_consignment_id,p_book_id,coalesce(p_sale_date,current_date),p_quantity,p_unit_price,v_gross,v_con.commission_rate,v_fee,v_net,p_note,v_doc,auth.uid()) returning id into v_sale;return v_sale;
end $$;
create or replace function public.return_consignment_stock(p_consignment_id uuid,p_items jsonb,p_close boolean default false,p_return_date date default current_date,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
declare v_con public.consignments%rowtype;v_wh uuid;v_doc uuid;v_item jsonb;v_book uuid;v_qty integer;v_remaining integer;v_group uuid;
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;select * into v_con from public.consignments where id=p_consignment_id for update;if not found or v_con.status<>'open' then raise exception 'Dépôt introuvable ou clôturé.';end if;
 select id into v_wh from public.locations where location_type='warehouse' and is_default and is_active limit 1 for update;
 insert into public.stock_documents(document_type,document_date,status,contact_id,note,created_by,validated_by,validated_at) values('consignment_return',coalesce(p_return_date,current_date),'validated',v_con.contact_id,p_note,auth.uid(),auth.uid(),now()) returning id into v_doc;
 for v_item in select value from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop v_book:=(v_item->>'book_id')::uuid;v_qty:=(v_item->>'quantity')::integer;select quantity_deposited-quantity_sold-quantity_returned into v_remaining from public.consignment_items where consignment_id=p_consignment_id and book_id=v_book for update;
  if v_remaining is null or v_qty<=0 or v_qty>v_remaining then raise exception 'Quantité retournée invalide.';end if;update public.consignment_items set quantity_returned=quantity_returned+v_qty where consignment_id=p_consignment_id and book_id=v_book;v_group:=gen_random_uuid();
  insert into public.stock_movements(group_id,document_id,book_id,location_id,movement_type,quantity_delta,contact_id,note,created_by) values(v_group,v_doc,v_con.location_id,'consignment_return',-v_qty,v_con.contact_id,'Retour invendus DV-'||v_con.consignment_number,auth.uid());
  insert into public.stock_movements(group_id,document_id,book_id,location_id,movement_type,quantity_delta,contact_id,note,created_by) values(v_group,v_doc,v_book,v_wh,'consignment_return',v_qty,v_con.contact_id,'Retour en stock principal DV-'||v_con.consignment_number,auth.uid());
 end loop;
 if p_close then if exists(select 1 from public.consignment_items where consignment_id=p_consignment_id and quantity_sold+quantity_returned<quantity_deposited) then raise exception 'Des exemplaires sont encore chez le dépositaire.';end if;update public.consignments set status='closed',closed_date=coalesce(p_return_date,current_date) where id=p_consignment_id;end if;
end $$;
create or replace function public.record_consignment_payment(p_consignment_sale_id uuid,p_amount numeric,p_payment_date date default current_date,p_payment_method text default 'virement',p_reference text default null,p_note text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare v_due numeric;v_paid numeric;v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentification requise.';end if;if p_amount<=0 then raise exception 'Montant de règlement positif requis.';end if;
 select net_amount_due into v_due from public.consignment_sales where id=p_consignment_sale_id for update;if v_due is null then raise exception 'Vente en dépôt-vente introuvable.';end if;select coalesce(sum(amount),0) into v_paid from public.consignment_payments where consignment_sale_id=p_consignment_sale_id;
 if p_amount>v_due-v_paid+0.001 then raise exception 'Le règlement dépasse le solde net dû (% €).',round(v_due-v_paid,2);end if;
 insert into public.consignment_payments(consignment_sale_id,payment_date,amount,payment_method,reference,note,created_by) values(p_consignment_sale_id,coalesce(p_payment_date,current_date),p_amount,coalesce(p_payment_method,'virement'),p_reference,p_note,auth.uid()) returning id into v_id;return v_id;
end $$;

-- Réimpression : une commande ne change jamais le stock ; chaque réception réelle le fait.
create or replace function public.create_print_run(p_supplier_contact_id uuid,p_order_date date,p_expected_date date,p_supplier_reference text,p_note text,p_items jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare v_run uuid;v_item jsonb;v_book uuid;v_qty integer;v_cost numeric;
begin if auth.uid() is null then raise exception 'Authentification requise.';end if;if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Ajoutez au moins un titre.';end if;
 insert into public.print_runs(supplier_contact_id,order_date,expected_date,status,supplier_reference,note,created_by) values(p_supplier_contact_id,coalesce(p_order_date,current_date),p_expected_date,'ordered',p_supplier_reference,p_note,auth.uid()) returning id into v_run;
 for v_item in select value from jsonb_array_elements(p_items) loop v_book:=(v_item->>'book_id')::uuid;v_qty:=(v_item->>'quantity_ordered')::integer;v_cost:=coalesce((v_item->>'unit_cost')::numeric,0);if v_qty<=0 or v_cost<0 then raise exception 'Quantité ou coût unitaire invalide.';end if;
 insert into public.print_run_items(print_run_id,book_id,quantity_ordered,unit_cost,note) values(v_run,v_book,v_qty,v_cost,nullif(v_item->>'note',''));end loop;return v_run;end $$;
create or replace function public.receive_print_run(p_print_run_id uuid,p_receive_date date,p_items jsonb,p_reference text,p_note text) returns void language plpgsql security definer set search_path=public as $$
declare v_run public.print_runs%rowtype;v_item jsonb;v_book uuid;v_qty integer;v_line public.print_run_items%rowtype;v_doc uuid;v_wh uuid;
begin if auth.uid() is null then raise exception 'Authentification requise.';end if;select * into v_run from public.print_runs where id=p_print_run_id for update;if not found or v_run.status in('received','cancelled','draft') then raise exception 'Commande non recevable.';end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Saisissez les quantités réceptionnées.';end if;select id into v_wh from public.locations where location_type='warehouse' and is_default and is_active limit 1 for update;
 insert into public.stock_documents(document_type,document_date,status,contact_id,reference,note,created_by,validated_by,validated_at) values('print_receipt',coalesce(p_receive_date,current_date),'validated',v_run.supplier_contact_id,coalesce(p_reference,v_run.supplier_reference),p_note,auth.uid(),auth.uid(),now()) returning id into v_doc;
 for v_item in select value from jsonb_array_elements(p_items) loop v_book:=(v_item->>'book_id')::uuid;v_qty:=(v_item->>'quantity_received')::integer;if v_qty<=0 then raise exception 'Quantité reçue positive requise.';end if;
 select * into v_line from public.print_run_items where print_run_id=p_print_run_id and book_id=v_book for update;if not found or v_qty>v_line.quantity_ordered-v_line.quantity_received then raise exception 'Réception supérieure au restant à recevoir.';end if;
 update public.print_run_items set quantity_received=quantity_received+v_qty where id=v_line.id;
 insert into public.stock_movements(document_id,book_id,location_id,movement_type,quantity_delta,unit_cost,contact_id,reference,note,created_by) values(v_doc,v_book,v_wh,'print_receipt',v_qty,v_line.unit_cost,v_run.supplier_contact_id,coalesce(p_reference,v_run.supplier_reference),coalesce(p_note,'Réception tirage TIR-'||v_run.print_run_number),auth.uid());end loop;
 if not exists(select 1 from public.print_run_items where print_run_id=p_print_run_id and quantity_received<quantity_ordered) then update public.print_runs set status='received' where id=p_print_run_id;else update public.print_runs set status='partially_received' where id=p_print_run_id;end if;end $$;

-- Droits d'exécution explicites.
grant execute on function public.create_sale(date,uuid,text,text,numeric,numeric,text,jsonb) to authenticated;
grant execute on function public.record_sale_payment(uuid,date,numeric,text,text,text) to authenticated;
grant execute on function public.create_stock_operation(text,uuid,integer,uuid,date,text,text) to authenticated;
grant execute on function public.start_inventory(uuid,date,text) to authenticated;
grant execute on function public.save_inventory_counts(uuid,jsonb) to authenticated;
grant execute on function public.validate_inventory(uuid) to authenticated;
grant execute on function public.cancel_inventory(uuid,text) to authenticated;
grant execute on function public.create_loan(uuid,date,date,text,jsonb) to authenticated;
grant execute on function public.return_loan(uuid,jsonb,date,text) to authenticated;
grant execute on function public.create_consignment(uuid,date,numeric,text,jsonb) to authenticated;
grant execute on function public.record_consignment_sale(uuid,uuid,integer,numeric,date,text) to authenticated;
grant execute on function public.return_consignment_stock(uuid,jsonb,boolean,date,text) to authenticated;
grant execute on function public.record_consignment_payment(uuid,numeric,date,text,text,text) to authenticated;
grant execute on function public.create_print_run(uuid,date,date,text,text,jsonb) to authenticated;
grant execute on function public.receive_print_run(uuid,date,jsonb,text,text) to authenticated;
