-- LPGRAPP V0.5 : reprise des engagements ouverts et après-vente.
BEGIN;
CREATE TABLE IF NOT EXISTS public.sale_adjustments(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),sale_id uuid NOT NULL REFERENCES public.sales(id),
 kind text NOT NULL CHECK(kind IN('return','cancellation','price_adjustment')), adjustment_date date NOT NULL,
 credit_amount numeric(12,2) NOT NULL CHECK(credit_amount>=0), note text NOT NULL,
 document_id uuid REFERENCES public.stock_documents(id),created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sale_adjustment_lines(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),adjustment_id uuid NOT NULL REFERENCES public.sale_adjustments(id),
 sale_item_id uuid NOT NULL REFERENCES public.sale_items(id),quantity integer NOT NULL CHECK(quantity>0),restocked boolean NOT NULL,
 UNIQUE(adjustment_id,sale_item_id)
);
CREATE TABLE IF NOT EXISTS public.sale_refunds(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),sale_id uuid NOT NULL REFERENCES public.sales(id),
 refund_date date NOT NULL,amount numeric(12,2) NOT NULL CHECK(amount>0),payment_method text NOT NULL,reference text,note text NOT NULL,
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.historical_commitment_links(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid NOT NULL REFERENCES public.historical_orders(id),
 kind text NOT NULL CHECK(kind IN('loan','consignment')),loan_id uuid REFERENCES public.loans(id),consignment_id uuid REFERENCES public.consignments(id),
 opening_date date NOT NULL,note text NOT NULL,created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(order_id,kind),CHECK((kind='loan' AND loan_id IS NOT NULL AND consignment_id IS NULL) OR (kind='consignment' AND consignment_id IS NOT NULL AND loan_id IS NULL))
);
CREATE TABLE IF NOT EXISTS public.opening_receivables(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),commitment_id uuid NOT NULL UNIQUE REFERENCES public.historical_commitment_links(id),
 contact_id uuid NOT NULL REFERENCES public.contacts(id),amount_due numeric(12,2) NOT NULL CHECK(amount_due>0),note text NOT NULL,
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.opening_receivable_payments(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),receivable_id uuid NOT NULL REFERENCES public.opening_receivables(id),
 amount numeric(12,2) NOT NULL CHECK(amount>0),payment_date date NOT NULL,payment_method text NOT NULL,reference text,note text,
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.historical_deliveries(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid NOT NULL REFERENCES public.historical_orders(id),
 delivery_date date NOT NULL,document_id uuid NOT NULL REFERENCES public.stock_documents(id),reference text,note text NOT NULL,
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.historical_delivery_lines(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),delivery_id uuid NOT NULL REFERENCES public.historical_deliveries(id),
 order_line_id uuid NOT NULL REFERENCES public.historical_order_lines(id),book_id uuid NOT NULL REFERENCES public.books(id),
 quantity integer NOT NULL CHECK(quantity>0),UNIQUE(delivery_id,order_line_id)
);
CREATE INDEX IF NOT EXISTS sale_adjustment_sale_idx ON public.sale_adjustments(sale_id);
CREATE INDEX IF NOT EXISTS sale_refund_sale_idx ON public.sale_refunds(sale_id);
CREATE INDEX IF NOT EXISTS historical_delivery_order_idx ON public.historical_deliveries(order_id);
CREATE OR REPLACE VIEW public.v_sales_financials WITH(security_invoker=true) AS
 SELECT s.*,coalesce(a.credit,0)::numeric credited_total,
 (s.gross_amount+s.shipping_charged-coalesce(a.credit,0))::numeric net_due,
 coalesce(p.paid,0)::numeric paid_gross,coalesce(r.refunded,0)::numeric refunded_total,
 (coalesce(p.paid,0)-coalesce(r.refunded,0))::numeric paid_net,
 greatest(0,s.gross_amount+s.shipping_charged-coalesce(a.credit,0)-coalesce(p.paid,0)+coalesce(r.refunded,0))::numeric balance_due,
 greatest(0,coalesce(p.paid,0)-coalesce(r.refunded,0)-s.gross_amount-s.shipping_charged+coalesce(a.credit,0))::numeric refund_due
 FROM public.sales s
 LEFT JOIN(SELECT sale_id,sum(credit_amount) credit FROM public.sale_adjustments GROUP BY sale_id) a ON a.sale_id=s.id
 LEFT JOIN(SELECT sale_id,sum(amount) paid FROM public.payments GROUP BY sale_id) p ON p.sale_id=s.id
 LEFT JOIN(SELECT sale_id,sum(amount) refunded FROM public.sale_refunds GROUP BY sale_id) r ON r.sale_id=s.id;
