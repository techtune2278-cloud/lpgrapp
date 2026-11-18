const menu=document.querySelector('.menu-toggle');
menu?.addEventListener('click',()=>{const open=menu.getAttribute('aria-expanded')!=='true';menu.setAttribute('aria-expanded',String(open));document.querySelector('#nav').classList.toggle('open',open)});
const fold=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
let filter='available';
function filterBooks(){const query=fold(document.querySelector('#book-search')?.value||'');let count=0;document.querySelectorAll('[data-book]').forEach(el=>{el.hidden=!(filter==='all'||el.dataset.status===filter)||!fold(el.dataset.title).includes(query);if(!el.hidden)count++});const empty=document.querySelector('#empty-results');if(empty)empty.hidden=count>0;}
document.querySelectorAll('[data-filter]').forEach(button=>button.addEventListener('click',()=>{filter=button.dataset.filter;document.querySelectorAll('[data-filter]').forEach(b=>{b.classList.toggle('active',b===button);b.setAttribute('aria-pressed',String(b===button))});filterBooks()}));
document.querySelector('#book-search')?.addEventListener('input',filterBooks);
const form=document.querySelector('#contact-form');
if(form){
  const subject=new URLSearchParams(location.search).get('sujet');
  if(subject)form.elements.sujet.value=subject.slice(0,160);
  if(subject==='abonnement-personnalise'){try{const saved=JSON.parse(sessionStorage.getItem('lpgr-subscription-request')||'null');if(saved&&typeof saved.subject==='string'&&typeof saved.message==='string'){form.elements.sujet.value=saved.subject.slice(0,160);form.elements.message.value=saved.message.slice(0,5000);sessionStorage.removeItem('lpgr-subscription-request')}}catch{}}
  let startedAt=Date.now();let enabled=false;let sending=false;
  const sendButton=document.querySelector('#send-message');
  const result=document.querySelector('#message-result');
  const availability=document.querySelector('#contact-availability');
  async function checkContact(){
    try{
      const response=await fetch('/api/contact',{headers:{Accept:'application/json'},cache:'no-store',signal:AbortSignal.timeout(10000)});
      if(!response.ok)throw new Error();
      enabled=(await response.json()).enabled===true;
    }catch{enabled=false;}
    sendButton.disabled=!enabled;
    availability.textContent=enabled?'Votre demande sera envoyée aux auteurs. Votre adresse permet de vous répondre ; elle ne vous inscrit pas à une newsletter.':'L’envoi n’est pas encore disponible sur ce site. Vous pouvez préparer et conserver votre message avec le bouton « Conserver un brouillon ».';
  }
  checkContact();
  document.querySelector('#save-draft').addEventListener('click',()=>{
    const data=new FormData(form);
    const text=`${data.get('nom')} — ${data.get('profil')}\n${data.get('email')}\n\n${data.get('sujet')}\n\n${data.get('message')}`;
    const url=URL.createObjectURL(new Blob([text],{type:'text/plain;charset=utf-8'}));
    const a=document.createElement('a');a.href=url;a.download='demande-collection.txt';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  });
  form.addEventListener('submit',async event=>{
    event.preventDefault();if(sending)return;
    if(!enabled){result.textContent='L’envoi est indisponible. Vous pouvez conserver un brouillon.';return;}
    if(!form.reportValidity())return;
    const data=new FormData(form);const body=Object.fromEntries(data);body.consent=data.get('consent')==='on';body.devis=data.get('devis')==='on';body.startedAt=startedAt;
    sending=true;sendButton.disabled=true;sendButton.textContent='Envoi en cours…';form.setAttribute('aria-busy','true');result.textContent='';
    try{
      const response=await fetch('/api/contact',{method:'POST',headers:{'Content-Type':'application/json',Accept:'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
      let answer;try{answer=await response.json()}catch{throw new Error('L’envoi n’a pas pu être confirmé. Votre texte est conservé.');}
      if(!response.ok||answer.ok!==true)throw new Error(answer.error||'Votre message n’a pas été envoyé. Réessayez plus tard.');
      result.textContent=answer.message;form.reset();startedAt=Date.now();
    }catch(error){result.textContent=error.name==='TimeoutError'?'L’envoi n’a pas pu être confirmé à temps. Votre texte est conservé.':(error.message||'L’envoi a échoué. Votre texte est conservé.');}
    finally{sending=false;sendButton.disabled=!enabled;sendButton.textContent='Envoyer mon message ↗';form.removeAttribute('aria-busy');result.focus();}
  });
}
const moliereAudio=document.querySelector('#moliere-audio');
if(moliereAudio){
  document.querySelector('#audio-back')?.addEventListener('click',()=>{moliereAudio.currentTime=Math.max(0,moliereAudio.currentTime-10)});
  document.querySelector('#audio-speed')?.addEventListener('change',event=>{moliereAudio.playbackRate=Number(event.target.value)});
  moliereAudio.addEventListener('error',()=>{document.querySelector('#audio-status').textContent='Le fichier ne peut pas être lu pour le moment. Essayez le lien direct ci-dessous.'});
}
const editor=document.querySelector('#editor');
if(editor){(async()=>{const storageKey='lpgr-content-v01';let content;try{content=JSON.parse(localStorage.getItem(storageKey)||'null')}catch{}if(!content)content=await(await fetch('/content.json')).json();for(const book of content.books){for(const key of ['title','description']){if(typeof book[key]==='string')book[key]=book[key].replace(/\bautrices\b/gi,word=>word[0]==='A'?'Auteurs':'auteurs')}}const select=document.querySelector('#editor-book');const desc=document.querySelector('#editor-description');const cover=document.querySelector('#editor-cover');const status=document.querySelector('#editor-status');const preview=document.querySelector('#editor-preview');const populate=()=>{select.replaceChildren();for(const b of content.books){const option=document.createElement('option');option.value=b.number;option.textContent=`${b.number}. ${b.title}`;select.append(option)}};const current=()=>content.books.find(b=>b.number===Number(select.value));function render(){const b=current();if(!b)return;preview.replaceChildren();if(b.cover){const img=document.createElement('img');img.src=b.cover;img.alt=`Aperçu de la couverture de ${b.title}`;preview.append(img)}else{const placeholder=document.createElement('p');placeholder.textContent='Couverture à ajouter';placeholder.className='empty-panel';preview.append(placeholder)}const h=document.createElement('h2');h.textContent=b.title;const p=document.createElement('p');p.textContent=b.description||'Description à ajouter';preview.append(h,p)}function load(){desc.value=current().description||'';cover.value=current().cover?.startsWith('http')?current().cover:'';document.querySelector('#editor-file').value='';status.textContent='';render()}function saveLocal(){try{localStorage.setItem(storageKey,JSON.stringify(content));status.textContent='Contenus enregistrés dans ce navigateur. Pensez à les exporter.'}catch{status.textContent='Stockage du navigateur insuffisant. Exportez les contenus pour les conserver.'}}populate();load();select.addEventListener('change',load);editor.addEventListener('submit',event=>{event.preventDefault();current().description=desc.value;if(cover.value)current().cover=cover.value;saveLocal();render()});document.querySelector('#editor-file').addEventListener('change',event=>{const file=event.target.files[0];if(!file)return;if(file.size>4*1024*1024){status.textContent='Choisissez une image de moins de 4 Mo.';return}if(!['image/png','image/jpeg','image/webp'].includes(file.type)){status.textContent='Formats acceptés : PNG, JPEG et WebP.';return}const target=current();const reader=new FileReader();reader.onload=()=>{target.cover=reader.result;saveLocal();render()};reader.readAsDataURL(file)});document.querySelector('#export-content').addEventListener('click',()=>{current().description=desc.value;if(cover.value)current().cover=cover.value;const url=URL.createObjectURL(new Blob([JSON.stringify(content,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='content.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)});document.querySelector('#import-content').addEventListener('change',async event=>{try{const incoming=JSON.parse(await event.target.files[0].text());if(!Array.isArray(incoming.books)||incoming.books.length!==33||incoming.books.some(b=>typeof b.title!=='string'||typeof b.slug!=='string'||!Number.isInteger(b.number)||typeof b.color!=='string'||(b.cover&&!/^(https?:\/\/|data:image\/(png|jpeg|webp);base64,|\/assets\/)/i.test(b.cover))))throw Error('Format de catalogue incorrect');content=incoming;populate();load();saveLocal();document.querySelector('#import-status').textContent='Fichier importé dans cet atelier local.'}catch{document.querySelector('#import-status').textContent='Import impossible : choisissez un fichier de contenu valide.'}})})().catch(()=>{document.querySelector('#editor-status').textContent='Le catalogue n’a pas pu être chargé. Réessayez en rechargeant la page.'})}
