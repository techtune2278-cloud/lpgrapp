"""Mise en page des textes du brief, sans réécriture éditoriale."""
import json
from urllib.parse import urljoin
from image_assets import portraits, press_images
from content_features import excerpts, editorial_lists
from legal_pages import render_legal
from admin_page import admin_page
from bonus_audio import render_bonus
from subscription_content import subscription_page, TITLE, DESCRIPTION, H1, GUARANTEES, INCLUDED, NEXT, month_label
from site_features import book_order, buying_help, offer_order, contact_form, shipping_body, audio_body


def render_site(ctx):
    root, books, settings = ctx['ROOT'], ctx['books'], ctx['settings']
    t, esc, page, cards, cover = (ctx[k] for k in ['text', 'esc', 'page', 'cards', 'cover'])
    heading, link, book_title = (ctx[k] for k in ['heading', 'link', 'book_title'])
    is_collector = ctx['is_collector']
    shop, series, base = ctx['SUMUP'], ctx['SERIES'], ctx['SITE_URL']
    p = lambda number: '<p data-brief="'+str(number)+'">'+esc(t(number))+'</p>'
    para = lambda value: '<p>'+esc(value)+'</p>'
    h = lambda number: '<h2>'+esc(t(number).split('H2 : ', 1)[-1])+'</h2>'
    section = lambda number, body, cls='': '<section class="section copy-section '+cls+'" data-section="'+str(number)+'">'+h(number)+body+'</section>'
    quote = lambda: '<blockquote class="nothomb-quote" data-brief="59">« On n&#x27;est jamais trop petit pour découvrir les plus grands. »<br><cite>—&nbsp;Amélie Nothomb, écrivain</cite></blockquote>'
    collection_quote = '<section class="section copy-section">'+para("En découvrant notre collection, l’écrivain Amélie Nothomb a salué notre démarche avec ces mots :")+ '<blockquote class="nothomb-quote">'+esc("« On n’est jamais trop petit pour découvrir les plus grands. »")+'</blockquote></section>'
    event_cards, news_cards = editorial_lists(ctx)
    available = [b for b in books if b['available'] and not is_collector(b)]

    photo_alt = 'Hervélina Vyskoc et Valérie Lemoine, auteurs de la collection, au Festival du Livre de Paris'
    photo = '<div class="photo-placeholder" role="img" aria-label="'+photo_alt+'"><span aria-hidden="true">✳</span><p>Hervélina Vyskoc et Valérie Lemoine</p></div>'
    photo = portraits(root, esc) or photo
    presse = [
        {'key': 'pyrenees', 'name': 'La République des Pyrénées', 'date': '30 avril 2026', 'details': 'page 49, par Aurélie Dugast', 'url': 'https://www.larepubliquedespyrenees.fr/culture-et-loisirs/livres/montaut-hervelina-vyskoc-et-valerie-lemoine-racontent-les-grands-ecrivains-aux-enfants-28856816.php'},
        {'key': 'tregor', 'name': 'Le Trégor', 'date': '1er avril 2026', 'details': 'par Thierry Morisseau', 'url': 'https://actu.fr/bretagne/runan_22269/cotes-darmor-dans-leur-nouvelle-collection-ils-racontent-les-plus-grands-auteurs-francais-aux-plus-petits_64086485.html'},
        {'key': 'flaneur', 'name': 'Le Flâneur', 'date': '27 juin 2026', 'details': 'par Pascal Le Coz', 'url': 'https://www.flaneur-mag.com/2026/06/27/les-plus-grands-racontes-aux-plus-petits-les-grands-auteurs-a-decouvrir-en-livres-denfants/'},
    ]
    presse.append({'key':'ouest-france','name':'Ouest-France','date':'','details':'','url':'https://www.ouest-france.fr/bretagne/runan-22260/le-concept-de-valerie-lemoine-dans-les-cotes-darmor-la-litterature-a-hauteur-denfant-eddbc2d8-3ef5-11f1-b283-bbda7cee88c6'})
    def press_cards():
        result = []
        for article in presse:
            paths=press_images(root,article['key'])
            if paths:
                image='<a class="press-image-link" href="'+esc(paths[0])+'" target="_blank" rel="noopener"><img src="'+esc(paths[0])+'" alt="Coupure de '+esc(article['name'])+'" loading="lazy"><span>Agrandir la coupure ↗</span></a>'
                if len(paths)>1:
                    image+='<div class="press-pages">'+''.join('<a href="'+esc(url)+'" target="_blank" rel="noopener">Page '+str(i)+' ↗</a>' for i,url in enumerate(paths,1))+'</div>'
            else:
                image=''
            meta='<p>'+article['date']+('<br>' if article['date'] and article['details'] else '')+article['details']+'</p>' if article['date'] or article['details'] else ''
            result.append('<article class="press-article">'+image+'<h3>'+article['name']+'</h3>'+meta+'<a class="underlink" href="'+article['url']+'">Lire l’article ↗</a></article>')
        return '<div class="press-grid">'+''.join(result)+'</div>'

    # Accueil : les onze blocs sont conservés dans l’ordre du document.
    hero_visual = ''.join('<div class="hero-book hb'+str(i)+'">'+cover(books[n], True)+'</div>' for i, n in enumerate([j for j in [1,5,8] if j<len(books)]))
    home = '<section class="hero brief-hero"><div class="hero-copy"><h1>'+esc(t(55).removeprefix('H1 : '))+'</h1>'+para("Les plus Grands racontés aux plus petits, c'est une collection de livres illustrés pour faire découvrir aux enfants, dès 5 ans, les grands auteurs de la littérature française.")+'<div class="actions">'+link('Offrir un abonnement','/offrir/#abonnement')+link('Acheter',shop,'light')+'</div></div><div class="hero-visual"><div class="sunburst"></div>'+hero_visual+'</div></section>'
    home += collection_quote
    home += section(62,para("Chaque livre invite les jeunes lecteurs à rencontrer un écrivain, à découvrir sa vie, son époque et son univers, puis à lire un véritable extrait de son œuvre. Des jeux, des rubriques amusantes et des découvertes culturelles viennent enrichir cette rencontre.")+para("Au fil des pages, l'enfant apprend à connaître les écrivains, entre dans leur univers et découvre le plaisir des mots et des textes.")+para("Une approche vivante, ludique et accessible, qui respecte l'intelligence des enfants sans simplifier à l'excès les œuvres et les références."))

    home += section(65, '<ul class="brief-list">'+''.join('<li data-brief="'+str(n)+'">'+esc(t(n))+'</li>' for n in [66,67,68,69])+'</ul>')
    fabrication = t(71).split(' Lien : ',1)[0]
    home += section(70, '<figure class="craft-photo"><img src="/assets/photos/collection-couture-bibliotheque.jpeg" alt="Tranches colorées et couture rose des livres de la collection, entre deux livres anciens" width="546" height="1425" loading="lazy"></figure>'+para(fabrication)+link('Pourquoi ces livres valent leur prix','/fabrique-en-france/','text'))
    home += section(72, '<ul class="brief-list">'+''.join('<li data-brief="'+str(n)+'">'+esc(t(n))+'</li>' for n in [73,74,75])+'</ul>'+para("Les livres peuvent être découverts dès 5 ans avec un adulte. À partir de 8 ou 9 ans, selon son aisance en lecture, l'enfant peut aussi les lire seul.")+para("Mais nous encourageons surtout les parents et les grands-parents à partager ce moment avec lui : lire ensemble, commenter, échanger, s'étonner… Car les grands aussi pourraient bien apprendre quelques petites choses au fil des pages !"))
    home += section(77, '<div class="book-grid">'+cards(available)+'</div>'+para('À paraître : '+', '.join(b['title'] for b in books if 12<=b['number']<=17)+'. Le Collector n° 1 (tome 10), un livre de 32 pages avec jeux et exercices, est disponible à 16,50 €.'))
    audiences = [(92,'Parents','/livres/'),(93,'Grands-parents','/offrir/'),(94,'Écoles et bibliothèques','/professionnels/#bibliotheques'),(95,'Libraires, musées, salons, Alliances françaises','/professionnels/')]
    audience_cards = ''
    for num, label, url in audiences:
        value=t(num).split(' : « ',1)[-1].split(' »',1)[0]
        audience_cards += '<a class="audience-card" href="'+url+'"><h3>'+label+'</h3><p>'+esc(value)+'</p></a>'
    home += section(90, '<div class="audience-grid">'+audience_cards+'</div>')
    home += section(96, '<div class="authors-intro">'+photo+'<div>'+para(t(97).split(' Lien : ',1)[0])+link('Rencontrer les auteurs','/auteurs/','text')+'</div></div>')
    organization={'@context':'https://schema.org','@type':'Organization','name':'Sur le Chemin des Arts','url':base,'founder':[{'@type':'Person','name':n} for n in ['Hervélina Vyskoc','Valérie Lemoine']]}
    page('', t(53).split(' : ',1)[1], home, description=t(54).split(' : ',1)[1], og_description="On n'est jamais trop petit pour découvrir les plus grands.", structured=organization)

    # Collection et prévisions de parution, avec les trois numéros Collector.
    catalog = heading('La collection', 'Les plus grands racontés aux plus petits', t(63))+collection_quote
    catalog += '<figure class="subscription-fan"><img src="/assets/photos/collection-livres-eventail.jpeg" alt="Les dix livres parus de la collection disposés en éventail" width="1824" height="1373" loading="lazy"></figure>'
    catalog += '<section class="section catalog-section"><div class="filter-bar" role="group" aria-label="Filtrer les livres"><button class="filter active" data-filter="available" aria-pressed="true">Disponibles · '+str(sum(b['available'] for b in books))+'</button><button class="filter" data-filter="future" aria-pressed="false">À paraître · '+str(sum(not b['available'] for b in books))+'</button><button class="filter" data-filter="all" aria-pressed="false">Toute la collection · '+str(len(books))+'</button><label class="search-label">Chercher un auteur<input id="book-search" type="search" placeholder="Hugo, Colette…"></label></div><div class="book-grid catalog">'
    def filtered_cards(items):
        return ''.join('<div data-book data-status="'+('available' if b['available'] else 'future')+'" data-title="'+esc(b['title'])+'" '+('hidden' if not b['available'] else '')+'>'+cards([b])+'</div>' for b in items)
    collectors = sorted((b for b in books if is_collector(b)), key=lambda b: b['number'])
    catalog += filtered_cards(b for b in books if not is_collector(b))
    catalog += '</div><p id="empty-results" hidden>Aucun auteur ne correspond à votre recherche.</p></section>'
    catalog += '<section class="section copy-section"><h2>Les numéros Collector</h2>'+para("Après chaque série de neuf titres, un numéro Collector vient enrichir la collection. Avec ses 32 pages, il propose de nouveaux jeux et des rubriques interactives pour revenir sur la vie et l'œuvre des écrivains découverts dans les neuf livres précédents.")+para("Le Collector permet également d'approfondir certains thèmes abordés dans les livres, de faire appel à la mémoire des jeunes lecteurs et de prolonger leurs découvertes par de nouvelles activités.")+para("Il fait pleinement partie de la collection : une façon amusante de retrouver les auteurs déjà rencontrés et de poursuivre l'aventure littéraire.")+'<div class="book-grid collectors-grid">'+filtered_cards(collectors)+'</div></section>'
    page('livres','La collection de livres jeunesse dès 5 ans',catalog,active='La collection',structured={'@context':'https://schema.org','@type':'BookSeries','name':series,'inLanguage':'fr'})

    # Les auteurs : introduction et biographies intégrales à la première personne.
    intro=t(144).removeprefix('Introduction. ').split(' Photo des deux auteurs',1)[0]
    author_body=heading('Les auteurs',t(141).removeprefix('H1 : '),intro)
    author_body+='<section class="section">'+photo+'</section>'
    author_body+=section(145,p(146)).replace('<section ', '<section id="hervelina-vyskoc" ',1)+section(147,p(148)).replace('<section ', '<section id="valerie-lemoine" ',1)
    author_body+=section(149,para(t(150).split(' Lien vers ',1)[0])+link('Contact','/contact/','text')+' '+link('Professionnels','/professionnels/','text'))
    people={'@context':'https://schema.org','@graph':[{'@type':'Person','@id':base+'/auteurs/#hervelina-vyskoc','name':'Hervélina Vyskoc','jobTitle':['Comédienne','Écrivain','Professeur de théâtre'],'worksFor':{'@type':'Organization','name':'Sur le Chemin des Arts'}},{'@type':'Person','@id':base+'/auteurs/#valerie-lemoine','name':'Valérie Lemoine','jobTitle':'Enseignante','worksFor':{'@type':'Organization','name':'Sur le Chemin des Arts'}}]}
    page('auteurs',t(139).split(' : ',1)[1],author_body,description=t(140).split(' : ',1)[1],active='Les auteurs',structured=people)
    page('autrices','Les auteurs',heading('Les auteurs','Cette page a changé d’adresse.')+link('Rencontrer les auteurs','/auteurs/'),extra='<meta http-equiv="refresh" content="0;url=/auteurs/">')

    # Fiches : gabarit Victor Hugo du brief, adapté aux valeurs de chaque livre.
    deposit={1:'décembre 2025',2:'décembre 2025',3:'février 2026',4:'février 2026',5:'avril 2026',6:'avril 2026',7:'juin 2026',8:'juillet 2026',9:'juillet 2026',10:'octobre 2026',11:'août 2026'}
    for index,b in enumerate(books):
        if not b['has_page']:continue
        bt=book_title(b); available_now=b['available']; collector=is_collector(b)
        meta=f'Découvrez {b["title"]} avec les enfants dès 5 ans : sa vie, un extrait de son œuvre, des jeux. Livre carré 18×18, tome {b["number"]} de la collection. {b["pages"]} pages, {b["price"]} €.' if available_now else 'Les plus grands racontés aux plus petits · '+bt+' · À paraître.'
        if b['number']==2:meta=t(156).split(' : ',1)[1]
        price=str(b['price']).replace('.',',')+' €' if available_now else (str(b['price']).replace('.',',')+' € — À paraître')
        product='<section class="section product"><div><a class="backlink" href="/livres/">← La collection</a><div class="product-visual">'+cover(b,True)+'</div></div><div class="product-copy"><h1>'+esc(bt)+'</h1><p>Livre n° '+str(b['number'])+' de la collection '+series+' · dès 5 ans</p><div class="product-price">'+price+'</div>'
        product+=book_order(b,shop) if available_now else '<p>À paraître.</p>'+link('Me prévenir','/contact/?sujet=Parution%20-%20'+b['slug'],'text')
        product+= (buying_help() if available_now else '')+'<h2>Fiche pratique</h2><dl class="specs">'
        specs=[('Statut',{'paru':'Paru','prochain':'Prochain','plus_tard':'Plus tard'}[b['status']]),('Parution prévue',month_label(b['release_month']) if not b['available'] else 'À préciser'),('Collection',series),('Auteurs','Hervélina Vyskoc et Valérie Lemoine'),('Édition','Sur le chemin des arts'),('Numéro',b['number']),('Âge', 'Dès 5 ans'),('Format','18 × 18 cm'),('Pages',b['pages']),('Fabrication','Couture solide'),('Prix',price),('ISBN',b.get('isbn') or 'À renseigner'),('Dépôt légal BnF',deposit.get(b['number'],'À préciser'))]
        product+=''.join('<div><dt>'+label+'</dt><dd>'+esc(value)+'</dd></div>' for label,value in specs if value not in ('À renseigner','À préciser'))+'</dl><p class="muted">TVA non applicable, article 293 B du CGI</p><p>Hervélina Vyskoc et Valérie Lemoine<br>Sur le Chemin des Arts</p></div></section>'
        detail=b.get('description') or ('Livre de 32 pages avec jeux et exercices.' if collector else '')
        product+=excerpts(root,b)
        if b['number']==2: product+='<section class="section copy-section"><h2>Pour aller plus loin</h2><p>La Maison de Victor Hugo à Paris et Hauteville House à Guernesey [à vérifier et compléter].</p></section>'
        if b['number']==11:product+='<section class="section copy-section"><h2>Bonus</h2>'+link('Écouter le bonus de Molière','/bonus/moliere/')+'</section>'
        product+='<section class="section copy-section"><h2>Pourquoi 15 € ?</h2>'+''.join(p(n) for n in [471,472,473,474,475,476])+link('Fabriqué en France, avec soin','/fabrique-en-france/','text')+'</section>' if b['pages']==24 else '<section class="section copy-section"><h2>Fabriqué en France, avec soin</h2>'+p(471)+p(473)+link('Pourquoi ces livres valent leur prix','/fabrique-en-france/','text')+'</section>'
        product+='<section class="section"><h2>Les autres livres de la collection</h2><div class="book-grid">'+cards([books[i] for i in [index-1,index+1] if 0<=i<len(books)])+'</div>'+link('Pour les professionnels','/professionnels/','text')+'</section>'
        schema={'@context':'https://schema.org','@type':['Product','Book'],'name':bt,'author':[{'@type':'Person','name':n} for n in ['Hervélina Vyskoc','Valérie Lemoine']],'publisher':{'@type':'Organization','name':'Sur le Chemin des Arts'},'isPartOf':{'@type':'BookSeries','name':series},'numberOfPages':b['pages'],'inLanguage':'fr','typicalAgeRange':'5-'}
        if b.get('isbn'):schema['isbn']=b['isbn']
        if b.get('cover'):schema['image']=urljoin(base+'/',b['cover'])
        if available_now:schema['offers']={'@type':'Offer','price':f'{b["price"]:.2f}','priceCurrency':'EUR','availability':'https://schema.org/InStock','url':base+'/livres/'+b['slug']+'/'}
        page('livres/'+b['slug'],bt+' dès 5 ans | Livre jeunesse',product,description=meta,active='La collection',structured=schema)

    # Professionnels : une section et une ancre par public, sans condenser les conditions.
    prof=heading('Professionnels','Libraires, bibliothèques, musées, salons, écoles et Alliances françaises : travaillons ensemble',"Nous sommes une maison d'édition indépendante : vous parlez directement aux auteurs de la collection.")+quote()
    publics=[('libraires','Librairies'),('bibliotheques','Bibliothèques & médiathèques'),('ecoles','Alliances françaises et écoles'),('musees',"Musées & Maisons d’écrivains"),('salons','Rencontres et salons')]
    prof+='<nav class="public-nav" aria-label="Publics professionnels">'+''.join('<a href="#'+anchor+'">'+esc(label)+'</a>' for anchor,label in publics)+'</nav>'
    prof+='<section class="section copy-section" id="libraires"><h2>Librairies</h2>'+para("Dépôt-vente : Règlement trimestriel par virement (sur présentation de l'état des ventes), dépôt de 6 mois, reprise des invendus avec 10 jours de préavis.")+para('Commandes possibles via Dilicom (référencé via CyberScribe) ou en direct.')+para("N'hésitez pas à nous écrire pour recevoir le bon de commande complet et la liste de nos numéros d'ISBN.")+'</section>'
    prof+='<section class="section copy-section" id="bibliotheques"><h2>Bibliothèques & médiathèques</h2>'+para("Liste des titres avec numéros d'ISBN et prix public sur simple demande.")+para('Établissement de devis sur mesure (sur présentation de votre bon de commande).')+para('Facturation directe et paiement par virement bancaire ou chèque à réception.')+'</section>'
    prof+='<section class="section copy-section" id="ecoles"><h2>Alliances françaises et écoles</h2><h3>Une collection au service de la langue française</h3>'+para('Les ouvrages constituent un support pédagogique permettant :')+'<ul><li>de sensibiliser les enfants à la richesse de la langue française ;</li><li>de découvrir les grands auteurs qui ont façonné l’imaginaire collectif ;</li><li>de créer un premier lien avec les œuvres littéraires classiques ;</li></ul></section>'
    prof+='<section class="section copy-section" id="musees"><h2>Musées & Maisons d’écrivains</h2>'+para("Transmettre la littérature aux enfants, c'est aussi aller à la rencontre des grands auteurs là où ils ont vécu !")+para("Adaptés aux 5-10 ans, nos albums de la collection Les plus Grands racontés aux plus Petits allient rigueur historique et jeux ludiques. Ils offrent le prolongement idéal de la visite dans les boutiques de sites patrimoniaux et lieux de mémoire.")+para("Vous gérez la boutique d'un site culturel ou des animations jeunesse ? Contactez-nous pour recevoir un spécimen, établir un dépôt-vente ou concevoir une animation sur mesure.")+'<figure class="museum-photo"><img src="/assets/photos/musee-jules-verne-nantes.jpg" alt="Le livre Jules Verne dans la boutique du musée de Nantes" loading="lazy"><figcaption>Le livre Jules Verne dans la boutique du musée de Nantes.</figcaption></figure></section>'
    prof+='<section class="section copy-section" id="salons"><h2>Rencontres, dédicaces et présences sur les salons</h2>'+para("Parce que nos livres prennent tout leur sens au contact des lecteurs, nous adorons aller sur le terrain ! Présents sur de nombreux salons littéraires, marchés artisanaux et événements culturels, nous privilégions la proximité, la convivialité et l'échange direct avec le public.")+para("Vous organisez un salon jeunesse, un marché local, une fête du livre ou un événement en médiathèque ? Contactez-nous pour réserver notre venue ou planifier une intervention.")+link('Écrivez-nous','/contact/','text')+'</section>'
    prof+='<section class="section form-section"><h2>Formulaire de contact</h2><p>Un projet de rencontre ? Parlez-nous en</p>'+contact_form(professional=True)+'</section>'
    page('professionnels','Libraires, écoles, musées et Alliances françaises : livres jeunesse',prof,active='Professionnels')

    page('offrir',TITLE,subscription_page(ctx),description=DESCRIPTION,active='Abonnement cadeau')
    manufacture=heading('La fabrication','Fabriqué en France, avec soin')+'<figure class="section craft-photo"><img src="/assets/photos/collection-couture-bibliotheque.jpeg" alt="Les livres de la collection avec leurs tranches colorées et leur couture rose" width="546" height="1425" loading="lazy"></figure>'+'<section class="section copy-section"><h2>Pourquoi ces livres valent leur prix</h2>'+''.join(p(n) for n in [471,472,473,474,475,476])+'</section>'
    page('fabrique-en-france','Fabriqué en France, avec soin',manufacture)
    page('presse','Ils parlent de nous',heading('Presse','Ils parlent de nous')+'<section class="section copy-section">'+para(t(100).split(' Amélie Nothomb a découvert', 1)[0])+para("En découvrant notre collection, l’écrivain Amélie Nothomb a salué notre démarche avec ces mots :")+'<blockquote class="nothomb-quote quote-centered">« On n’est jamais trop petit pour découvrir les plus grands. »</blockquote>'+press_cards()+'</section>')

    # Autres parcours déjà livrés, en cohérence avec les termes du brief.
    form=contact_form()
    page('contact','Contact',heading('Contact','Une question, une invitation à un salon, une commande pour une librairie ou une école ?')+'<section class="section form-section">'+form+'</section>')
    page('livraison','Livraison et questions sur votre commande',heading('Commander les livres','Livraison et questions pratiques')+shipping_body(settings))
    page('faq','Questions fréquentes',heading('Questions fréquentes','Commander les livres')+shipping_body(settings))
    bookstores='<section class="section copy-section" id="librairies"><h2>Chez votre libraire</h2><div class="bookstore-grid">'
    for store in ctx['catalog'].get('stores',[]):
        bookstores+='<article class="bookstore"><h3>'+esc(store['name'])+'</h3><address>'+esc(store.get('address',''))+'<br>'+esc(store.get('postal_code','')+' '+store.get('city',''))+'</address><p><a href="tel:'+esc(store.get('phone','').replace(' ',''))+'">'+esc(store.get('phone',''))+'</a></p>'
        if store.get('url'):bookstores+='<a href="'+esc(store['url'])+'">Découvrir le point de vente ↗</a>'
        bookstores+='</article>'
    bookstores+='</div></section>'
    page('ou-nous-trouver','Où nous trouver',heading('Librairies et rencontres','Où nous trouver ?')+'<section class="section copy-section"><h2>Dans notre boutique en ligne</h2>'+link('Acheter les livres sur SumUp',shop)+'</section>'+bookstores+'<section class="section"><h2>Salons et dédicaces</h2><p>Retrouvez aussi nos marchés et rencontres.</p><div class="event-grid">'+event_cards+'</div>'+'<div class="empty-panel">'+link('Un projet de rencontre ? Parlez-nous en','/contact/','text')+'</div></section>',active='Où nous trouver ?')
    page('agenda','Où nous trouver',heading('Où nous trouver','Cette page a changé d’adresse.')+link('Où nous trouver','/ou-nous-trouver/'),extra='<meta http-equiv="refresh" content="0;url=/ou-nous-trouver/">')
    page('actualites','Blog et actualités',heading('La collection','Blog et actualités')+'<section class="section copy-section">'+(news_cards or '<p>Retrouvez les prochaines parutions dans la collection et les rencontres dans « Où nous trouver ».</p>')+'</section>')
    bonuses = ctx['catalog'].get('bonuses')
    if bonuses is None:
        bonuses = json.loads((root / 'bonus-default.json').read_text(encoding='utf-8'))
    bonus_cards = [render_bonus(bonus, root) for bonus in bonuses]
    page('bonus','Bonus et activités',heading('Bonus et activités','Les bonus de la collection')+'<section class="section bonus-list">'+(''.join(bonus_cards) or '<p>Aucun bonus disponible pour le moment.</p>')+'</section>',extra='<script src="/bonus-audio.js?v='+ctx['VERSION']+'" defer></script>')
    page('bonus/moliere','Molière : le bonus audio',heading('Tome 11','Lecture d’un texte sous forme d’interprétation théâtrale pour Molière')+audio_body(settings,root))
    render_legal(ctx)
    page('administration','Administration privée — Valérie Lemoine',admin_page(ctx))
    page('newsletter-confirmee','Lettre d’information',heading('Lettre d’information','Votre demande de confirmation')+'<section class="section copy-section"><p>Les inscriptions à la lettre d’information ne sont pas proposées sur ce site.</p></section>')
    page('atelier','Administration',heading('Administration','L’espace de gestion du site')+link('Ouvrir l’administration','/administration/'),extra='<meta http-equiv="refresh" content="0;url=/administration/">')