CREATE OR REPLACE VIEW public.v_opening_receivables WITH(security_invoker=true) AS
 SELECT r.*,l.order_id,l.consignment_id,coalesce(p.paid,0)::numeric amount_paid,(r.amount_due-coalesce(p.paid,0))::numeric remaining
 FROM public.opening_receivables r JOIN public.historical_commitment_links l ON l.id=r.commitment_id
 LEFT JOIN(SELECT receivable_id,sum(amount) paid FROM public.opening_receivable_payments GROUP BY receivable_id) p ON p.receivable_id=r.id;

CREATE OR REPLACE FUNCTION app_private.begin_request(p_action text,p_id uuid,p_payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.app_requests%rowtype;
BEGIN
 PERFORM app_private.require_member();
 IF p_id IS NULL THEN RAISE EXCEPTION 'Identifiant de requête requis.'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':'||p_action||':'||p_id::text,0));
 SELECT * INTO r FROM public.app_requests WHERE actor_id=auth.uid() AND action=p_action AND request_id=p_id;
 IF FOUND THEN
  IF r.fingerprint<>md5(p_payload::text) THEN RAISE EXCEPTION 'Requête déjà utilisée avec un contenu différent.'; END IF;
  RETURN r.result;
 END IF;
 RETURN NULL;
