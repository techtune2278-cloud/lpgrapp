import {timingSafeEqual} from 'node:crypto';
export type Digest={actions:number;contacts:number;overdue_actions:number;overdue_contacts:number};
export type Claim={claimed:boolean;id?:string;lease?:string};
export type PublishConfig={serverUrl:string;topic:string;token:string;appUrl:string};
export class DeliveryError extends Error{
 code:string;uncertain:boolean;
 constructor(code:string,uncertain=false){super(code);this.name='DeliveryError';this.code=code;this.uncertain=uncertain;}
}
export function authorizedCron(header:string|null,secret:string|undefined){
 if(!secret||secret.length<32||!header)return false;
 const actual=Buffer.from(header),expected=Buffer.from(`Bearer ${secret}`);
 return actual.length===expected.length&&timingSafeEqual(actual,expected);
}
export function parisDate(now:Date){return new Intl.DateTimeFormat('sv-SE',{timeZone:'Europe/Paris',year:'numeric',month:'2-digit',day:'2-digit'}).format(now)}
export function readConfig(env:Record<string,string|undefined>){
 const enabled=env.NTFY_ENABLED==='true';
 if(!enabled)return {enabled:false,ready:false,missing:[] as string[]};
 if(env.VERCEL_ENV&&env.VERCEL_ENV!=='production')return {enabled:true,ready:false,missing:[] as string[],reason:'preview_disabled'};
 const required=['NTFY_SERVER_URL','NTFY_TOPIC','NTFY_TOKEN','LPGRAPP_URL','SUPABASE_SERVICE_ROLE_KEY','CRON_SECRET','NEXT_PUBLIC_SUPABASE_URL'];
 const missing=required.filter(k=>!env[k]);if(missing.length)return {enabled:true,ready:false,missing};
 try{
  const server=new URL(env.NTFY_SERVER_URL!),app=new URL(env.LPGRAPP_URL!);
  for(const u of [server,app])if(u.protocol!=='https:'||u.username||u.password||u.search||u.hash)throw new Error();
  if(!/^[A-Za-z0-9_-]{1,128}$/.test(env.NTFY_TOPIC!)||env.NTFY_TOKEN!.length<16||/[\r\n]/.test(env.NTFY_TOKEN!)||env.CRON_SECRET!.length<32)throw new Error();
  return {enabled:true,ready:true,missing,config:{serverUrl:server.href.replace(/\/$/,''),topic:env.NTFY_TOPIC!,token:env.NTFY_TOKEN!,appUrl:app.origin}};
 }catch{return {enabled:true,ready:false,missing:[] as string[],reason:'configuration_invalid'}}
}
export function validateDigest(value:unknown):Digest{
 const d=value as Digest;if(!d||['actions','contacts','overdue_actions','overdue_contacts'].some(k=>!Number.isSafeInteger(d[k as keyof Digest])||d[k as keyof Digest]<0)||d.overdue_actions>d.actions||d.overdue_contacts>d.contacts)throw new DeliveryError('digest_invalid');return d;
}
export function messageFor(d:Digest,test=false){
 if(test)return 'Notification de test LPGRAPP. Le canal est joignable. Ouvrez l’application pour retrouver vos données.';
 const plural=(n:number,s:string,p:string)=>`${n} ${n===1?s:p}`;
 return `${plural(d.actions,'action commerciale','actions commerciales')} et ${plural(d.contacts,'contact','contacts')} à suivre, dont ${d.overdue_actions+d.overdue_contacts} en retard. Ouvrez LPGRAPP pour consulter les détails.`;
}
export async function publishNtfy(config:PublishConfig,d:Digest,test=false,fetcher:typeof fetch=fetch){
 const click=new URL(!test&&d.contacts>0&&d.actions===0?'/contacts':!test&&d.actions>0&&d.contacts===0?'/crm':'/',config.appUrl).href;
 let response:Response;
 try{response=await fetcher(`${config.serverUrl}/${config.topic}`,{method:'POST',headers:{Authorization:`Bearer ${config.token}`,'Content-Type':'text/plain; charset=utf-8',Title:test?'LPGRAPP - Test':'LPGRAPP - Rappels',Click:click,Priority:'3'},body:messageFor(d,test),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(10000)})}
 catch{throw new DeliveryError('delivery_uncertain',true)}
 if(!response.ok)throw new DeliveryError(response.status>=500?'delivery_uncertain':'provider_rejected',response.status>=500);
}
export async function executeReminder(options:{test:boolean;now:Date;digest:Digest;claim:(slot:string,d:Digest)=>Promise<Claim>;finish:(id:string,lease:string,state:string,error?:string)=>Promise<boolean>;publish:(d:Digest,test:boolean)=>Promise<void>}){
 const {test,now}=options,d=validateDigest(options.digest);
 const slot=test?`test:${now.toISOString().slice(0,16)}`:`daily:${parisDate(now)}`;
 const claim=await options.claim(slot,d);if(!claim.claimed)return {status:'already_processed'};
 if(!claim.id||!claim.lease)throw new DeliveryError('claim_invalid');
 const finish=async(state:string,error?:string)=>{if(!await options.finish(claim.id!,claim.lease!,state,error))throw new DeliveryError('tracking_unavailable')};
 if(!test&&d.actions+d.contacts===0){await finish('empty');return {status:'empty'}}
 try{await options.publish(d,test)}catch(error){
  const known=error instanceof DeliveryError&&!error.uncertain&&error.code==='provider_rejected';
  await finish(known?'failed':'uncertain',known?'provider_rejected':'delivery_uncertain');throw new DeliveryError(known?'provider_rejected':'delivery_uncertain',!known);
 }
 await finish('sent');return {status:'sent'};
}
