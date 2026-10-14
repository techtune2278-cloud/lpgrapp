import 'server-only';
import {createClient} from '@supabase/supabase-js';
import {authorizedCron,DeliveryError,executeReminder,parisDate,publishNtfy,readConfig,validateDigest} from './core';
export function reply(data:unknown,status=200){return Response.json(data,{status,headers:{'Cache-Control':'no-store'}})}
export async function adminSession(request:Request){
 const header=request.headers.get('authorization');
 if(!header?.startsWith('Bearer '))return null;
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;if(!url||!key)return null;
 const token=header.slice(7);
 try{
  const sb=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{headers:{Authorization:`Bearer ${token}`}}});
  const u=await sb.auth.getUser(token);if(u.error||!u.data.user)return null;
  const m=await sb.from('app_members').select('is_active,can_admin').eq('user_id',u.data.user.id).maybeSingle();
  return !m.error&&m.data?.is_active&&m.data?.can_admin?sb:null;
 }catch{return null}
}
export async function statusHandler(request:Request){
 const sb=await adminSession(request);if(!sb)return reply({error:'Accès administrateur requis.'},403);
 const cfg=readConfig(process.env);
 const r=await sb.from('notification_runs').select('state,created_at,completed_at,error_code').order('created_at',{ascending:false}).limit(1);
 return reply({enabled:cfg.enabled,ready:cfg.ready,missing:cfg.missing,reason:cfg.reason??null,last:r.data?.[0]??null,migrationReady:!r.error});
}
export async function reminderHandler(request:Request,test=false){
 if(test){if(!await adminSession(request))return reply({error:'Accès administrateur requis.'},403)}
 else if(!authorizedCron(request.headers.get('authorization'),process.env.CRON_SECRET))return reply({error:'Non autorisé.'},401);
 const cfg=readConfig(process.env);
 if(!cfg.enabled)return reply({status:'disabled'});
 if(!cfg.ready||!cfg.config)return reply({error:'Configuration ntfy incomplète ou invalide.'},503);
 try{
  const sb=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.SUPABASE_SERVICE_ROLE_KEY!,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
  const now=new Date();let digest={actions:0,contacts:0,overdue_actions:0,overdue_contacts:0};
  if(!test){const r=await sb.rpc('ntfy_digest',{p_today:parisDate(now)});if(r.error)throw new DeliveryError('database_unavailable');digest=validateDigest(r.data)}
  const result=await executeReminder({test,now,digest,
   claim:async(slot,d)=>{const r=await sb.rpc('claim_notification_run',{p_slot:slot,p_actions:d.actions,p_contacts:d.contacts});if(r.error)throw new DeliveryError('database_unavailable');return r.data},
   finish:async(id,lease,state,error)=>{const r=await sb.rpc('finish_notification_run',{p_id:id,p_lease:lease,p_state:state,p_error_code:error??null});if(r.error)throw new DeliveryError('tracking_unavailable');return r.data===true},
   publish:(d,isTest)=>publishNtfy(cfg.config!,d,isTest)
  });return reply(result);
 }catch(error){const code=error instanceof DeliveryError?error.code:'service_unavailable';return reply({error:'Notification non confirmée. Consultez le suivi ntfy.',code},503)}
}
