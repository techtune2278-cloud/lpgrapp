'use strict';
const crypto=require('node:crypto');
const COOKIE='__Host-lpgr_admin';
function createAdminService({env=process.env,fetchImpl=globalThis.fetch,now=Date.now}={}){
 const attempts=new Map();
 const configured=()=>typeof env.ADMIN_PASSWORD==='string'&&env.ADMIN_PASSWORD.length>=16&&typeof env.ADMIN_SESSION_SECRET==='string'&&env.ADMIN_SESSION_SECRET.length>=32;
 const signature=data=>crypto.createHmac('sha256',env.ADMIN_SESSION_SECRET).update(data+'|'+env.ADMIN_PASSWORD).digest('base64url');
 const cookie=(token,age)=>`${COOKIE}=${token}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=${age}`;
 function session(headers){try{const raw=(headers.cookie||'').split(';').map(x=>x.trim()).find(x=>x.startsWith(COOKIE+'='))?.slice(COOKIE.length+1);const [payload,sig]=raw.split('.');const expected=signature(payload);if(sig.length!==expected.length||!crypto.timingSafeEqual(Buffer.from(sig),Buffer.from(expected)))return false;const data=JSON.parse(Buffer.from(payload,'base64url'));return data.sub==='valerie'&&data.exp>now()&&data.exp<=now()+8*3600000;}catch{return false;}}
 async function github(method,body,raw=false){
  const repo=env.ADMIN_GITHUB_REPOSITORY||'techtune2278-cloud/site_lpgrapp';if(!/^[\w.-]+\/[\w.-]+$/.test(repo)||!env.ADMIN_GITHUB_TOKEN)throw Error('Configurez le dépôt et le jeton GitHub dans Vercel.');
  const branch=env.ADMIN_GITHUB_BRANCH||'main';const url='https://api.github.com/repos/'+repo+'/contents/content.json'+(method==='GET'?'?ref='+encodeURIComponent(branch):'');
  const response=await fetchImpl(url,{method,headers:{Authorization:'Bearer '+env.ADMIN_GITHUB_TOKEN,Accept:raw?'application/vnd.github.raw+json':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','Content-Type':'application/json'},...(body?{body:JSON.stringify({...body,branch})}:{}),signal:AbortSignal.timeout(15000)});
  if(!response.ok){const error=Error(response.status===409?'Le contenu a changé. Rechargez avant de publier.':'GitHub n’a pas accepté cette opération. Vérifiez la configuration du dépôt.');error.status=response.status===409?409:502;throw error;}
  return raw?response.text():response.json();
 }
 return async ({method,headers={},body,ip=''})=>{
  const reply=(status,data,extra={})=>({status,data,headers:{'Cache-Control':'no-store','X-Robots-Tag':'noindex, nofollow','X-Content-Type-Options':'nosniff',...extra}});
  if(!configured())return reply(503,{error:'Administration à activer : configurez ADMIN_PASSWORD et ADMIN_SESSION_SECRET dans Vercel.'});
  if(!['GET','POST'].includes(method))return reply(405,{error:'Méthode non autorisée.'});
  let data={};
  if(method==='POST'){
   try{const origin=new URL(headers.origin);if(origin.host!==headers.host||!['http:','https:'].includes(origin.protocol))throw Error();}catch{return reply(403,{error:'Origine non autorisée.'});}
   if(!(headers['content-type']||'').startsWith('application/json'))return reply(415,{error:'JSON requis.'});
   try{if(Buffer.byteLength(JSON.stringify(body)||'')>3500000)return reply(413,{error:'Contenu trop volumineux. Réduisez les photos.'});data=typeof body==='string'?JSON.parse(body):body;}catch{return reply(400,{error:'JSON invalide.'});}
   if(!data||typeof data!=='object'||Array.isArray(data))return reply(400,{error:'Demande invalide.'});
   if(data.action==='login'){
    for(const [key,v] of attempts)if(v.until<now())attempts.delete(key);
    const key=crypto.createHash('sha256').update(ip||'unknown').digest('hex');const bucket=attempts.get(key)||{count:0,until:now()+900000};
    if(bucket.count>=5||attempts.size>10000)return reply(429,{error:'Trop de tentatives. Réessayez dans 15 minutes.'});
    bucket.count++;attempts.set(key,bucket);
    const a=crypto.createHash('sha256').update(typeof data.password==='string'?data.password:'').digest(),b=crypto.createHash('sha256').update(env.ADMIN_PASSWORD).digest();
    if(!crypto.timingSafeEqual(a,b))return reply(401,{error:'Mot de passe incorrect.'});
    attempts.delete(key);const payload=Buffer.from(JSON.stringify({sub:'valerie',exp:now()+8*3600000,nonce:crypto.randomBytes(16).toString('hex')})).toString('base64url');
    return reply(200,{ok:true},{'Set-Cookie':cookie(payload+'.'+signature(payload),28800)});
   }
  }
  if(!session(headers))return reply(401,{error:'Connectez-vous pour administrer le site.'});
  if(method==='POST'&&data.action==='logout')return reply(200,{ok:true},{'Set-Cookie':cookie('',0)});
  try{
   const file=await github('GET');if(!file.content&&file.size>1000000)file.content=Buffer.from(await github('GET',undefined,true)).toString('base64');if(!file.content||!file.sha)return reply(502,{error:'Le catalogue GitHub est illisible.'});
   const content=JSON.parse(Buffer.from(file.content,'base64').toString('utf8'));
   if(method==='GET')return reply(200,{content,sha:file.sha,admin:'Valérie Lemoine'});
   if(data.action!=='save')return reply(400,{error:'Action inconnue.'});
   if(data.sha!==file.sha)return reply(409,{error:'Une autre modification est intervenue. Rechargez avant de publier.'});
   if(!['books','events','stores','subscription'].includes(data.section))return reply(400,{error:'Rubrique invalide.'});
   const {validateSection}=require('./content-validation');const value=validateSection(data.section,data.value);
   content[data.section]=value;
   const updated=await github('PUT',{message:'Mise à jour '+data.section+' par Valérie depuis l’administration',sha:file.sha,content:Buffer.from(JSON.stringify(content,null,2)+'\n').toString('base64')});
   return reply(200,{ok:true,sha:updated.content?.sha,commit:updated.commit?.sha,message:'Modifications enregistrées dans GitHub. Vercel reconstruit le site ; vérifiez le déploiement dans quelques instants.'});
  }catch(error){return reply(error.status||400,{error:error.message==='Unexpected end of JSON input'?'Catalogue illisible.':error.message});}
 };
}
module.exports={createAdminService};
