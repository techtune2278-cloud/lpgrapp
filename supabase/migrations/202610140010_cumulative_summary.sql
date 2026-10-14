-- LPGRAPP V0.4.1 : intégrer immédiatement l’historique Excel à la synthèse.
-- Lecture seule des opérations : aucune vente, aucun paiement ni mouvement créé.
BEGIN;
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
 SELECT coalesce(sum(p.amount),0) INTO direct_received FROM public.payments p JOIN public.sales s ON s.id=p.sale_id WHERE s.status='recorded';
 SELECT coalesce(sum(p.amount),0) INTO consignment_received FROM public.consignment_payments p JOIN public.consignment_sales cs ON cs.id=p.consignment_sale_id JOIN public.consignments c ON c.id=cs.consignment_id WHERE c.status<>'cancelled';
 RETURN jsonb_build_object(
 'received_total',history_amount+direct_received+consignment_received,
 'history_received',history_amount,'history_orders',history_orders,
 'history_pending',history_pending,'history_missing_amounts',history_missing,
 'consignment_received',consignment_received,
 'orders_count',history_orders+(SELECT count(*) FROM public.sales WHERE status='recorded'),
 'sales_total',(SELECT coalesce(sum(gross_amount+shipping_charged),0) FROM public.sales WHERE status='recorded'),
 'sales_count',(SELECT count(*) FROM public.sales WHERE status='recorded'),
 'paid_total',direct_received,
 'expense_total',(SELECT coalesce(sum(amount),0) FROM public.expenses WHERE status<>'cancelled'),
 'expense_paid',(SELECT coalesce(sum(amount),0) FROM public.expenses WHERE status='paid'),
 'consignment_pending',(SELECT coalesce(sum(greatest(0,s.net_amount_due-coalesce(p.paid,0))),0) FROM public.consignment_sales s JOIN public.consignments c ON c.id=s.consignment_id LEFT JOIN(SELECT consignment_sale_id,sum(amount) paid FROM public.consignment_payments GROUP BY consignment_sale_id) p ON p.consignment_sale_id=s.id WHERE c.status<>'cancelled'),
 'inventory_initialized',EXISTS(SELECT 1 FROM public.inventory_sessions WHERE status='validated'));
END $$;
REVOKE ALL ON FUNCTION public.dashboard_totals() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.dashboard_totals() TO authenticated;
COMMIT;
