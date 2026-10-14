BEGIN;
ALTER TABLE public.workbook_reconciliation ADD COLUMN IF NOT EXISTS resolved_at timestamptz;
ALTER TABLE public.workbook_reconciliation ADD COLUMN IF NOT EXISTS resolved_by uuid REFERENCES auth.users(id);
CREATE OR REPLACE FUNCTION public.search_workbook_rows(p_import_id uuid,p_sheet text DEFAULT NULL,p_query text DEFAULT NULL,p_templates boolean DEFAULT false,p_offset integer DEFAULT 0,p_limit integer DEFAULT 40)
RETURNS TABLE(id uuid,sheet_name text,row_number integer,row_values jsonb,row_formulas jsonb,metadata jsonb,total_count bigint)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT r.id,r.sheet_name,r.row_number,r.row_values,r.row_formulas,m.metadata,count(*) OVER()
 FROM public.legacy_import_rows r JOIN public.workbook_imports i ON i.source_key=r.source_file
 JOIN public.workbook_row_metadata m ON m.import_id=i.id AND m.sheet_name=r.sheet_name AND m.row_number=r.row_number
 WHERE i.id=p_import_id AND (p_sheet IS NULL OR r.sheet_name=p_sheet)
 AND (p_templates OR m.row_kind<>'template')
 AND (nullif(trim(p_query),'') IS NULL OR r.row_values::text ILIKE '%'||p_query||'%' OR r.sheet_name ILIKE '%'||p_query||'%')
 ORDER BY r.sheet_name,r.row_number LIMIT least(greatest(p_limit,1),100) OFFSET greatest(p_offset,0)
$$;
CREATE OR REPLACE FUNCTION public.resolve_workbook_difference(p_id bigint,p_apply boolean,p_note text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.workbook_reconciliation%rowtype; current_amount numeric;
BEGIN
 IF NOT app_private.is_admin() THEN RAISE EXCEPTION 'Action réservée à l’administration.' USING ERRCODE='42501'; END IF;
 IF length(trim(coalesce(p_note,'')))<5 THEN RAISE EXCEPTION 'Précisez le justificatif de votre décision.'; END IF;
 SELECT * INTO r FROM public.workbook_reconciliation WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR r.resolved_at IS NOT NULL THEN RAISE EXCEPTION 'Écart introuvable ou déjà traité.'; END IF;
 IF p_apply THEN
  IF r.entity<>'expense' THEN RAISE EXCEPTION 'Type d’écart non pris en charge.'; END IF;
  SELECT amount INTO current_amount FROM public.expenses WHERE source_legacy='excel:06 DEPENSES:'||r.reference FOR UPDATE;
  IF NOT FOUND OR current_amount IS DISTINCT FROM (r.current_value#>>'{}')::numeric THEN RAISE EXCEPTION 'La dépense a changé depuis l’import : rapprochez-la à nouveau avant de modifier son montant.'; END IF;
  UPDATE public.expenses SET amount=(r.source_value#>>'{}')::numeric WHERE source_legacy='excel:06 DEPENSES:'||r.reference;
 END IF;
 UPDATE public.workbook_reconciliation SET resolution=CASE WHEN p_apply THEN 'Valeur Excel retenue : ' ELSE 'Valeur existante conservée : ' END||trim(p_note),resolved_at=now(),resolved_by=auth.uid() WHERE id=p_id;
END $$;

CREATE TABLE IF NOT EXISTS public.app_requests(
 actor_id uuid NOT NULL REFERENCES auth.users(id), action text NOT NULL, request_id uuid NOT NULL,
 fingerprint text NOT NULL, result uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(actor_id,action,request_id)
);
ALTER TABLE public.app_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_requests FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.app_requests TO service_role;
CREATE OR REPLACE FUNCTION public.create_sale_once(p_request_id uuid,p_payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.app_requests%rowtype; result_id uuid; h text;
BEGIN
 PERFORM app_private.require_member();
 IF p_request_id IS NULL THEN RAISE EXCEPTION 'Identifiant de requête manquant.'; END IF;
 h=md5(p_payload::text);
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':sale:'||p_request_id::text,0));
 SELECT * INTO r FROM public.app_requests WHERE actor_id=auth.uid() AND action='sale' AND request_id=p_request_id;
 IF FOUND THEN IF r.fingerprint<>h THEN RAISE EXCEPTION 'Cette requête a déjà été utilisée avec un autre contenu.'; END IF; RETURN r.result; END IF;
 result_id=public.create_sale((p_payload->>'p_sale_date')::date,(p_payload->>'p_contact_id')::uuid,p_payload->>'p_channel',p_payload->>'p_payment_method',(p_payload->>'p_payment_amount')::numeric,(p_payload->>'p_shipping_charged')::numeric,p_payload->>'p_note',p_payload->'p_items');
 INSERT INTO public.app_requests(actor_id,action,request_id,fingerprint,result) VALUES(auth.uid(),'sale',p_request_id,h,result_id);
 RETURN result_id;
END $$;
CREATE OR REPLACE FUNCTION public.record_sale_payment_once(p_request_id uuid,p_payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.app_requests%rowtype; result_id uuid; h text;
BEGIN
 PERFORM app_private.require_member();
 IF p_request_id IS NULL THEN RAISE EXCEPTION 'Identifiant de requête manquant.'; END IF;
 h=md5(p_payload::text);
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':payment:'||p_request_id::text,0));
 SELECT * INTO r FROM public.app_requests WHERE actor_id=auth.uid() AND action='payment' AND request_id=p_request_id;
 IF FOUND THEN IF r.fingerprint<>h THEN RAISE EXCEPTION 'Cette requête a déjà été utilisée avec un autre contenu.'; END IF; RETURN r.result; END IF;
 result_id=public.record_sale_payment((p_payload->>'p_sale_id')::uuid,(p_payload->>'p_payment_date')::date,(p_payload->>'p_amount')::numeric,p_payload->>'p_payment_method',p_payload->>'p_reference',p_payload->>'p_note');
 INSERT INTO public.app_requests(actor_id,action,request_id,fingerprint,result) VALUES(auth.uid(),'payment',p_request_id,h,result_id);
 RETURN result_id;
END $$;
REVOKE ALL ON FUNCTION public.search_workbook_rows(uuid,text,text,boolean,integer,integer),public.resolve_workbook_difference(bigint,boolean,text),public.create_sale_once(uuid,jsonb),public.record_sale_payment_once(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.search_workbook_rows(uuid,text,text,boolean,integer,integer),public.resolve_workbook_difference(bigint,boolean,text),public.create_sale_once(uuid,jsonb),public.record_sale_payment_once(uuid,jsonb) TO authenticated;
COMMIT;
