"""Contenus facultatifs : seules les données réellement renseignées sont publiées."""
import html
import re
from datetime import date,datetime
from urllib.parse import urlsplit
from image_assets import find_images


def excerpts(root,book):
    images=book.get('excerpts') or find_images(root,'extraits/'+book['slug'], '',contains=True)
    if not images:return ''
    esc=lambda s:html.escape(str(s),quote=True)
    return '<section class="section"><h2>Feuilleter</h2><div class="excerpt-grid">'+''.join('<a href="'+esc(src)+'" target="_blank" rel="noopener noreferrer"><img src="'+esc(src)+'" alt="Extrait '+str(i)+' du livre '+esc(book['title'])+'" loading="lazy"><span>Agrandir l’extrait '+str(i)+' ↗</span></a>' for i,src in enumerate(images,1))+'</div></section>'


def valid_slug(value):
    return isinstance(value,str) and re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*',value)


def editorial_lists(ctx):
    import json
    catalog=json.loads((ctx['ROOT']/'content.json').read_text(encoding='utf-8-sig'))
    page,esc,heading=ctx['page'],ctx['esc'],ctx['heading'];base=ctx['SITE_URL']
    events=[];news=[]
    for entry in catalog.get('events',[]):
        # Une date et un lieu sont indispensables pour annoncer un événement.
        if not all(entry.get(k) for k in ['slug','title','start_date','city']):continue
        if not valid_slug(entry['slug']):raise ValueError('Slug de rencontre invalide')
        start=entry['start_date'];parsed=datetime.fromisoformat(start) if 'T' in start else date.fromisoformat(start)
        route='rencontres/'+entry['slug'];url=base+'/'+route+'/'
        if not entry.get('confirmed',True):ctx['settings'].setdefault('_unconfirmed_routes',[]).append(route)
        place={'@type':'Place','name':entry.get('place') or entry['city'],'address':{'@type':'PostalAddress','addressLocality':entry['city'],'addressCountry':entry.get('country','FR')}}
        for field,schema_field in [('street','streetAddress'),('postal_code','postalCode')]:
            if entry.get(field):place['address'][schema_field]=entry[field]
        schema={'@context':'https://schema.org','@type':'Event','name':entry['title'],'startDate':start,'location':place,'url':url,'eventStatus':'https://schema.org/EventScheduled','eventAttendanceMode':'https://schema.org/OfflineEventAttendanceMode','organizer':{'@id':base+'/#organization'}}
        if entry.get('end_date'):
            datetime.fromisoformat(entry['end_date']);schema['endDate']=entry['end_date']
        body=heading('Rencontres',entry['title'])+'<section class="section copy-section"><p><time datetime="'+esc(start)+'">'+parsed.strftime('%d/%m/%Y')+'</time> · '+esc(entry.get('place') or 'Lieu précis à confirmer')+', '+esc(entry['city'])+'</p>'
        if entry.get('description'):body+='<p>'+esc(entry['description'])+'</p>';schema['description']=entry['description']
        if entry.get('image'):
            body+='<img src="'+esc(entry['image'])+'" alt="'+esc(entry['title'])+'" loading="lazy">';schema['image']=base+entry['image'] if entry['image'].startswith('/') else entry['image']
        body+='</section>'
        page(route,entry['title']+' | Rencontres',body,description=entry['title']+' — '+parsed.strftime('%d/%m/%Y')+'. '+entry.get('description',''),structured=(schema if entry.get('confirmed',True) and entry.get('place') else None),active='Où nous trouver')
        events.append('<article class="empty-panel"><h2><a href="/'+route+'/">'+esc(entry['title'])+'</a></h2><p>'+parsed.strftime('%d/%m/%Y')+' · '+esc(entry['city'])+('</p>' if entry.get('confirmed',True) else ' · À confirmer</p>')+'</article>')
    for entry in catalog.get('news',[]):
        if not all(entry.get(k) for k in ['slug','title','date','text']):continue
        if not valid_slug(entry['slug']):raise ValueError('Slug d’actualité invalide')
        date.fromisoformat(entry['date']);route='actualites/'+entry['slug']
        body=heading('Actualités',entry['title'])+'<section class="section copy-section"><p><time datetime="'+esc(entry['date'])+'">'+esc(entry['date'])+'</time></p>'+''.join('<p>'+esc(p)+'</p>' for p in entry['text'].split('\n\n'))+'</section>'
        page(route,entry['title']+' | Actualités',body,description=entry.get('description',entry['text'].split('\n')[0][:170]))
        news.append('<article><h2><a href="/'+route+'/">'+esc(entry['title'])+'</a></h2><p>'+esc(entry.get('description',''))+('</p>' if entry.get('confirmed',True) else ' · À confirmer</p>')+'</article>')
    ctx['settings']['_has_news']=bool(news)
    return ''.join(events),''.join(news)
