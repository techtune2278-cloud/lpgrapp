export type Book={id:string;tome_number:number;title:string;status:string;isbn:string|null;price_public:number|null;price_reduced:number|null;reorder_threshold:number;critical_threshold:number;subtitle?:string|null;ean?:string|null};
export type Contact={id:string;name:string;contact_type:string;email?:string|null;phone?:string|null;city?:string|null};
export type StockSummary={book_id:string;warehouse_stock:number;consignment_stock:number;loaned_stock:number;damaged_stock:number;owned_stock:number};
export type SaleItemDraft={book_id:string;quantity:number;unit_price:number};
