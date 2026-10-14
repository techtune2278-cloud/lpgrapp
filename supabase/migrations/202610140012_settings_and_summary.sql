BEGIN;
CREATE TABLE IF NOT EXISTS public.collection_settings(
 id boolean PRIMARY KEY DEFAULT true CHECK(id),future_graphic_cost numeric(12,2) NOT NULL DEFAULT 420 CHECK(future_graphic_cost>=0),
 future_print_cost numeric(12,2) NOT NULL DEFAULT 705.50 CHECK(future_print_cost>=0),future_print_quantity integer NOT NULL DEFAULT 100 CHECK(future_print_quantity>0),
 reduced_min_quantity integer NOT NULL DEFAULT 5 CHECK(reduced_min_quantity>0),updated_at timestamptz NOT NULL DEFAULT now(),updated_by uuid REFERENCES auth.users(id)
);
INSERT INTO public.collection_settings(id) VALUES(true) ON CONFLICT(id) DO NOTHING;
CREATE TABLE IF NOT EXISTS public.shipping_rates(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),zone text NOT NULL CHECK(zone IN('France','Europe','US')),quantity integer NOT NULL CHECK(quantity>0),
 amount numeric(12,2) NOT NULL CHECK(amount>=0),is_active boolean NOT NULL DEFAULT true,
 updated_at timestamptz NOT NULL DEFAULT now(),updated_by uuid REFERENCES auth.users(id),UNIQUE(zone,quantity)
);
-- Initialisation depuis les valeurs déjà dans Supabase. Jamais de lecture du fichier Excel.
INSERT INTO public.shipping_rates(zone,quantity,amount)
 SELECT z.zone,(r.row_values->>0)::integer,(r.row_values->>z.col)::numeric
 FROM public.workbook_resources r JOIN public.workbook_imports i ON i.id=r.import_id
 CROSS JOIN(VALUES('France',1),('Europe',2),('US',3)) z(zone,col)
 WHERE i.is_current AND r.section='postal_rates' AND (r.row_values->>0)~'^[0-9]+$' AND (r.row_values->>z.col)~'^[0-9]+(\.[0-9]+)?$'
 ON CONFLICT(zone,quantity) DO NOTHING;
CREATE OR REPLACE FUNCTION public.save_collection_settings(p_graphic numeric,p_print numeric,p_quantity integer,p_reduced integer) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT app_private.is_admin() THEN RAISE EXCEPTION 'Réglages réservés à l’administration.' USING ERRCODE='42501'; END IF;
 IF p_graphic IS NULL OR p_print IS NULL OR p_quantity IS NULL OR p_reduced IS NULL OR p_graphic<0 OR p_print<0 OR p_quantity<=0 OR p_reduced<=0 OR p_graphic::text IN('NaN','Infinity','-Infinity') OR p_print::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Paramètres invalides.'; END IF;
 UPDATE public.collection_settings SET future_graphic_cost=p_graphic,future_print_cost=p_print,future_print_quantity=p_quantity,reduced_min_quantity=p_reduced,updated_at=now(),updated_by=auth.uid() WHERE id;
END $$;
CREATE OR REPLACE FUNCTION public.save_shipping_rate(p_zone text,p_quantity integer,p_amount numeric,p_active boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT app_private.is_admin() THEN RAISE EXCEPTION 'Tarifs réservés à l’administration.' USING ERRCODE='42501'; END IF;
 IF p_zone IS NULL OR p_zone NOT IN('France','Europe','US') OR p_quantity IS NULL OR p_quantity<=0 OR p_amount IS NULL OR p_amount<0 OR p_amount::text IN('NaN','Infinity','-Infinity') OR p_active IS NULL THEN RAISE EXCEPTION 'Zone, quantité ou tarif invalide.'; END IF;
 INSERT INTO public.shipping_rates(zone,quantity,amount,is_active,updated_by) VALUES(p_zone,p_quantity,p_amount,p_active,auth.uid())
 ON CONFLICT(zone,quantity) DO UPDATE SET amount=excluded.amount,is_active=excluded.is_active,updated_by=auth.uid(),updated_at=now();
END $$;
CREATE OR REPLACE FUNCTION public.collection_projection() RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 PERFORM app_private.require_member();
 SELECT jsonb_agg(jsonb_build_object('book_id',b.id,'tome_number',b.tome_number,'title',b.title,'status',b.status,
 'graphic',coalesce(b.illustrator_cost,s.future_graphic_cost),'printing',coalesce(b.printer_cost,s.future_print_cost),
 'total',coalesce(b.illustrator_cost,s.future_graphic_cost)+coalesce(b.printer_cost,s.future_print_cost),
 'estimated',b.illustrator_cost IS NULL OR b.printer_cost IS NULL) ORDER BY b.tome_number) INTO result FROM public.books b CROSS JOIN public.collection_settings s;
 RETURN coalesce(result,'[]'::jsonb);
END $$;
DO $security$ DECLARE t text;BEGIN
 FOREACH t IN ARRAY ARRAY['collection_settings','shipping_rates'] LOOP
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
REVOKE ALL ON FUNCTION public.save_collection_settings(numeric,numeric,integer,integer),public.save_shipping_rate(text,integer,numeric,boolean),public.collection_projection() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_collection_settings(numeric,numeric,integer,integer),public.save_shipping_rate(text,integer,numeric,boolean),public.collection_projection() TO authenticated;
COMMIT;
