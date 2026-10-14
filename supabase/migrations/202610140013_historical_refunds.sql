BEGIN;
ALTER TABLE public.historical_orders ADD COLUMN IF NOT EXISTS fulfillment_closed boolean NOT NULL DEFAULT false;
CREATE TABLE IF NOT EXISTS public.historical_refunds(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid NOT NULL REFERENCES public.historical_orders(id),
 refund_date date NOT NULL,amount numeric(12,2) NOT NULL CHECK(amount>0),payment_method text NOT NULL,reference text,note text NOT NULL,
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.historical_refunds ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.historical_refunds FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.historical_refunds TO authenticated;
GRANT ALL ON public.historical_refunds TO service_role;
DROP POLICY IF EXISTS member_read ON public.historical_refunds;
CREATE POLICY member_read ON public.historical_refunds FOR SELECT TO authenticated USING(app_private.is_member());
DROP TRIGGER IF EXISTS audit_historical_refunds ON public.historical_refunds;
CREATE TRIGGER audit_historical_refunds AFTER INSERT OR UPDATE OR DELETE ON public.historical_refunds FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();
CREATE OR REPLACE FUNCTION public.refund_historical_once(p_request_id uuid,p_payload jsonb) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result_id uuid;o public.historical_orders%rowtype;a numeric;gross numeric;paid_back numeric;d date;
BEGIN
 result_id=app_private.begin_request('historical_refund',p_request_id,p_payload);IF result_id IS NOT NULL THEN RETURN result_id; END IF;
 SELECT * INTO o FROM public.historical_orders WHERE id=(p_payload->>'order_id')::uuid FOR UPDATE;
 IF NOT FOUND OR o.review_status='ignored' THEN RAISE EXCEPTION 'Commande historique introuvable ou écartée.'; END IF;
 gross=CASE WHEN o.review_status='accepted' THEN o.confirmed_received ELSE o.source_received END;
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
 IF refunded>0 AND (NEW.review_status='ignored' OR gross IS NULL OR gross<refunded) THEN RAISE EXCEPTION 'Un remboursement est déjà journalisé : conservez le montant brut reçu et la commande pour éviter de déduire deux fois ce remboursement.'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION app_private.protect_refunded_history() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS protect_refunded_history ON public.historical_orders;
CREATE TRIGGER protect_refunded_history BEFORE UPDATE ON public.historical_orders FOR EACH ROW EXECUTE FUNCTION app_private.protect_refunded_history();
REVOKE ALL ON FUNCTION public.refund_historical_once(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.refund_historical_once(uuid,jsonb) TO authenticated;
COMMIT;
