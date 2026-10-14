BEGIN;
-- Les nouveaux règlements restent distincts des sommes reçues avant bascule.
CREATE TABLE IF NOT EXISTS public.historical_payments(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid NOT NULL REFERENCES public.historical_orders(id),
 payment_date date NOT NULL,amount numeric(12,2) NOT NULL CHECK(amount>0),payment_method text NOT NULL,reference text,note text NOT NULL,
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS historical_payment_order_idx ON public.historical_payments(order_id);
ALTER TABLE public.historical_payments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.historical_payments FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.historical_payments TO authenticated;
GRANT ALL ON public.historical_payments TO service_role;
DROP POLICY IF EXISTS member_read ON public.historical_payments;
CREATE POLICY member_read ON public.historical_payments FOR SELECT TO authenticated USING(app_private.is_member());
DROP TRIGGER IF EXISTS audit_historical_payments ON public.historical_payments;
CREATE TRIGGER audit_historical_payments AFTER INSERT OR UPDATE OR DELETE ON public.historical_payments FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();
CREATE OR REPLACE FUNCTION public.pay_historical_once(p_request_id uuid,p_payload jsonb) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result_id uuid;o public.historical_orders%rowtype;a numeric;gross numeric;new_paid numeric;d date;
BEGIN
 result_id=app_private.begin_request('historical_payment',p_request_id,p_payload);IF result_id IS NOT NULL THEN RETURN result_id; END IF;
 SELECT * INTO o FROM public.historical_orders WHERE id=(p_payload->>'order_id')::uuid FOR UPDATE;
 IF NOT FOUND OR o.review_status='ignored' OR o.fulfillment_closed OR o.classification NOT IN('sale','subscription') THEN RAISE EXCEPTION 'Précisez une vente ou un abonnement actif avant son règlement.'; END IF;
 gross=CASE WHEN o.review_status='accepted' THEN o.confirmed_received ELSE o.source_received END;
 SELECT coalesce(sum(amount),0) INTO new_paid FROM public.historical_payments WHERE order_id=o.id;
 a=round((p_payload->>'amount')::numeric,2);d=(p_payload->>'date')::date;
 IF o.confirmed_total IS NULL OR gross IS NULL OR a IS NULL OR a<=0 OR a>o.confirmed_total-gross-new_paid OR a::text IN('NaN','Infinity','-Infinity') OR d IS NULL OR d>current_date OR length(trim(coalesce(p_payload->>'note','')))<5 THEN RAISE EXCEPTION 'Confirmez le total de commande et les montants reçus avant bascule ; le nouveau règlement ne peut pas dépasser le solde.'; END IF;
 INSERT INTO public.historical_payments(order_id,payment_date,amount,payment_method,reference,note,created_by) VALUES(o.id,d,a,coalesce(nullif(p_payload->>'method',''),'autre'),p_payload->>'reference',p_payload->>'note',auth.uid()) RETURNING id INTO result_id;
 RETURN app_private.end_request('historical_payment',p_request_id,p_payload,result_id);
END $$;
REVOKE ALL ON FUNCTION public.pay_historical_once(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pay_historical_once(uuid,jsonb) TO authenticated;
CREATE OR REPLACE FUNCTION public.refund_historical_once(p_request_id uuid,p_payload jsonb) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result_id uuid;o public.historical_orders%rowtype;a numeric;gross numeric;paid_back numeric;d date;
BEGIN
 result_id=app_private.begin_request('historical_refund',p_request_id,p_payload);IF result_id IS NOT NULL THEN RETURN result_id; END IF;
 SELECT * INTO o FROM public.historical_orders WHERE id=(p_payload->>'order_id')::uuid FOR UPDATE;
 IF NOT FOUND OR o.review_status='ignored' THEN RAISE EXCEPTION 'Commande historique introuvable ou écartée.'; END IF;
 gross=CASE WHEN o.review_status='accepted' THEN o.confirmed_received ELSE o.source_received END;
 gross=gross+(SELECT coalesce(sum(amount),0) FROM public.historical_payments WHERE order_id=o.id);
 SELECT coalesce(sum(amount),0) INTO paid_back FROM public.historical_refunds WHERE order_id=o.id;
 a=(p_payload->>'amount')::numeric;d=(p_payload->>'date')::date;
 IF gross IS NULL OR a IS NULL OR a<=0 OR a>gross-paid_back OR a::text IN('NaN','Infinity','-Infinity') OR d IS NULL OR d>current_date OR length(trim(coalesce(p_payload->>'note','')))<5 THEN RAISE EXCEPTION 'Confirmez les montants reçus et saisissez un remboursement réel justifié ne dépassant pas le solde.'; END IF;
 INSERT INTO public.historical_refunds(order_id,refund_date,amount,payment_method,reference,note,created_by) VALUES(o.id,d,a,coalesce(nullif(p_payload->>'method',''),'autre'),p_payload->>'reference',p_payload->>'note',auth.uid()) RETURNING id INTO result_id;
 IF coalesce((p_payload->>'stop_delivery')::boolean,false) THEN UPDATE public.historical_orders SET fulfillment_closed=true WHERE id=o.id; END IF;
 RETURN app_private.end_request('historical_refund',p_request_id,p_payload,result_id);
END $$;
CREATE OR REPLACE FUNCTION app_private.protect_refunded_history() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE refunded numeric;gross numeric;
BEGIN
 SELECT coalesce(sum(amount),0) INTO refunded FROM public.historical_refunds WHERE order_id=OLD.id;
 gross=CASE WHEN NEW.review_status='accepted' THEN NEW.confirmed_received ELSE NEW.source_received END;
 IF EXISTS(SELECT 1 FROM public.historical_payments WHERE order_id=OLD.id) AND (NEW.review_status='ignored' OR gross IS NULL OR NEW.confirmed_total IS NULL OR gross+(SELECT coalesce(sum(amount),0) FROM public.historical_payments WHERE order_id=OLD.id)>NEW.confirmed_total) THEN RAISE EXCEPTION 'Des règlements sont journalisés : conservez la commande et un montant total cohérent.'; END IF;
 gross=gross+(SELECT coalesce(sum(amount),0) FROM public.historical_payments WHERE order_id=OLD.id);
 IF refunded>0 AND (NEW.review_status='ignored' OR gross IS NULL OR gross<refunded) THEN RAISE EXCEPTION 'Un remboursement est déjà journalisé : conservez le montant brut reçu et la commande pour éviter de déduire deux fois ce remboursement.'; END IF;
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION public.dashboard_totals() RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE history_amount numeric:=0; history_orders bigint:=0; history_pending bigint:=0;
 history_missing bigint:=0; direct_received numeric:=0; consignment_received numeric:=0;
BEGIN
 PERFORM app_private.require_member();
 -- Une décision remplace la valeur Excel ; elle ne s’ajoute jamais à celle-ci.
 -- Tant qu’une commande n’a pas été rapprochée, les valeurs Excel restent utilisées.
 SELECT coalesce(sum(CASE WHEN o.review_status='accepted' THEN o.confirmed_received ELSE o.source_received END),0),
 count(*),count(*) FILTER(WHERE o.review_status<>'accepted'),
 count(*) FILTER(WHERE CASE WHEN o.review_status='accepted' THEN o.confirmed_received ELSE o.source_received END IS NULL)
 INTO history_amount,history_orders,history_pending,history_missing
 FROM public.historical_orders o JOIN public.workbook_imports i ON i.id=o.import_id
 WHERE i.is_current AND o.review_status<>'ignored';
 SELECT coalesce(sum(amount),0) INTO direct_received FROM public.payments;
 direct_received=direct_received-(SELECT coalesce(sum(amount),0) FROM public.sale_refunds);
 SELECT coalesce(sum(p.amount),0) INTO consignment_received FROM public.consignment_payments p JOIN public.consignment_sales cs ON cs.id=p.consignment_sale_id JOIN public.consignments c ON c.id=cs.consignment_id WHERE c.status<>'cancelled';
 history_amount=history_amount+(SELECT coalesce(sum(p.amount),0) FROM public.historical_payments p JOIN public.historical_orders o ON o.id=p.order_id JOIN public.workbook_imports i ON i.id=o.import_id WHERE i.is_current);
 history_amount=history_amount-(SELECT coalesce(sum(r.amount),0) FROM public.historical_refunds r JOIN public.historical_orders o ON o.id=r.order_id JOIN public.workbook_imports i ON i.id=o.import_id WHERE i.is_current);
 consignment_received=consignment_received+(SELECT coalesce(sum(amount),0) FROM public.opening_receivable_payments);
 RETURN jsonb_build_object(
 'received_total',history_amount+direct_received+consignment_received,
 'history_received',history_amount,'history_orders',history_orders,
 'history_pending',history_pending,'history_missing_amounts',history_missing,
 'consignment_received',consignment_received,
 'orders_count',history_orders+(SELECT count(*) FROM public.sales WHERE status='recorded'),
 'sales_total',(SELECT coalesce(sum(net_due),0) FROM public.v_sales_financials),
 'direct_balance_due',(SELECT coalesce(sum(balance_due),0) FROM public.v_sales_financials),
 'direct_refund_due',(SELECT coalesce(sum(refund_due),0) FROM public.v_sales_financials),
 'historical_refunded',(SELECT coalesce(sum(r.amount),0) FROM public.historical_refunds r JOIN public.historical_orders o ON o.id=r.order_id JOIN public.workbook_imports i ON i.id=o.import_id WHERE i.is_current),
 'sales_count',(SELECT count(*) FROM public.sales WHERE status='recorded'),
 'paid_total',direct_received,
 'expense_total',(SELECT coalesce(sum(amount),0) FROM public.expenses WHERE status<>'cancelled'),
 'expense_paid',(SELECT coalesce(sum(amount),0) FROM public.expenses WHERE status='paid'),
 'opening_pending',(SELECT coalesce(sum(remaining),0) FROM public.v_opening_receivables),
 'consignment_pending',(SELECT coalesce(sum(greatest(0,s.net_amount_due-coalesce(p.paid,0))),0) FROM public.consignment_sales s JOIN public.consignments c ON c.id=s.consignment_id LEFT JOIN(SELECT consignment_sale_id,sum(amount) paid FROM public.consignment_payments GROUP BY consignment_sale_id) p ON p.consignment_sale_id=s.id WHERE c.status<>'cancelled'),
 'inventory_initialized',EXISTS(SELECT 1 FROM public.inventory_sessions WHERE status='validated'));
END $$;
COMMIT;
