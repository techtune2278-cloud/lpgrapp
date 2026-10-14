-- LPGRAPP 0.4 : reprise versionnée, sans effet sur le stock actif.
BEGIN;
CREATE TABLE IF NOT EXISTS public.workbook_imports(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), sha256 text NOT NULL UNIQUE CHECK(length(sha256)=64),
 source_name text NOT NULL, source_key text NOT NULL UNIQUE,
 is_current boolean NOT NULL DEFAULT false, summary jsonb NOT NULL, sheets jsonb NOT NULL,
 imported_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS workbook_one_current ON public.workbook_imports(is_current) WHERE is_current;
CREATE TABLE IF NOT EXISTS public.historical_orders(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), import_id uuid NOT NULL REFERENCES public.workbook_imports(id),
 reference text NOT NULL, contact_id uuid REFERENCES public.contacts(id), customer_name text NOT NULL,
 channel text, source_sale_date date, source_received numeric(12,2),
 classification text NOT NULL DEFAULT 'unclassified' CHECK(classification IN('sale','subscription','donation','consignment','loan','unclassified')),
 flags jsonb NOT NULL DEFAULT '[]', review_status text NOT NULL DEFAULT 'to_review' CHECK(review_status IN('to_review','accepted','needs_clarification','ignored')),
 confirmed_sale_date date, confirmed_total numeric(12,2) CHECK(confirmed_total>=0),
 confirmed_received numeric(12,2) CHECK(confirmed_received>=0), review_note text,
 reviewed_by uuid REFERENCES auth.users(id), reviewed_at timestamptz,
 UNIQUE(import_id,reference)
);
CREATE INDEX IF NOT EXISTS historical_orders_contact ON public.historical_orders(contact_id);
CREATE INDEX IF NOT EXISTS historical_orders_import ON public.historical_orders(import_id,reference);
CREATE TABLE IF NOT EXISTS public.historical_order_lines(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL REFERENCES public.historical_orders(id),
 source_row integer NOT NULL, book_id uuid REFERENCES public.books(id), tome_number integer,
 source_quantity integer, source_unit_price numeric(12,2), source_line_total numeric(12,2),
 source_received numeric(12,2), payment_method text, source_note text,
 confirmed_quantity integer CHECK(confirmed_quantity>=0), delivered_quantity integer CHECK(delivered_quantity>=0),
 UNIQUE(order_id,source_row), CHECK(delivered_quantity IS NULL OR (confirmed_quantity IS NOT NULL AND delivered_quantity<=confirmed_quantity))
);
CREATE TABLE IF NOT EXISTS public.workbook_stock_observations(
 import_id uuid NOT NULL REFERENCES public.workbook_imports(id), book_id uuid NOT NULL REFERENCES public.books(id),
 initial_quantity integer, reprint_quantity integer, source_quantity integer, theoretical_quantity integer,
 physical_quantity integer CHECK(physical_quantity>=0), PRIMARY KEY(import_id,book_id)
);
CREATE TABLE IF NOT EXISTS public.workbook_resources(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, import_id uuid NOT NULL REFERENCES public.workbook_imports(id),
 section text NOT NULL, sheet_name text NOT NULL, row_number integer NOT NULL, row_values jsonb NOT NULL,
 UNIQUE(import_id,sheet_name,row_number)
);
CREATE TABLE IF NOT EXISTS public.workbook_row_metadata(
 import_id uuid NOT NULL REFERENCES public.workbook_imports(id), sheet_name text NOT NULL, row_number integer NOT NULL,
 row_kind text NOT NULL, metadata jsonb NOT NULL DEFAULT '{}', PRIMARY KEY(import_id,sheet_name,row_number)
);
CREATE TABLE IF NOT EXISTS public.workbook_reconciliation(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, import_id uuid NOT NULL REFERENCES public.workbook_imports(id),
 entity text NOT NULL, reference text NOT NULL, source_value jsonb, current_value jsonb, resolution text NOT NULL,
 UNIQUE(import_id,entity,reference)
);
CREATE TABLE IF NOT EXISTS public.workbook_inventory_preparations(
 import_id uuid PRIMARY KEY REFERENCES public.workbook_imports(id), inventory_id uuid NOT NULL REFERENCES public.inventory_sessions(id),
 prepared_by uuid NOT NULL REFERENCES auth.users(id), prepared_at timestamptz NOT NULL DEFAULT now()
);
CREATE OR REPLACE FUNCTION app_private.contact_key(p_text text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT regexp_replace(translate(lower(trim(replace(coalesce(p_text,''),'’',''''))),'àâäéèêëîïôöùûüç','aaaeeeeiioouuuc'),'\s+',' ','g')
$$;
REVOKE ALL ON FUNCTION app_private.contact_key(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION app_private.contact_key(text) TO authenticated,service_role;

-- Réservé au SQL Editor ou à service_role. Jamais appelé avec une clé navigateur.
CREATE OR REPLACE FUNCTION public.import_workbook_snapshot(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE batch_id uuid; sk text; o jsonb; l jsonb; r jsonb; c uuid; order_id uuid; b uuid;
 match_count integer; n integer; old_amount numeric; new_amount numeric;
BEGIN
 IF NOT (coalesce(auth.role(),'')='service_role' OR session_user IN('postgres','supabase_admin')) THEN
  RAISE EXCEPTION 'Import réservé à l’administration.' USING ERRCODE='42501';
 END IF;
 IF p->>'format_version'<>'1' OR (p->>'sha256') !~ '^[a-f0-9]{64}$' OR jsonb_typeof(p->'rows')<>'array' OR jsonb_typeof(p->'orders')<>'array' THEN
  RAISE EXCEPTION 'Format de reprise invalide.';
 END IF;
 PERFORM pg_advisory_xact_lock(409204,1);
 SELECT id INTO batch_id FROM public.workbook_imports WHERE sha256=p->>'sha256';
 IF batch_id IS NOT NULL THEN RETURN jsonb_build_object('status','already_imported','import_id',batch_id,'message','Aucune donnée ni décision remplacée.'); END IF;
 sk='workbook:'||(p->>'sha256');
 INSERT INTO public.workbook_imports(sha256,source_name,source_key,summary,sheets)
 VALUES(p->>'sha256',p->>'source_name',sk,p->'summary',p->'sheets') RETURNING id INTO batch_id;
 INSERT INTO public.legacy_import_rows(source_file,sheet_name,row_number,row_values,row_formulas,row_hash,source_address)
 SELECT sk,x->>'sheet_name',(x->>'row_number')::integer,x->'values',x->'formulas',x->>'hash',x->>'kind'
 FROM jsonb_array_elements(p->'rows') x;
 INSERT INTO public.workbook_row_metadata(import_id,sheet_name,row_number,row_kind,metadata)
 SELECT batch_id,x->>'sheet_name',(x->>'row_number')::integer,x->>'kind',x->'metadata' FROM jsonb_array_elements(p->'rows') x;
 FOR o IN SELECT value FROM jsonb_array_elements(p->'orders') LOOP
  c=NULL;
  SELECT count(*),(array_agg(id ORDER BY id))[1] INTO match_count,c FROM public.contacts
  WHERE app_private.contact_key(name)=app_private.contact_key(o->>'customer_name');
  IF match_count=0 THEN
   INSERT INTO public.contacts(name,contact_type,source_legacy,notes)
   VALUES(o->>'customer_name','autre','workbook:contact:'||md5(app_private.contact_key(o->>'customer_name')),'Contact repris des ventes Excel. Aucune autorisation de prospection déduite.')
   ON CONFLICT (source_legacy) WHERE source_legacy IS NOT NULL DO NOTHING;
   SELECT id INTO c FROM public.contacts WHERE source_legacy='workbook:contact:'||md5(app_private.contact_key(o->>'customer_name'));
  ELSIF match_count>1 THEN
   c=NULL;
   o=jsonb_set(o,'{flags}',(o->'flags')||jsonb_build_array('Plusieurs contacts possibles : rapprochement manuel requis'));
  END IF;
  INSERT INTO public.historical_orders(import_id,reference,contact_id,customer_name,channel,source_sale_date,source_received,classification,flags)
  VALUES(batch_id,o->>'reference',c,o->>'customer_name',o->>'channel',(o->>'sale_date')::date,(o->>'source_received')::numeric,o->>'classification',o->'flags') RETURNING id INTO order_id;
  FOR l IN SELECT value FROM jsonb_array_elements(o->'lines') LOOP
   b=NULL; SELECT id INTO b FROM public.books WHERE tome_number=(l->>'tome_number')::integer;
   INSERT INTO public.historical_order_lines(order_id,source_row,book_id,tome_number,source_quantity,source_unit_price,source_line_total,source_received,payment_method,source_note)
   VALUES(order_id,(l->>'row_number')::integer,b,(l->>'tome_number')::integer,(l->>'quantity')::integer,(l->>'unit_price')::numeric,(l->>'line_total')::numeric,(l->>'amount_received')::numeric,l->>'payment_method',l->>'note');
  END LOOP;
 END LOOP;
 INSERT INTO public.workbook_stock_observations(import_id,book_id,initial_quantity,reprint_quantity,source_quantity,theoretical_quantity,physical_quantity)
 SELECT batch_id,b.id,(x->>'initial_quantity')::integer,(x->>'reprint_quantity')::integer,(x->>'source_quantity')::integer,(x->>'theoretical_quantity')::integer,(x->>'physical_quantity')::integer
 FROM jsonb_array_elements(p->'stocks') x JOIN public.books b ON b.tome_number=(x->>'tome_number')::integer;
 -- Compléments manquants uniquement : ne pas écraser les modifications faites dans l’app.
 UPDATE public.books b SET subtitle=coalesce(nullif(b.subtitle,''),nullif(x->>'subtitle','')),publisher=coalesce(nullif(b.publisher,''),nullif(x->>'publisher',''))
 FROM jsonb_array_elements(p->'editorial') x WHERE b.tome_number=(x->>'tome_number')::integer AND ((b.subtitle IS NULL AND nullif(x->>'subtitle','') IS NOT NULL) OR (b.publisher IS NULL AND nullif(x->>'publisher','') IS NOT NULL));
 FOR r IN SELECT value FROM jsonb_array_elements(p->'expenses') LOOP
  SELECT amount INTO old_amount FROM public.expenses WHERE source_legacy='excel:06 DEPENSES:'||(r->>'reference');
  new_amount=(r->>'amount')::numeric;
  IF NOT FOUND THEN
   INSERT INTO public.expenses(expense_date,category,object,supplier,amount,paid_by,status,notes,source_legacy)
   VALUES((r->>'date')::date,coalesce(r->>'category','autre'),r->>'object',r->>'supplier',new_amount,r->>'paid_by',CASE WHEN r->>'status'='Payé' THEN 'paid' ELSE 'to_pay' END,r->>'note','excel:06 DEPENSES:'||(r->>'reference'));
  ELSIF old_amount IS DISTINCT FROM new_amount THEN
   INSERT INTO public.workbook_reconciliation(import_id,entity,reference,source_value,current_value,resolution)
   VALUES(batch_id,'expense',r->>'reference',to_jsonb(new_amount),to_jsonb(old_amount),'À rapprocher : montant existant conservé.');
  END IF;
 END LOOP;
 INSERT INTO public.workbook_resources(import_id,section,sheet_name,row_number,row_values)
 SELECT batch_id,x->>'section',x->>'sheet_name',(x->>'row_number')::integer,x->'values' FROM jsonb_array_elements(p->'resources') x;
 SELECT count(*) INTO n FROM public.historical_orders WHERE import_id=batch_id;
 IF n<>(p->'summary'->>'order_count')::integer THEN RAISE EXCEPTION 'Contrôle du nombre de commandes échoué.'; END IF;
 SELECT count(*) INTO n FROM public.historical_order_lines l JOIN public.historical_orders o ON o.id=l.order_id WHERE o.import_id=batch_id;
 IF n<>(p->'summary'->>'sale_line_count')::integer THEN RAISE EXCEPTION 'Contrôle du nombre de lignes échoué.'; END IF;
 SELECT count(*) INTO n FROM public.legacy_import_rows WHERE source_file=sk;
 IF n<>(p->'summary'->>'source_rows')::integer THEN RAISE EXCEPTION 'Contrôle des lignes sources échoué.'; END IF;
 IF (SELECT coalesce(sum(source_received),0) FROM public.historical_orders WHERE import_id=batch_id)<>(p->'summary'->>'source_received')::numeric THEN RAISE EXCEPTION 'Contrôle des montants sources échoué.'; END IF;
 UPDATE public.workbook_imports SET is_current=false WHERE is_current;
 UPDATE public.workbook_imports SET is_current=true WHERE id=batch_id;
 RETURN jsonb_build_object('status','imported','import_id',batch_id,'summary',p->'summary','stock_movements_created',0);
END $$;

CREATE OR REPLACE FUNCTION public.review_historical_order(p_order_id uuid,p_status text,p_classification text,p_contact_id uuid,p_date date,p_total numeric,p_received numeric,p_note text,p_lines jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.historical_orders%rowtype; x jsonb; n integer; old_rows integer;
BEGIN
 PERFORM app_private.require_member();
 SELECT * INTO o FROM public.historical_orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Commande historique introuvable.'; END IF;
 IF p_status NOT IN('to_review','accepted','needs_clarification','ignored') OR p_classification NOT IN('sale','subscription','donation','consignment','loan','unclassified') THEN RAISE EXCEPTION 'Décision invalide.'; END IF;
 IF p_status IN('accepted','ignored') AND length(trim(coalesce(p_note,'')))<5 THEN RAISE EXCEPTION 'Indiquez la décision de rapprochement et sa justification.'; END IF;
 IF p_status='accepted' AND p_classification='unclassified' THEN RAISE EXCEPTION 'Précisez la nature de la commande.'; END IF;
 IF p_total<0 OR p_received<0 OR (p_total IS NOT NULL AND p_received>p_total) THEN RAISE EXCEPTION 'Montants confirmés incohérents.'; END IF;
 IF p_status='accepted' AND p_received IS NULL THEN RAISE EXCEPTION 'Confirmez le montant reçu, y compris zéro si justifié.'; END IF;
 IF p_status='accepted' AND p_classification='donation' AND coalesce(p_received,0)<>0 THEN RAISE EXCEPTION 'Un don gratuit ne peut porter un encaissement.'; END IF;
 IF jsonb_typeof(p_lines)<>'array' THEN RAISE EXCEPTION 'Lignes de rapprochement invalides.'; END IF;
 SELECT count(*) INTO old_rows FROM public.historical_order_lines WHERE order_id=p_order_id;
 IF jsonb_array_length(p_lines)<>old_rows OR (SELECT count(DISTINCT value->>'id') FROM jsonb_array_elements(p_lines))<>old_rows THEN RAISE EXCEPTION 'Toutes les lignes doivent être présentes une seule fois.'; END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(p_lines) LOOP
  UPDATE public.historical_order_lines SET book_id=CASE WHEN x ? 'book_id' THEN nullif(x->>'book_id','')::uuid ELSE book_id END,confirmed_quantity=(x->>'quantity')::integer,delivered_quantity=(x->>'delivered')::integer WHERE id=(x->>'id')::uuid AND order_id=p_order_id;
  GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'Ligne étrangère à cette commande.'; END IF;
 END LOOP;
 IF p_status='accepted' AND EXISTS(SELECT 1 FROM public.historical_order_lines WHERE order_id=p_order_id AND (confirmed_quantity IS NULL OR (confirmed_quantity>0 AND book_id IS NULL))) THEN RAISE EXCEPTION 'Confirmez les quantités et identifiez les ouvrages, ou laissez la commande à clarifier.'; END IF;
 UPDATE public.historical_orders SET review_status=p_status,classification=p_classification,contact_id=p_contact_id,confirmed_sale_date=p_date,confirmed_total=p_total,confirmed_received=p_received,review_note=nullif(trim(p_note),''),reviewed_by=auth.uid(),reviewed_at=now() WHERE id=p_order_id;
END $$;

CREATE OR REPLACE FUNCTION public.prepare_workbook_inventory(p_import_id uuid,p_date date,p_note text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE warehouse uuid; inv uuid; state text;
BEGIN
 PERFORM app_private.require_member();
 IF p_date IS NULL OR p_date>current_date OR length(trim(coalesce(p_note,'')))<5 THEN RAISE EXCEPTION 'Précisez la date réelle du comptage et son périmètre.'; END IF;
 SELECT id INTO warehouse FROM public.locations WHERE location_type='warehouse' AND is_default AND is_active FOR UPDATE;
 IF warehouse IS NULL THEN RAISE EXCEPTION 'Stock principal introuvable.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.workbook_imports WHERE id=p_import_id AND is_current) THEN RAISE EXCEPTION 'Cette version Excel n’est plus active.'; END IF;
 SELECT p.inventory_id,s.status INTO inv,state FROM public.workbook_inventory_preparations p JOIN public.inventory_sessions s ON s.id=p.inventory_id WHERE p.import_id=p_import_id;
 IF inv IS NOT NULL THEN
  IF state='in_progress' THEN RETURN inv; END IF;
  RAISE EXCEPTION 'Un inventaire a déjà été préparé pour ce classeur. Créez ensuite un inventaire normal.';
 END IF;
 IF EXISTS(SELECT 1 FROM public.stock_movements WHERE location_id=warehouse) THEN RAISE EXCEPTION 'Le stock actif a déjà été initialisé. Les anciens comptages Excel restent consultables ; effectuez un nouveau comptage.'; END IF;
 IF EXISTS(SELECT 1 FROM public.inventory_sessions WHERE location_id=warehouse AND status='in_progress') THEN RAISE EXCEPTION 'Un inventaire est déjà en cours : terminez-le ou annulez-le avant cette préparation.'; END IF;
 inv=public.start_inventory(warehouse,p_date,'Comptage Excel à vérifier : '||p_note);
 UPDATE public.inventory_lines l SET counted_quantity=o.physical_quantity,note='Quantité Excel proposée, à vérifier au comptage daté.' FROM public.workbook_stock_observations o
 WHERE o.import_id=p_import_id AND o.book_id=l.book_id AND l.inventory_session_id=inv AND o.physical_quantity IS NOT NULL;
 INSERT INTO public.workbook_inventory_preparations(import_id,inventory_id,prepared_by) VALUES(p_import_id,inv,auth.uid());
 RETURN inv;
END $$;

CREATE OR REPLACE FUNCTION public.workbook_summary() RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE i public.workbook_imports%rowtype; result jsonb;
BEGIN
 PERFORM app_private.require_member();
 SELECT * INTO i FROM public.workbook_imports WHERE is_current;
 IF NOT FOUND THEN RETURN jsonb_build_object('installed',true,'imported',false); END IF;
 SELECT jsonb_build_object('installed',true,'imported',true,'import_id',i.id,'source_name',i.source_name,'source_key',i.source_key,'source',i.summary,'sheets',i.sheets,
 'orders',count(*),'accepted',count(*) FILTER(WHERE review_status='accepted'),'to_review',count(*) FILTER(WHERE review_status='to_review'),'needs_clarification',count(*) FILTER(WHERE review_status='needs_clarification'),'ignored',count(*) FILTER(WHERE review_status='ignored'),
 'confirmed_received',coalesce(sum(confirmed_received) FILTER(WHERE review_status='accepted'),0)) INTO result FROM public.historical_orders WHERE import_id=i.id;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.dashboard_totals() RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 PERFORM app_private.require_member();
 RETURN jsonb_build_object(
 'sales_total',(SELECT coalesce(sum(gross_amount+shipping_charged),0) FROM public.sales WHERE status='recorded'),
 'sales_count',(SELECT count(*) FROM public.sales WHERE status='recorded'),
 'paid_total',(SELECT coalesce(sum(p.amount),0) FROM public.payments p JOIN public.sales s ON s.id=p.sale_id WHERE s.status='recorded'),
 'expense_total',(SELECT coalesce(sum(amount),0) FROM public.expenses WHERE status<>'cancelled'),
 'expense_paid',(SELECT coalesce(sum(amount),0) FROM public.expenses WHERE status='paid'),
 'consignment_pending',(SELECT coalesce(sum(greatest(0,s.net_amount_due-coalesce(p.paid,0))),0) FROM public.consignment_sales s LEFT JOIN(SELECT consignment_sale_id,sum(amount) paid FROM public.consignment_payments GROUP BY consignment_sale_id) p ON p.consignment_sale_id=s.id),
 'inventory_initialized',EXISTS(SELECT 1 FROM public.inventory_sessions WHERE status='validated'));
END $$;

DO $security$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['workbook_imports','historical_orders','historical_order_lines','workbook_stock_observations','workbook_resources','workbook_row_metadata','workbook_reconciliation','workbook_inventory_preparations'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('DROP POLICY IF EXISTS workbook_members_read ON public.%I',t);
  EXECUTE format('CREATE POLICY workbook_members_read ON public.%I FOR SELECT TO authenticated USING(app_private.is_member())',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
  EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
  EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['historical_orders','historical_order_lines'] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS audit_%I ON public.%I',t,t);
  EXECUTE format('CREATE TRIGGER audit_%I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()',t,t);
 END LOOP;
END $security$;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
REVOKE ALL ON FUNCTION public.import_workbook_snapshot(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.import_workbook_snapshot(jsonb) TO service_role;
REVOKE ALL ON FUNCTION public.review_historical_order(uuid,text,text,uuid,date,numeric,numeric,text,jsonb),public.prepare_workbook_inventory(uuid,date,text),public.workbook_summary(),public.dashboard_totals() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.review_historical_order(uuid,text,text,uuid,date,numeric,numeric,text,jsonb),public.prepare_workbook_inventory(uuid,date,text),public.workbook_summary(),public.dashboard_totals() TO authenticated;
COMMIT;
