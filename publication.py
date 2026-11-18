"""Métadonnées, graphe d’entités et publication/indexation des pages."""
import html
import json
import os
import re
from urllib.parse import urljoin,urlsplit
from media_pipeline import MediaPipeline

SERIES='Les plus grands racontés aux plus petits'
DESCRIPTIONS={
 'livres':'Découvrez la collection de livres jeunesse dès 5 ans : dix grands auteurs déjà racontés aux enfants, des extraits, des jeux et les titres à paraître.',
 'professionnels':'Libraires, bibliothèques, musées, écoles et Alliances françaises : découvrez la collection jeunesse dès 5 ans, les ISBN et demandez votre devis.',
 'offrir':"Offrez à un enfant dès 5 ans un abonnement à la collection : choisissez vos livres, groupez les envois. Carte et dédicace d'Hervélina ou Valérie.",
 'presse':'La presse présente Les plus grands racontés aux plus petits : articles de La République des Pyrénées, du Trégor, du Flâneur et de Ouest-France.',
 'fabrique-en-france':'Découvrez la fabrication en France des livres jeunesse : format 18 × 18 cm, petites séries, couture Singer, illustrations et soin apporté à chaque ouvrage.',
 'contact':'Contactez Sur le Chemin des Arts pour une question sur les livres, un abonnement, une commande professionnelle ou une invitation à un salon.',
 'ou-nous-trouver':'Retrouvez les rencontres et salons des auteurs de la collection Les plus grands racontés aux plus petits, et proposez un événement autour des livres.',
 'bonus':'Prolongez la découverte des grands auteurs : retrouvez les bonus de la collection jeunesse et la lecture théâtrale qui accompagne le livre Molière.',
 'bonus/moliere':'Écoutez le bonus du livre Molière : une interprétation théâtrale pour prolonger la découverte du théâtre avec les enfants dès 5 ans.',
 'faq':'Commande, livraison, frais de port, cadeaux et abonnements : les réponses aux questions sur les livres Les plus grands racontés aux plus petits.',
 'livraison':'Consultez les frais de livraison en France, en Europe et aux États-Unis, les conditions des envois groupés et les réponses aux questions de commande.',
 'mentions-legales':'Identité, coordonnées et informations légales de Sur le Chemin des Arts, éditeur de la collection Les plus grands racontés aux plus petits.',
 'cgv':'Consultez les conditions de commande et d’abonnement des livres de Sur le Chemin des Arts : paiement, livraison, rétractation et contact.',
 'confidentialite':'Découvrez comment Sur le Chemin des Arts utilise les données des formulaires de contact et de la lettre d’information, ainsi que vos droits.',
 'actualites':'Parutions et nouvelles de la collection Les plus grands racontés aux plus petits : suivez les livres jeunesse et les projets des auteurs.',
 'atelier':'Outil local de préparation des contenus du site Les plus grands racontés aux plus petits.',
 'newsletter-confirmee':'Confirmation de votre inscription à la lettre d’information de la collection Les plus grands racontés aux plus petits.',
 '404':'La page demandée est introuvable. Retrouvez les livres et les informations de la collection Les plus grands racontés aux plus petits.',
}


def public_copy(value):
    # Les crochets du cahier des charges contiennent des notes de préparation.
    return re.sub(r'\s*\[(?=[^\]]*[A-Za-zÀ-ÿ])[^\]]*\]','',value).strip()


def site_url(settings):
    value=os.environ.get('SITE_URL') or settings.get('site_url') or 'https://sitelpgrapp.vercel.app'
    parsed=urlsplit(value)
    if parsed.scheme!='https' or not parsed.hostname or parsed.username or parsed.query or parsed.fragment or parsed.path not in ('','/'):
        raise ValueError('SITE_URL doit être une origine HTTPS, par exemple https://lesplusgrandsracontes.fr')
    return value.rstrip('/')


