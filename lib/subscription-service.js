'use strict';
const {quote,summary}=require('./subscription-rules');const {createContactService}=require('./contact-service');const {createNewsletterService}=require('./newsletter-service');
function createSubscriptionService({catalog,config={},env=process.env,fetchImpl=globalThis.fetch,now=Date.now,legalText=''}={}){
 const contact=createContactService({env:{...env,CONTACT_TO_EMAIL:'contact@lesplusgrandsracontes.fr'},fetchImpl,now});
 const newsletter=createNewsletterService({env,fetchImpl,now});
 return async request=>{
  if(request.method!=='POST')return contact(request);
  const fail=(status,error)=>({status,data:{error},headers:{'Cache-Control':'no-store'}});let data;
  try{if(Buffer.byteLength(JSON.stringify(request.body)||'')>24000)return fail(413,'Demande trop volumineuse.');data=typeof request.body==='string'?JSON.parse(request.body):request.body;}catch{return fail(400,'Demande illisible.');}
  if(!data||data.terms!==true||data.acknowledge!==true)return fail(400,'Validez les deux cases obligatoires.');
  let value;try{value=quote(catalog,data.lines,data.reservedIds,config);}catch(error){return fail(400,error.message);}
  if(data.expectedTotal!==value.total)return fail(409,'Le montant a changé. Rechargez la page.');
  for(const [key,max] of Object.entries({phone:40,billing_address:500,recipient_name:120,address:200,address_extra:200,postal_code:5,city:120,card_message:1000}))if(data[key]!==undefined&&(typeof data[key]!=='string'||data[key].length>max||(key!=='card_message'&&/[\r\n]/.test(data[key]))))return fail(400,'Vérifiez les coordonnées.');
  if(value.paid.length&&(!data.billing_address?.trim()||!data.recipient_name?.trim()||!data.address?.trim()||!data.city?.trim()||!/^\d{5}$/.test(data.postal_code)||data.country!=='France'))return fail(400,'Complétez les adresses de facturation et de livraison en France.');
  const message=summary(value)+`\n\nFacturation : ${data.billing_address||'À confirmer'}\nDestinataire : ${data.recipient_name||'À confirmer'}\n${data.address||''}\n${data.address_extra||''}\n${data.postal_code||''} ${data.city||''}\nTéléphone : ${data.phone||''}\nMot pour la carte : ${data.card_message||''}\n\nCGV acceptées ; demande sans paiement comprise.\nInfolettre demandée : ${data.newsletter===true?'oui (confirmation requise)':'non'}`;
  const answer=await contact({...request,body:{nom:data.nom,email:data.email,profil:'Un particulier',sujet:'Demande d’abonnement — facture puis virement',message,consent:true,startedAt:data.startedAt,website:data.website}});
  if(answer.status!==200)return answer;
  let acknowledged=false;
  try{
   const response=await fetchImpl('https://api.brevo.com/v3/smtp/email',{method:'POST',headers:{'api-key':env.BREVO_API_KEY,'Content-Type':'application/json'},body:JSON.stringify({sender:{email:env.CONTACT_FROM_EMAIL,name:env.CONTACT_FROM_NAME||'Sur le Chemin des Arts'},to:[{email:data.email.trim()}],subject:'Votre demande de livres a bien été reçue',textContent:'Bonjour '+data.nom+',\n\nNous avons reçu votre demande. Après vérification, nous vous adresserons une facture valable 15 jours. Le règlement se fait par virement, en une seule fois. Aucun paiement n’a été effectué.\n\n'+message+'\n\nContact : contact@lesplusgrandsracontes.fr',...(legalText?{attachment:[{name:'CGV-et-retractation.txt',content:Buffer.from(legalText).toString('base64')}]}:{})}),signal:AbortSignal.timeout(10000)});if(response.ok)acknowledged=Boolean((await response.json()).messageId);
  }catch{}
  let newsletterStatus='not_requested';if(data.newsletter===true){const n=await newsletter({...request,body:{email:data.email,consent:true,website:'',startedAt:data.startedAt}});newsletterStatus=n.status===200?'confirmation_sent':'unavailable';}
  return {...answer,data:{ok:true,acknowledged,newsletterStatus,message:acknowledged?'Votre demande a été transmise. Un accusé de réception vous a été envoyé. Nous vérifierons les colis avant d’établir la facture.':'Votre demande a été transmise, mais l’accusé de réception automatique n’a pas pu être confirmé. Contactez-nous si nécessaire.'}};
 };
}
module.exports={createSubscriptionService};