END $$;
CREATE OR REPLACE FUNCTION app_private.end_request(p_action text,p_id uuid,p_payload jsonb,p_result uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.app_requests(actor_id,action,request_id,fingerprint,result) VALUES(auth.uid(),p_action,p_id,md5(p_payload::text),p_result);
 RETURN p_result;
END $$;
REVOKE ALL ON FUNCTION app_private.begin_request(text,uuid,jsonb),app_private.end_request(text,uuid,jsonb,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.adjust_sale_once(p_request_id uuid,p_payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result_id uuid;s public.sales%rowtype;item public.sale_items%rowtype; x jsonb; q integer;already integer;
 credit numeric:=0;existing_credit numeric;ship_credit numeric;doc uuid;wh uuid;k text;d date;restock boolean;
BEGIN
 result_id=app_private.begin_request('adjust_sale',p_request_id,p_payload);IF result_id IS NOT NULL THEN RETURN result_id; END IF;
 SELECT * INTO s FROM public.sales WHERE id=(p_payload->>'sale_id')::uuid FOR UPDATE;
 IF NOT FOUND OR s.status<>'recorded' THEN RAISE EXCEPTION 'Vente introuvable ou déjà annulée.'; END IF;
 k=p_payload->>'kind'; d=(p_payload->>'date')::date;restock=coalesce((p_payload->>'restock')::boolean,false);
 IF k NOT IN('return','cancellation','price_adjustment') OR k IS NULL OR d IS NULL OR d>current_date OR length(trim(coalesce(p_payload->>'note','')))<5 THEN RAISE EXCEPTION 'Précisez une opération, une date réelle et un motif.'; END IF;
 SELECT coalesce(sum(credit_amount),0) INTO existing_credit FROM public.sale_adjustments WHERE sale_id=s.id;
 IF k='price_adjustment' THEN
  credit=round((p_payload->>'credit')::numeric,2);
 ELSIF k='cancellation' THEN
  credit=s.gross_amount+s.shipping_charged-existing_credit;
 ELSE
  IF coalesce(jsonb_typeof(p_payload->'items'),'')<>'array' OR jsonb_array_length(p_payload->'items')=0 THEN RAISE EXCEPTION 'Sélectionnez les quantités retournées.'; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_payload->'items'))<>(SELECT count(DISTINCT value->>'id') FROM jsonb_array_elements(p_payload->'items')) THEN RAISE EXCEPTION 'Ligne de retour répétée.'; END IF;
  FOR x IN SELECT value FROM jsonb_array_elements(p_payload->'items') LOOP
   SELECT * INTO item FROM public.sale_items WHERE id=(x->>'id')::uuid AND sale_id=s.id;
   IF NOT FOUND THEN RAISE EXCEPTION 'Ligne étrangère à la vente.'; END IF;
   q=(x->>'quantity')::integer;
   SELECT coalesce(sum(l.quantity),0) INTO already FROM public.sale_adjustment_lines l WHERE l.sale_item_id=item.id;
   IF q IS NULL OR q<=0 OR q>item.quantity-already THEN RAISE EXCEPTION 'Quantité retournée supérieure au restant de la vente.'; END IF;
   credit=credit+round(item.line_total/item.quantity*q,2);
  END LOOP;
  ship_credit=coalesce((p_payload->>'shipping_credit')::numeric,0);
  IF ship_credit<0 OR ship_credit>s.shipping_charged OR ship_credit::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Avoir sur les frais de port invalide.'; END IF;
  credit=credit+ship_credit;
 END IF;
 IF k='return' THEN credit=least(credit,s.gross_amount+s.shipping_charged-existing_credit); END IF;
 IF credit IS NULL OR credit<0 OR (credit=0 AND k='price_adjustment') OR credit>s.gross_amount+s.shipping_charged-existing_credit OR credit::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Le crédit ne peut pas dépasser le montant restant de la vente ; une correction de prix doit être positive.'; END IF;
 IF k<>'price_adjustment' AND restock THEN
  SELECT id INTO wh FROM public.locations WHERE location_type='warehouse' AND is_default AND is_active FOR UPDATE;
  IF wh IS NULL THEN RAISE EXCEPTION 'Stock principal introuvable.'; END IF;
  INSERT INTO public.stock_documents(document_type,document_date,contact_id,note,created_by,validated_by,validated_at)
  VALUES('correction',d,s.contact_id,p_payload->>'note',auth.uid(),auth.uid(),now()) RETURNING id INTO doc;
 END IF;
 INSERT INTO public.sale_adjustments(sale_id,kind,adjustment_date,credit_amount,note,document_id,created_by)
 VALUES(s.id,k,d,credit,p_payload->>'note',doc,auth.uid()) RETURNING id INTO result_id;
 IF k='cancellation' THEN
  FOR item IN SELECT * FROM public.sale_items WHERE sale_id=s.id LOOP
   SELECT coalesce(sum(quantity),0) INTO already FROM public.sale_adjustment_lines WHERE sale_item_id=item.id;
   q=item.quantity-already;
   IF q>0 THEN
    INSERT INTO public.sale_adjustment_lines(adjustment_id,sale_item_id,quantity,restocked) VALUES(result_id,item.id,q,restock);
    IF restock THEN INSERT INTO public.stock_movements(document_id,book_id,location_id,movement_type,quantity_delta,contact_id,note,created_by) VALUES(doc,item.book_id,wh,'correction',q,s.contact_id,'Retour après annulation de vente',auth.uid()); END IF;
   END IF;
  END LOOP;
  UPDATE public.sales SET status='cancelled' WHERE id=s.id;
 ELSIF k='return' THEN
  FOR x IN SELECT value FROM jsonb_array_elements(p_payload->'items') LOOP
   SELECT * INTO item FROM public.sale_items WHERE id=(x->>'id')::uuid AND sale_id=s.id;q=(x->>'quantity')::integer;
   INSERT INTO public.sale_adjustment_lines(adjustment_id,sale_item_id,quantity,restocked) VALUES(result_id,item.id,q,restock);
   IF restock THEN INSERT INTO public.stock_movements(document_id,book_id,location_id,movement_type,quantity_delta,contact_id,note,created_by) VALUES(doc,item.book_id,wh,'correction',q,s.contact_id,'Retour client',auth.uid()); END IF;
  END LOOP;
 END IF;
 RETURN app_private.end_request('adjust_sale',p_request_id,p_payload,result_id);
END $$;

CREATE OR REPLACE FUNCTION public.refund_sale_once(p_request_id uuid,p_payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result_id uuid;s public.sales%rowtype;financial public.v_sales_financials%rowtype;a numeric;d date;
BEGIN
 result_id=app_private.begin_request('refund_sale',p_request_id,p_payload);IF result_id IS NOT NULL THEN RETURN result_id; END IF;
 SELECT * INTO s FROM public.sales WHERE id=(p_payload->>'sale_id')::uuid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Vente introuvable.'; END IF;
 SELECT * INTO financial FROM public.v_sales_financials WHERE id=s.id;
 a=round((p_payload->>'amount')::numeric,2);d=(p_payload->>'date')::date;
 IF a IS NULL OR a<=0 OR a>financial.refund_due OR a::text IN('NaN','Infinity','-Infinity') OR d IS NULL OR d>current_date OR length(trim(coalesce(p_payload->>'note','')))<5 THEN RAISE EXCEPTION 'Remboursement invalide : vérifiez le crédit client disponible, la date et le motif.'; END IF;
 INSERT INTO public.sale_refunds(sale_id,refund_date,amount,payment_method,reference,note,created_by)
 VALUES(s.id,d,a,coalesce(nullif(p_payload->>'method',''),'autre'),p_payload->>'reference',p_payload->>'note',auth.uid()) RETURNING id INTO result_id;
 RETURN app_private.end_request('refund_sale',p_request_id,p_payload,result_id);
END $$;

CREATE OR REPLACE FUNCTION public.record_sale_payment(p_sale_id uuid,p_payment_date date,p_amount numeric,p_payment_method text,p_reference text DEFAULT NULL,p_note text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.sales%rowtype;balance numeric;result_id uuid;
BEGIN
 PERFORM app_private.require_member();
 SELECT * INTO s FROM public.sales WHERE id=p_sale_id FOR UPDATE;
 IF NOT FOUND OR s.status<>'recorded' THEN RAISE EXCEPTION 'Vente introuvable ou annulée.'; END IF;
 SELECT balance_due INTO balance FROM public.v_sales_financials WHERE id=s.id;
 IF p_payment_date>current_date OR p_amount IS NULL OR p_amount<=0 OR p_amount>balance OR p_amount::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Le règlement dépasse le solde réellement dû après corrections.'; END IF;
 INSERT INTO public.payments(sale_id,payment_date,amount,payment_method,reference,note,created_by) VALUES(s.id,coalesce(p_payment_date,current_date),p_amount,coalesce(p_payment_method,'autre'),p_reference,p_note,auth.uid()) RETURNING id INTO result_id;
 RETURN result_id;
END $$;

CREATE OR REPLACE FUNCTION public.open_historical_commitment_once(p_request_id uuid,p_payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result_id uuid;o public.historical_orders%rowtype;contact uuid;k text;d date;loc uuid;doc uuid;entity uuid;link uuid;x jsonb;b uuid;q integer;num bigint;due numeric;commission numeric;
BEGIN
 result_id=app_private.begin_request('open_commitment',p_request_id,p_payload);IF result_id IS NOT NULL THEN RETURN result_id; END IF;
 SELECT * INTO o FROM public.historical_orders WHERE id=(p_payload->>'order_id')::uuid FOR UPDATE;
 IF NOT FOUND OR o.review_status='ignored' THEN RAISE EXCEPTION 'Commande historique introuvable ou écartée.'; END IF;
 k=p_payload->>'kind';contact=(p_payload->>'contact_id')::uuid;d=(p_payload->>'date')::date;due=coalesce((p_payload->>'net_due')::numeric,0);commission=coalesce((p_payload->>'commission')::numeric,30);
 IF k IS NULL OR k NOT IN('loan','consignment') OR contact IS NULL OR d IS NULL OR d>current_date OR length(trim(coalesce(p_payload->>'note','')))<5 OR NOT coalesce((p_payload->>'offsite_confirmed')::boolean,false) THEN RAISE EXCEPTION 'Confirmez le détenteur, la date, le motif et le fait que ces livres sont déjà hors du stock principal.'; END IF;
 IF due<0 OR due::text IN('NaN','Infinity','-Infinity') OR commission<0 OR commission>100 OR commission::text IN('NaN','Infinity','-Infinity') OR (k='loan' AND due<>0) THEN RAISE EXCEPTION 'Solde net ou commission invalide.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.contacts WHERE id=contact AND is_active) THEN RAISE EXCEPTION 'Détenteur actif introuvable.'; END IF;
 IF EXISTS(SELECT 1 FROM public.historical_commitment_links WHERE order_id=o.id AND kind=k) THEN RAISE EXCEPTION 'Cet engagement a déjà été repris. Utilisez ensuite les retours et règlements normaux.'; END IF;
 IF coalesce(jsonb_typeof(p_payload->'items'),'')<>'array' OR (jsonb_array_length(p_payload->'items')=0 AND due=0) THEN RAISE EXCEPTION 'Saisissez les livres encore confiés ou un solde net à recevoir.'; END IF;
 IF k='loan' THEN
  INSERT INTO public.loans(contact_id,loan_date,due_date,note,created_by) VALUES(contact,d,(p_payload->>'due_date')::date,'Reprise du solde ouvert · '||o.reference||' · '||(p_payload->>'note'),auth.uid()) RETURNING id,loan_number INTO entity,num;
 ELSE
  INSERT INTO public.consignments(contact_id,deposit_date,commission_rate,note,created_by) VALUES(contact,d,commission,'Reprise du solde ouvert · '||o.reference||' · '||(p_payload->>'note'),auth.uid()) RETURNING id,consignment_number INTO entity,num;
 END IF;
 INSERT INTO public.locations(name,location_type,contact_id,created_by) VALUES('Reprise '||o.reference||' · '||num,CASE WHEN k='loan' THEN 'loan' ELSE 'consignment' END,contact,auth.uid()) RETURNING id INTO loc;
 INSERT INTO public.stock_documents(document_type,document_date,contact_id,reference,note,created_by,validated_by,validated_at) VALUES('opening_inventory',d,contact,o.reference,'Stock déjà confié avant bascule : '||(p_payload->>'note'),auth.uid(),auth.uid(),now()) RETURNING id INTO doc;
 IF k='loan' THEN UPDATE public.loans SET location_id=loc,document_id=doc WHERE id=entity; ELSE UPDATE public.consignments SET location_id=loc,document_id=doc WHERE id=entity; END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(p_payload->'items') LOOP
  b=(x->>'book_id')::uuid;q=(x->>'quantity')::integer;
  IF q IS NULL OR q<=0 OR NOT EXISTS(SELECT 1 FROM public.books WHERE id=b AND status='publie') THEN RAISE EXCEPTION 'Un livre publié et une quantité restante positive sont requis.'; END IF;
  IF k='loan' THEN INSERT INTO public.loan_items(loan_id,book_id,quantity) VALUES(entity,b,q);
  ELSE INSERT INTO public.consignment_items(consignment_id,book_id,quantity_deposited,unit_price) VALUES(entity,b,q,(x->>'unit_price')::numeric); END IF;
  INSERT INTO public.stock_movements(document_id,book_id,location_id,movement_type,quantity_delta,contact_id,reference,note,created_by) VALUES(doc,b,loc,'opening',q,contact,o.reference,'Solde déjà confié à la bascule',auth.uid());
 END LOOP;
 INSERT INTO public.historical_commitment_links(order_id,kind,loan_id,consignment_id,opening_date,note,created_by) VALUES(o.id,k,CASE WHEN k='loan' THEN entity END,CASE WHEN k='consignment' THEN entity END,d,p_payload->>'note',auth.uid()) RETURNING id INTO link;
 IF due>0 THEN INSERT INTO public.opening_receivables(commitment_id,contact_id,amount_due,note,created_by) VALUES(link,contact,due,'Net restant pour des ventes déjà réalisées avant bascule · '||(p_payload->>'note'),auth.uid()); END IF;
 RETURN app_private.end_request('open_commitment',p_request_id,p_payload,entity);
END $$;

CREATE OR REPLACE FUNCTION public.record_opening_payment_once(p_request_id uuid,p_payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result_id uuid;r public.opening_receivables%rowtype;a numeric;paid numeric;d date;
BEGIN
 result_id=app_private.begin_request('opening_payment',p_request_id,p_payload);IF result_id IS NOT NULL THEN RETURN result_id; END IF;
 SELECT * INTO r FROM public.opening_receivables WHERE id=(p_payload->>'receivable_id')::uuid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Solde antérieur introuvable.'; END IF;
 SELECT coalesce(sum(amount),0) INTO paid FROM public.opening_receivable_payments WHERE receivable_id=r.id;
 a=(p_payload->>'amount')::numeric;d=(p_payload->>'date')::date;
 IF a IS NULL OR a<=0 OR a>r.amount_due-paid OR a::text IN('NaN','Infinity','-Infinity') OR d IS NULL OR d>current_date THEN RAISE EXCEPTION 'Règlement supérieur au solde ou date invalide.'; END IF;
 INSERT INTO public.opening_receivable_payments(receivable_id,amount,payment_date,payment_method,reference,note,created_by) VALUES(r.id,a,d,coalesce(nullif(p_payload->>'method',''),'autre'),p_payload->>'reference',p_payload->>'note',auth.uid()) RETURNING id INTO result_id;
 RETURN app_private.end_request('opening_payment',p_request_id,p_payload,result_id);
END $$;

CREATE OR REPLACE FUNCTION public.ship_historical_order_once(p_request_id uuid,p_payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result_id uuid;o public.historical_orders%rowtype;l public.historical_order_lines%rowtype;x jsonb;q integer;wh uuid;doc uuid;d date;available integer;
BEGIN
 result_id=app_private.begin_request('historical_delivery',p_request_id,p_payload);IF result_id IS NOT NULL THEN RETURN result_id; END IF;
 SELECT * INTO o FROM public.historical_orders WHERE id=(p_payload->>'order_id')::uuid FOR UPDATE;
 IF NOT FOUND OR o.review_status='ignored' OR coalesce((to_jsonb(o)->>'fulfillment_closed')::boolean,false) OR o.classification NOT IN('sale','subscription') THEN RAISE EXCEPTION 'Précisez une vente ou un abonnement actif avant la livraison.'; END IF;
 d=(p_payload->>'date')::date;
 IF d IS NULL OR d>current_date OR length(trim(coalesce(p_payload->>'note','')))<5 OR coalesce(jsonb_typeof(p_payload->'items'),'')<>'array' OR jsonb_array_length(p_payload->'items')=0 THEN RAISE EXCEPTION 'Saisissez la date réelle, le motif et les quantités à livrer.'; END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(p_payload->'items'))<>(SELECT count(DISTINCT value->>'id') FROM jsonb_array_elements(p_payload->'items')) THEN RAISE EXCEPTION 'Ligne de livraison répétée.'; END IF;
 SELECT id INTO wh FROM public.locations WHERE location_type='warehouse' AND is_default AND is_active FOR UPDATE;
 IF wh IS NULL THEN RAISE EXCEPTION 'Stock principal introuvable.'; END IF;
 INSERT INTO public.stock_documents(document_type,document_date,contact_id,reference,note,created_by,validated_by,validated_at) VALUES('sale',d,o.contact_id,p_payload->>'reference','Livraison de commande reprise · '||o.reference||' · '||(p_payload->>'note'),auth.uid(),auth.uid(),now()) RETURNING id INTO doc;
 INSERT INTO public.historical_deliveries(order_id,delivery_date,document_id,reference,note,created_by) VALUES(o.id,d,doc,p_payload->>'reference',p_payload->>'note',auth.uid()) RETURNING id INTO result_id;
 FOR x IN SELECT value FROM jsonb_array_elements(p_payload->'items') LOOP
  SELECT * INTO l FROM public.historical_order_lines WHERE id=(x->>'id')::uuid AND order_id=o.id FOR UPDATE;q=(x->>'quantity')::integer;
  IF NOT FOUND OR q IS NULL OR q<=0 OR l.book_id IS NULL OR l.delivered_quantity IS NULL OR coalesce(l.confirmed_quantity,l.source_quantity) IS NULL THEN RAISE EXCEPTION 'Identifiez le livre et renseignez les quantités commandées et déjà livrées avant cette expédition.'; END IF;
  IF q>coalesce(l.confirmed_quantity,l.source_quantity)-l.delivered_quantity THEN RAISE EXCEPTION 'Quantité supérieure au restant à livrer.'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.books WHERE id=l.book_id AND status='publie') THEN RAISE EXCEPTION 'Ce livre n’est pas publié.'; END IF;
  SELECT coalesce(sum(quantity_delta),0) INTO available FROM public.stock_movements WHERE book_id=l.book_id AND location_id=wh;
  IF available<q THEN RAISE EXCEPTION 'Stock principal insuffisant pour la livraison.'; END IF;
  UPDATE public.historical_order_lines SET delivered_quantity=delivered_quantity+q WHERE id=l.id;
  INSERT INTO public.historical_delivery_lines(delivery_id,order_line_id,book_id,quantity) VALUES(result_id,l.id,l.book_id,q);
  INSERT INTO public.stock_movements(document_id,book_id,location_id,movement_type,quantity_delta,contact_id,reference,note,created_by) VALUES(doc,l.book_id,wh,'sale',-q,o.contact_id,o.reference,'Livraison d’une commande déjà comptée financièrement',auth.uid());
 END LOOP;
 RETURN app_private.end_request('historical_delivery',p_request_id,p_payload,result_id);
END $$;

-- Une livraison effectivement enregistrée ne peut pas être effacée par une simple revue.
CREATE OR REPLACE FUNCTION app_private.protect_delivered_review() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE shipped integer;
BEGIN
 SELECT coalesce(sum(quantity),0) INTO shipped FROM public.historical_delivery_lines WHERE order_line_id=OLD.id;
 IF shipped>0 AND (NEW.book_id IS DISTINCT FROM OLD.book_id OR NEW.delivered_quantity IS NULL OR NEW.delivered_quantity<OLD.delivered_quantity) THEN RAISE EXCEPTION 'Des livraisons sont déjà journalisées : le livre et les quantités livrées ne peuvent plus être réduits par la revue.'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION app_private.protect_delivered_review() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS protect_delivered_review ON public.historical_order_lines;
CREATE TRIGGER protect_delivered_review BEFORE UPDATE ON public.historical_order_lines FOR EACH ROW EXECUTE FUNCTION app_private.protect_delivered_review();

DO $security$ DECLARE t text;BEGIN
 FOREACH t IN ARRAY ARRAY['sale_adjustments','sale_adjustment_lines','sale_refunds','historical_commitment_links','opening_receivables','opening_receivable_payments','historical_deliveries','historical_delivery_lines'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
  EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
  EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
  EXECUTE format('DROP POLICY IF EXISTS member_read ON public.%I',t);
  EXECUTE format('CREATE POLICY member_read ON public.%I FOR SELECT TO authenticated USING(app_private.is_member())',t);
  EXECUTE format('DROP TRIGGER IF EXISTS audit_%I ON public.%I',t,t);
  EXECUTE format('CREATE TRIGGER audit_%I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()',t,t);
 END LOOP;
END $security$;
GRANT SELECT ON public.v_sales_financials,public.v_opening_receivables TO authenticated;
REVOKE ALL ON FUNCTION public.adjust_sale_once(uuid,jsonb),public.refund_sale_once(uuid,jsonb),public.open_historical_commitment_once(uuid,jsonb),public.record_opening_payment_once(uuid,jsonb),public.ship_historical_order_once(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.adjust_sale_once(uuid,jsonb),public.refund_sale_once(uuid,jsonb),public.open_historical_commitment_once(uuid,jsonb),public.record_opening_payment_once(uuid,jsonb),public.ship_historical_order_once(uuid,jsonb) TO authenticated;
COMMIT;