class Publication:
    def __init__(self,root,settings,books,base):
        self.root=root;self.out=root/'dist';self.settings=settings;self.books=books;self.base=base
        self.media=MediaPipeline(root);self.media.icons();self.pages=[]
        self.book_by_route={'livres/'+b['slug']:b for b in books}
        self.graph=[
         {'@type':'Organization','@id':base+'/#organization','name':'Sur le Chemin des Arts','url':base+'/', 'logo':{'@type':'ImageObject','url':base+'/apple-touch-icon.png'},'address':{'@type':'PostalAddress','streetAddress':'22 Rue de Lassun','postalCode':'64800','addressLocality':'Montaut','addressCountry':'FR'},'email':'contact@lesplusgrandsracontes.fr','identifier':'SIRET 953 755 477 00015','sameAs':['https://www.lescompagnonsderoute.com/','https://www.instagram.com/lpgrapp/']},
         {'@type':'WebSite','@id':base+'/#website','url':base+'/','name':SERIES,'inLanguage':'fr-FR','publisher':{'@id':base+'/#organization'}},
         {'@type':'BookSeries','@id':base+'/#collection','name':SERIES,'inLanguage':'fr','publisher':{'@id':base+'/#organization'}},
         {'@type':'Person','@id':base+'/auteurs/#hervelina-vyskoc','name':'Hervélina Vyskoc','jobTitle':['Comédienne','Écrivain','Professeur de théâtre'],'worksFor':{'@id':base+'/#organization'}},
         {'@type':'Person','@id':base+'/auteurs/#valerie-lemoine','name':'Valérie Lemoine','jobTitle':'Enseignante','worksFor':{'@id':base+'/#organization'}},
        ]

    def description(self,route,provided,title):
        return public_copy(provided or DESCRIPTIONS.get(route,title+' — '+SERIES+'.'))

    def indexable(self,route):
        if self.settings.get('publication_mode','production')!='production' or os.environ.get('VERCEL_ENV')=='preview':return False
        if route in {'atelier','administration','404','autrices','agenda','newsletter-confirmee','faq'}:return False
        if route in self.settings.get('_unconfirmed_routes',[]):return False
        if route=='actualites' and not self.settings.get('_has_news'):return False
        return True

    def metadata(self,route,title,description,canonical,provided):
        book=self.book_by_route.get(route)
        cover=book.get('cover','') if book else ''
        share=self.media.share_image(route,title,cover)
        share_url=self.base+share
        graph=list(self.graph)
        current={'@type':'WebPage','@id':canonical+'#webpage','url':canonical,'name':title,'description':description,'inLanguage':'fr-FR','isPartOf':{'@id':self.base+'/#website'},'primaryImageOfPage':{'@type':'ImageObject','url':share_url,'width':1200,'height':630}}
        if book:current['mainEntity']={'@id':canonical+'#book'}
        graph.append(current)
        if provided:
            entities=provided.get('@graph',[provided])
            for entity in entities:
                item={k:v for k,v in entity.items() if k!='@context'}
                types=item.get('@type',[])
                if isinstance(types,str):types=[types]
                if any(t in types for t in ['Organization','Person','BookSeries']):continue
                if book:
                    item['@id']=canonical+'#book';item['url']=canonical
                    item['author']=[{'@id':self.base+'/auteurs/#hervelina-vyskoc'},{'@id':self.base+'/auteurs/#valerie-lemoine'}]
                    item['publisher']={'@id':self.base+'/#organization'};item['isPartOf']={'@id':self.base+'/#collection'}
                    if cover:
                        data=self.media.image(cover)
                        item['image']=self.base+data['sizes'][-1]['src'] if data else urljoin(self.base+'/',cover)
                    else:item.pop('image',None)
                    if isinstance(item.get('offers'),dict):
                        item['offers']['seller']={'@id':self.base+'/#organization'}
                graph.append(item)
        crumbs=[{'@type':'ListItem','position':1,'name':'Accueil','item':self.base+'/'}]
        if book:crumbs.append({'@type':'ListItem','position':2,'name':'La collection','item':self.base+'/livres/'})
        if route:crumbs.append({'@type':'ListItem','position':len(crumbs)+1,'name':title,'item':canonical})
        if len(crumbs)>1:graph.append({'@type':'BreadcrumbList','itemListElement':crumbs})
        self.pages.append({'route':route,'canonical':canonical,'title':title,'description':description,'index':self.indexable(route),'sharing':share,'book':bool(book)})
        esc=lambda s:html.escape(str(s),quote=True)
        head=f'''<meta property="og:image" content="{esc(share_url)}"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:image:alt" content="{esc(title)}"><meta property="og:locale" content="fr_FR"><meta property="og:site_name" content="{SERIES}"><meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="{esc(title)}"><meta name="twitter:description" content="{esc(description)}"><meta name="twitter:image" content="{esc(share_url)}"><link rel="icon" href="/favicon.svg" type="image/svg+xml"><link rel="alternate icon" href="/favicon.ico"><link rel="apple-touch-icon" href="/apple-touch-icon.png"><link rel="preload" href="/assets/fonts/Poppins-Regular.woff2" as="font" type="font/woff2" crossorigin>'''
        for key,name in [('google_site_verification','google-site-verification'),('bing_site_verification','msvalidate.01')]:
            if self.settings.get(key):head+=f'<meta name="{name}" content="{esc(self.settings[key])}">'
        return head,{'@context':'https://schema.org','@graph':graph}

    def finalize(self):
        urls=sorted({page['canonical'] for page in self.pages if page['index']})
        (self.out/'robots.txt').write_text('User-agent: *\nAllow: /\nDisallow: /api/\nSitemap: '+self.base+'/sitemap.xml\n',encoding='utf-8')
        sitemap='<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+''.join('<url><loc>'+html.escape(url)+'</loc></url>' for url in urls)+'</urlset>'
        (self.out/'sitemap.xml').write_text(sitemap,encoding='utf-8')
        (self.root/'seo-report.json').write_text(json.dumps({'site_url':self.base,'mode':self.settings.get('publication_mode'),'pages':self.pages,'warnings':self.media.warnings,'lighthouse':'À mesurer sur le déploiement public avec les images réelles.'},ensure_ascii=False,indent=2),encoding='utf-8')
