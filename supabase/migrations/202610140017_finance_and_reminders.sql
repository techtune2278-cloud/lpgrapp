BEGIN;
CREATE OR REPLACE FUNCTION public.expense_payment_summary() RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 PERFORM app_private.require_member();
 SELECT jsonb_build_object(
 'paid',coalesce(sum(amount) FILTER(WHERE status='paid'),0),
 'to_pay',coalesce(sum(amount) FILTER(WHERE status='to_pay'),0),
 'recorded',coalesce(sum(amount) FILTER(WHERE status<>'cancelled'),0),
 'by_payer',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.amount DESC,p.payer) FROM (
 SELECT coalesce(nullif(trim(paid_by),''),'Non renseigné') payer,sum(amount) amount,count(*) count
 FROM public.expenses WHERE status='paid' GROUP BY coalesce(nullif(trim(paid_by),''),'Non renseigné')
 ) p),'[]'::jsonb)) INTO result FROM public.expenses;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.commercial_reminders(p_today date DEFAULT current_date) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 PERFORM app_private.require_member();
 IF p_today IS NULL THEN RAISE EXCEPTION 'Date requise.'; END IF;
 WITH pending AS(
 SELECT a.id,a.due_date,a.next_action,a.summary,coalesce(c.name,'Contact') contact_name
 FROM public.crm_actions a LEFT JOIN public.contacts c ON c.id=a.contact_id
 WHERE a.status IN('planned','waiting') AND a.due_date IS NOT NULL
 ), upcoming AS(SELECT * FROM pending ORDER BY due_date,id LIMIT 8)
 SELECT jsonb_build_object('overdue',(SELECT count(*) FROM pending WHERE due_date<p_today),
 'today',(SELECT count(*) FROM pending WHERE due_date=p_today),
 'next_seven_days',(SELECT count(*) FROM pending WHERE due_date>p_today AND due_date<=p_today+7),
 'total',(SELECT count(*) FROM pending),'rows',coalesce((SELECT jsonb_agg(to_jsonb(u) ORDER BY u.due_date,u.id) FROM upcoming u),'[]'::jsonb)) INTO result;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.expense_payment_summary(),public.commercial_reminders(date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.expense_payment_summary(),public.commercial_reminders(date) TO authenticated;
COMMIT;
