BEGIN;
CREATE OR REPLACE FUNCTION public.search_sales_financials(p_query text DEFAULT '',p_offset integer DEFAULT 0,p_limit integer DEFAULT 20)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE result jsonb; term text:=trim(coalesce(p_query,''));
BEGIN
 PERFORM app_private.require_member();
 IF p_offset IS NULL OR p_offset<0 OR p_limit IS NULL OR p_limit<1 OR p_limit>500 THEN RAISE EXCEPTION 'Pagination invalide.'; END IF;
 WITH found AS (
 SELECT f.*,coalesce(c.name,'Vente directe') customer_name FROM public.v_sales_financials f LEFT JOIN public.contacts c ON c.id=f.contact_id
 WHERE term='' OR position(lower(term) in lower('V-'||f.sale_number::text||' '||coalesce(f.channel,'')||' '||coalesce(c.name,'')))>0
 ), page AS(SELECT * FROM found ORDER BY created_at DESC,id LIMIT p_limit OFFSET p_offset)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM found),'rows',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM page p),'[]'::jsonb)) INTO result;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.search_sales_financials(text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.search_sales_financials(text,integer,integer) TO authenticated;
COMMIT;
