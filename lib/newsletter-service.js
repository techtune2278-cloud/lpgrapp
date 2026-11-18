'use strict';
const {createHash}=require('node:crypto');
const EMAIL=/^[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+$/;
function configured(env){return Boolean(env.BREVO_API_KEY && /^[1-9]\d*$/.test(env.BREVO_NEWSLETTER_LIST_ID||'') && /^[1-9]\d*$/.test(env.BREVO_DOI_TEMPLATE_ID||''));}
function createNewsletterService({env=process.env,fetchImpl=globalThis.fetch,now=Date.now}={}){
 const attempts=new Map();
 return async ({method,headers={},body,ip=''})=>{
  const reply=(status,data)=>({status,data,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
  if(method==='GET')return reply(200,{enabled:configured(env)});
  if(method!=='POST')return reply(405,{error:'Méthode non autorisée.'});
  try{const origin=new URL(headers.origin);if(!['http:','https:'].includes(origin.protocol)||origin.host!==headers.host||!headers.host)return reply(403,{error:'Origine non autorisée.'});}catch{return reply(403,{error:'Origine non autorisée.'});}
  if(!(headers['content-type']||'').startsWith('application/json'))return reply(415,{error:'Format non accepté.'});
  if(Number(headers['content-length'])>4000)return reply(413,{error:'Demande trop volumineuse.'});
  let data;try{if(Buffer.byteLength(JSON.stringify(body))>4000)return reply(413,{error:'Demande trop volumineuse.'});data=typeof body==='string'?JSON.parse(body):body;}catch{return reply(400,{error:'Demande illisible.'});}
  if(!data||typeof data.email!=='string'||data.email.length>254||!EMAIL.test(data.email)||data.consent!==true||data.website||!Number.isFinite(data.startedAt)||now()-data.startedAt<1800||now()-data.startedAt>86400000)return reply(400,{error:'Vérifiez votre adresse et votre accord.'});
  if(!configured(env))return reply(503,{error:'L’inscription est temporairement indisponible.'});
  for(const [key,bucket] of attempts)if(now()>=bucket.reset)attempts.delete(key);
  const key=createHash('sha256').update(ip||data.email.toLowerCase()).digest('hex');const bucket=attempts.get(key)||{count:0,reset:now()+600000};
  if(bucket.count>=3||attempts.size>=10000)return reply(429,{error:'Veuillez réessayer dans quelques minutes.'});bucket.count++;attempts.set(key,bucket);
  let base;try{base=new URL(env.SITE_URL||'https://sitelpgrapp.vercel.app');if(base.protocol!=='https:')throw Error();}catch{return reply(503,{error:'L’inscription est temporairement indisponible.'});}
  try{
   const response=await fetchImpl('https://api.brevo.com/v3/contacts/doubleOptinConfirmation',{method:'POST',headers:{'api-key':env.BREVO_API_KEY,'Content-Type':'application/json',Accept:'application/json'},body:JSON.stringify({email:data.email.trim(),includeListIds:[Number(env.BREVO_NEWSLETTER_LIST_ID)],templateId:Number(env.BREVO_DOI_TEMPLATE_ID),redirectionUrl:base.origin+'/newsletter-confirmee/',contactPixelTrackingConsent:false}),signal:AbortSignal.timeout(10000)});
   if(response.status!==201)return reply(502,{error:'L’envoi du message de confirmation n’a pas pu être confirmé. Réessayez plus tard.'});
   return reply(200,{ok:true,message:'Consultez votre messagerie et cliquez sur le lien reçu pour confirmer votre inscription.'});
  }catch{return reply(502,{error:'L’envoi du message de confirmation n’a pas pu être confirmé. Réessayez plus tard.'});}
 };
}
module.exports={createNewsletterService};
