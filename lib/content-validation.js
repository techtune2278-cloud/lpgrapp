'use strict';
const {isDeepStrictEqual}=require('node:util');
function validateSection(section,value,previous){
 const fail=()=>{throw Error('Vérifiez les champs : numéro, nom, date, prix et adresses des images/liens.');};
 const text=(x,max=1000)=>typeof x==='string'&&x.length<=max&&!/[\u0000-\u0008]/.test(x);
 const url=x=>!x||typeof x==='string'&&(x.startsWith('/assets/')&&!x.includes('..')||/^https:\/\//.test(x)||/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(x));
 const month=x=>!x||typeof x==='string'&&/^\d{4}-(0[1-9]|1[0-2])$/.test(x);
 const day=x=>!x||typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&!Number.isNaN(Date.parse(x))&&new Date(x).toISOString().slice(0,10)===x;
 if(section==='subscription'){
  if(!value||!Number.isInteger(value.min_books)||!Number.isInteger(value.max_books)||value.min_books<1||value.max_books<value.min_books||value.max_books>120)fail();return {min_books:value.min_books,max_books:value.max_books,max_parcel:3};
 }
 if(!Array.isArray(value)||value.length>500)fail();
 const ids=new Set();
 const oldEvents=new Map(section==='events'&&Array.isArray(previous)?previous.map(row=>[row.slug,row]):[]);
 for(const row of value){
  if(!row||typeof row!=='object')fail();const id=section==='books'?row.number:row.slug;
  if(ids.has(id))throw Error('Un numéro ou identifiant est utilisé deux fois.');ids.add(id);
  if(section==='books'){
   if(!Number.isInteger(row.number)||row.number<1||!text(row.title,150)||!row.title.trim()||!/^[-a-z0-9]+$/.test(row.slug)||typeof row.available!=='boolean'||!Number.isFinite(row.price)||row.price<=0||row.price>1000||!Number.isInteger(row.pages)||row.pages<1||!month(row.release_month)||!url(row.cover)||!text(row.description||'',10000)||!text(row.isbn||'',30)||!/^#[0-9a-fA-F]{6}$/.test(row.color)||!url(row.commande_url)||row.commande_url&&!row.commande_url.startsWith('https://'))fail();
   if(!['paru','prochain','plus_tard',undefined].includes(row.status))fail();
   if(row.excerpts&&(!Array.isArray(row.excerpts)||row.excerpts.length>4||row.excerpts.some(x=>!url(x))))fail();
  }else{
   if(!/^[-a-z0-9]+$/.test(row.slug))fail();
   if(section==='bonuses'){
    let media;
    try{media=new URL(row.url);}catch{}
    let localAudio=false;
    if(row.type==='audio'&&typeof row.url==='string'&&row.url.startsWith('/audio/')){
     try{
      const raw=row.url.slice(7),name=decodeURIComponent(raw);
      localAudio=!/[?#\\/\u0000-\u001f]/.test(name)&&/\.(mp3|m4a|wav|ogg|aac|flac|webm)$/i.test(name)&&new URL(row.url,'https://example.org').pathname.startsWith('/audio/');
     }catch{}
    }
    const external=media&&media.protocol==='https:'&&!media.username&&!media.password;
    if(!text(row.author,150)||!row.author.trim()||!text(row.title,300)||!row.title.trim()||!['audio','video'].includes(row.type)||!text(row.url,2000)||!(localAudio||external))throw Error('Pour chaque bonus, indiquez un auteur, un titre, un type et un chemin /audio/nom-du-fichier.mp3 (audio) ou un lien HTTPS (film).');
   }
   if(section==='events'&&!isDeepStrictEqual(oldEvents.get(row.slug),row)){
    const label=row.title?.trim?.()||'Nouvel événement';
    if(!text(row.title,200)||!row.title.trim()||!text(row.city,150)||!row.city.trim()||!row.start_date||!day(row.start_date))throw Error(label+' : renseignez le nom, la ville et une date de début valide.');
    if(!day(row.end_date)||(row.end_date&&row.end_date<row.start_date))throw Error(label+' : la date de fin doit être égale ou postérieure à la date de début.');
    if(![undefined,'rencontre','salon','marche'].includes(row.kind)||!text(row.place||'',200)||!url(row.image)||!text(row.description||'',5000))throw Error(label+' : vérifiez le type, le lieu, la photo et la présentation.');
   }
   if(section==='stores'&&(!text(row.name,150)||!text(row.city||'',150)||!text(row.address||'',250)||!text(row.phone||'',40)||!url(row.url)||row.url&&!row.url.startsWith('https://')))fail();
  }
 }
 if(section==='books'&&new Set(value.map(x=>x.slug)).size!==value.length)throw Error('Deux livres utilisent la même adresse.');
 return value;
}
module.exports={validateSection};
