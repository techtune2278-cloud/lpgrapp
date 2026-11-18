(function(root){
 'use strict';
 const currentMonth=(now=new Date())=>new Intl.DateTimeFormat('sv-SE',{timeZone:'Europe/Paris',year:'numeric',month:'2-digit'}).format(now);
 function quote(catalog,lines,reservedIds=[],config={},month=currentMonth()){
  const min=config.min_books||3,max=config.max_books||12;
  if(!Array.isArray(lines)||!Array.isArray(reservedIds)||lines.length>120||reservedIds.length>500||!lines.length&&!reservedIds.length)throw Error('Choisissez vos livres ou une réservation.');
  const byId=new Map(catalog.map(b=>[b.number,b])),paid=[],parcelsMap=new Map();
  for(const line of lines){
   const b=byId.get(line.number),quantity=line.quantity??1;
   if(!b||!b.subscription_payable||!Number.isFinite(b.price)||b.price<=0||!Number.isInteger(quantity)||quantity<1||quantity>max||!Number.isInteger(line.parcel)||line.parcel<1||line.parcel>120||typeof line.month!=='string'||!/^\d{4}-(0[1-9]|1[0-2])$/.test(line.month))throw Error('Vérifiez les titres, quantités, colis et mois.');
   const earliest=b.available?month:(b.release_month>month?b.release_month:month);
   if(line.month<earliest)throw Error('Un envoi ne peut pas précéder le mois courant ou la parution prévue de '+b.title+'.');
   const parcel=parcelsMap.get(line.parcel)||{id:line.parcel,month:line.month,books:[],shipping:0};
   if(parcel.month!==line.month)throw Error('Tous les livres du colis '+line.parcel+' doivent avoir le même mois d’envoi.');
   for(let i=0;i<quantity;i++){parcel.books.push(b);paid.push(b);}if(parcel.books.length>3)throw Error('Un colis contient au maximum trois exemplaires.');parcelsMap.set(line.parcel,parcel);
  }
  if(paid.length&&(paid.length<min||paid.length>max))throw Error(`L’abonnement comprend de ${min} à ${max} exemplaires au total.`);
  if(new Set(reservedIds).size!==reservedIds.length)throw Error('Réservation en double.');
  const reserved=reservedIds.map(id=>{const b=byId.get(id);if(!b||b.subscription_payable)throw Error('Réservation invalide.');return b;});
  const parcels=[...parcelsMap.values()].sort((a,b)=>a.month.localeCompare(b.month)||a.id-b.id);for(const p of parcels)p.shipping=p.books.length===1?4.5:7;
  const books=paid.reduce((s,b)=>s+Math.round(b.price*100),0)/100,shipping=parcels.reduce((s,p)=>s+Math.round(p.shipping*100),0)/100;
  return {paid,reserved,parcels,books,shipping,total:books+shipping,shipments:parcels.length,requiresQuote:false};
 }
 function summary(q){
  const money=n=>new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR'}).format(n);const out=['Demande d’abonnement — sans paiement à ce stade',''];
  for(const p of q.parcels){out.push(`Colis ${p.id} — mois choisi : ${p.month} — port : ${money(p.shipping)}`);for(const b of p.books)out.push(`- N° ${b.number} : ${b.title} — ${money(b.price)}`);out.push('');}
  out.push(`Livres : ${money(q.books)}`,`Port : ${money(q.shipping)}`,`Total estimatif : ${money(q.total)}`);
  if(q.reserved.length){out.push('','Réservations sans paiement, exclues du total :');for(const b of q.reserved)out.push('- '+b.title);}
  out.push('','Carte personnalisée et dédicace d’Hervélina ou de Valérie.','Après vérification : facture valable 15 jours, paiement unique par virement. Aucun prélèvement ni reconduction. Le contrat est conclu à réception du paiement.');return out.join('\n');
 }
 const api={quote,summary,currentMonth};if(typeof module==='object'&&module.exports)module.exports=api;root.LPGRSubscriptionRules=api;
})(typeof globalThis!=='undefined'?globalThis:this);
