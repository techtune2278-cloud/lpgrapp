export type WorkbookSummary = {
  imported: boolean; import_id?: string; source_name?: string; source_key?: string;
  orders?: number; accepted?: number; to_review?: number; needs_clarification?: number; ignored?: number;
  confirmed_received?: number;
  source?: {sheet_count:number;source_rows:number;order_count:number;sale_line_count:number;source_quantity:number;source_received:number;physical_counts:number;physical_total:number;expense_total:number};
  sheets?: {name:string;rows:number;template_rows:number;headers?:string[]}[];
};
export type HistoricalOrder = {
  id:string;import_id:string;reference:string;contact_id:string|null;customer_name:string;channel:string|null;
  source_sale_date:string|null;source_received:number|null;classification:string;flags:string[];review_status:string;
  confirmed_sale_date:string|null;confirmed_total:number|null;confirmed_received:number|null;review_note:string|null;
};
export type HistoricalLine = {
  id:string;order_id:string;source_row:number;book_id:string|null;tome_number:number|null;source_quantity:number|null;
  source_unit_price:number|null;source_line_total:number|null;source_received:number|null;payment_method:string|null;source_note:string|null;
  confirmed_quantity:number|null;delivered_quantity:number|null;
};
export const classifications:Record<string,string>={sale:'Vente',subscription:'Abonnement',donation:'Don gratuit',consignment:'Dépôt-vente',loan:'Prêt',unclassified:'À préciser'};
