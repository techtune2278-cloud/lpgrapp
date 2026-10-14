-- Diagnostic en lecture seule de la reprise Excel LPGR'APP.
-- À exécuter dans Supabase > SQL Editor. Aucun changement de données.

select 'Lignes de toutes les feuilles dans la zone de reprise' as indicateur,
       count(*)::bigint as valeur
from public.legacy_import_rows
union all
select 'Lignes historiques dans l’onglet 04 VENTES (hors en-têtes)',
       count(*)::bigint
from public.legacy_import_rows
where sheet_name = '04 VENTES' and row_number > 4
union all
select 'Ventes opérationnelles dans public.sales', count(*)::bigint
from public.sales
union all
select 'Lignes de ventes opérationnelles dans public.sale_items', count(*)::bigint
from public.sale_items
union all
select 'Paiements opérationnels dans public.payments', count(*)::bigint
from public.payments
union all
select 'Contacts dans public.contacts', count(*)::bigint
from public.contacts
union all
select 'Événements dans public.events', count(*)::bigint
from public.events
union all
select 'Dépenses dans public.expenses', count(*)::bigint
from public.expenses
order by indicateur;

-- Répartition des lignes importées par feuille : permet de vérifier si les 28 feuilles ont été reprises.
select sheet_name, count(*)::bigint as lignes_importees,
       min(row_number) as premiere_ligne, max(row_number) as derniere_ligne
from public.legacy_import_rows
group by sheet_name
order by sheet_name;

-- Aperçu des lignes de vente importées telles quelles, sans les transformer en transactions financières.
select row_number,
       row_values ->> 0 as reference_excel,
       row_values ->> 1 as date_source,
       row_values ->> 2 as client,
       row_values ->> 4 as canal,
       row_values ->> 5 as tome,
       row_values ->> 6 as titre,
       row_values ->> 7 as quantite,
       row_values ->> 9 as prix_unitaire,
       row_values ->> 10 as chiffre_affaires_ligne,
       row_values ->> 12 as encaissement_commande,
       review_status,
       review_note
from public.legacy_import_rows
where sheet_name = '04 VENTES' and row_number > 4
order by row_number
limit 50;
