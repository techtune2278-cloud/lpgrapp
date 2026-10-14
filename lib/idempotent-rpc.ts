import {getSupabase} from './supabase';
// Only hashes and request IDs are stored locally, never customer details.
export async function submitOnce(action:'create_sale_once'|'record_sale_payment_once'|'adjust_sale_once'|'refund_sale_once'|'open_historical_commitment_once'|'record_opening_payment_once'|'ship_historical_order_once'|'refund_historical_once'|'pay_historical_once',payload:Record<string,unknown>){
 const sb=getSupabase();if(!sb)throw new Error('Connexion indisponible.');
 const {data:{user},error}=await sb.auth.getUser();if(error||!user)throw new Error('Veuillez vous reconnecter.');
 const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify(payload)));
 const fingerprint=Array.from(new Uint8Array(bytes)).map(x=>x.toString(16).padStart(2,'0')).join('');
 const slot=`lpgrapp:pending:${user.id}:${action}`;
 let token=crypto.randomUUID();
 try{const cached=JSON.parse(sessionStorage.getItem(slot)??'null');if(cached?.fingerprint===fingerprint&&cached?.token)token=cached.token;sessionStorage.setItem(slot,JSON.stringify({fingerprint,token}));}catch{throw new Error('Le navigateur ne permet pas de sécuriser l’envoi. Autorisez le stockage de session puis réessayez.');}
 const result=await sb.rpc(action,{p_request_id:token,p_payload:payload});
 if(result.error)throw result.error;
 sessionStorage.removeItem(slot);return result.data;
}
