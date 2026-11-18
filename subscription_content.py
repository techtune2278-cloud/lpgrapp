"""Textes et sélection de l’abonnement libre, version du 21 octobre 2026."""
from datetime import date
import re

TITLE='Offrir un abonnement : livres pour enfants, grands auteurs'
DESCRIPTION="Offrez à un enfant dès 5 ans un abonnement à la collection : choisissez vos livres, groupez les envois. Carte et dédicace d'Hervélina ou Valérie."
H1='Offrir un abonnement à une collection de livres pour enfants'
INTRO="Offrez à un enfant, un petit-enfant ou un filleul les grands auteurs de la littérature française, un livre après l'autre. Vous choisissez les titres ; nous les envoyons au fil des parutions, avec une carte et une dédicace d'Hervélina ou de Valérie."
NEXT="Chaque titre annonce son mois de parution prévu. Un décalage d'un mois au plus est possible ; nous vous prévenons par e-mail. Si un titre a plus d'un mois de retard sur la date annoncée, vous pouvez l'annuler : nous vous remboursons son prix et son port. Votre livre part dans les 10 jours qui suivent sa parution. Le contenu sera en ligne à la parution : comme les dix premiers tomes, chaque livre contient la vie de l'auteur, un extrait, des rubriques culturelles et des activités."
LATER="Un titre plus lointain vous tente ? Réservez-le sans payer : nous vous écrivons quand sa date est confirmée, avec le lien de paiement. Vous pouvez renoncer à tout moment avant."
GROUP="Un envoi, c'est un colis. Plus il contient de livres, moins le port pèse. Mais pour les titres à paraître, grouper veut dire que le premier livre attend le suivant : votre premier livre partira à la parution du deuxième."
INCLUDED="Une carte et une dédicace d'Hervélina ou de Valérie. Les livres sont au prix habituel, le port est groupé selon le nombre de livres de chaque envoi."
GUARANTEES=['Un seul paiement par virement après réception de la facture, sans prélèvement récurrent.','Envoi en lettre suivie.','Droit de rétractation de 14 jours à compter de la réception du dernier livre.',"Remboursement d'un titre qui aurait plus d'un mois de retard."]


def prepare_catalog(books):
    for book in books:
        status='paru' if book['available'] else ('prochain' if book.get('release_month') else 'plus_tard')
        if status not in {'paru','prochain','plus_tard'}:raise ValueError('Statut de livre invalide : '+str(status))
        if status=='paru' and not book['available']:raise ValueError('Un livre paru doit avoir available=true.')
        month=book.get('release_month','')
        if month:
            if not re.fullmatch(r'\d{4}-\d{2}',month):raise ValueError('release_month attend AAAA-MM.')
            date.fromisoformat(month+'-01')
        book.update(status=status,release_month=month,has_page=bool(book['available'] or book.get('cover') or book.get('description','').strip()))
        book['subscription_payable']=bool(status=='paru' or (status=='prochain' and month))



def month_label(value):
    if not value:return 'Mois de parution à confirmer'
    names=['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre']
    return names[int(value[5:])-1]+' '+value[:4]


def subscription_page(ctx):
    esc=ctx['esc'];heading=ctx['heading'];books=ctx['books'];settings=ctx['catalog'].get('subscription',{'min_books':3,'max_books':12})
    body='<section class="section gift-hero" id="abonnement"><div>'+heading('Offrir',H1)+'<p>'+esc(INTRO)+'</p></div><img src="/assets/photos/enfant-lecture-fauteuil.png" alt="Une petite fille lit un livre de la collection dans un fauteuil" width="806" height="1069" loading="eager"></section>'
    body+='<section class="section copy-section"><h2>Comment ça marche</h2><ol class="brief-list"><li>Choisissez de '+str(settings['min_books'])+' à '+str(settings['max_books'])+' exemplaires. Plusieurs exemplaires du même titre sont possibles.</li><li>Choisissez le mois de chaque ouvrage et répartissez-les en colis de 1 à 3 livres. Un ouvrage ne peut pas partir avant sa parution prévue.</li><li>Indiquez les coordonnées et le prénom du destinataire, puis votre mot pour la carte.</li><li>Envoyez votre demande sans paiement. Nous vérifions les informations et adressons une facture valable 15 jours. Le paiement se fait en une fois par virement ; le contrat est conclu à réception du paiement.</li></ol></section>'
    body+='<section class="section copy-section subscription"><form id="subscription-builder" action="/api/subscription" method="post"><h2 id="choisir-livres">Choisir vos livres</h2>'
    for available,label in [(True,'Livres déjà parus'),(False,'Titres à paraître et Collectors')]:
        body+='<fieldset><legend>'+label+'</legend><div class="subscription-book-list">'
        for book in books:
            if book['available']!=available:continue
            reserve=not book['subscription_payable'];detail='Disponible' if available else month_label(book['release_month']);name='reserve-title' if reserve else 'subscription-title'
            body+='<div class="subscription-book"><label><input type="checkbox" name="'+name+'" value="'+str(book['number'])+'"><span><strong>'+esc(book['title'])+'</strong><small>'+esc(detail)+' · '+str(book['price']).replace('.',',')+' €</small><span>'+('Réserver sans paiement' if reserve else 'Choisir')+'</span></span></label>'
            if not reserve:body+='<label>Exemplaires<input type="number" min="1" max="'+str(settings['max_books'])+'" value="1" data-quantity="'+str(book['number'])+'"></label>'
            if book['has_page']:body+='<a href="/livres/'+book['slug']+'/" target="_blank" rel="noopener noreferrer">Voir le livre ↗</a>'
            body+='</div>'
        body+='</div></fieldset>'
    body+='<h2>Mois et composition des colis</h2><p>Choisissez le mois d’envoi de chaque exemplaire. Pour grouper des livres, donnez-leur le même numéro de colis et le même mois. Un colis contient au maximum 3 exemplaires. Les livres parus peuvent être livrés au mois de votre choix ; les achats à l’unité restent disponibles immédiatement dans la boutique.</p><button class="button light" type="button" id="auto-parcels">Répartir automatiquement par mois</button><div id="subscription-schedule"></div><p>Port France métropolitaine, par colis : 1 livre, 4,50 € ; 2 ou 3 livres, 7 €. Autres destinations sur devis.</p><div id="subscription-summary" class="subscription-summary" role="status" aria-live="polite"></div><div id="subscription-parcels"></div><p id="reservation-summary"></p><h2>Ce qui est inclus</h2><p>'+esc(INCLUDED)+'</p><h2>Délais et garanties</h2><p>Livres disponibles : expédition après paiement, au mois choisi ; pour un départ immédiat, sous cinq jours ouvrés. Titres à paraître : dans les dix jours suivant la parution du dernier titre du colis, ou au mois ultérieur choisi. En cas de retard de plus d’un mois, vous pouvez maintenir, remplacer ou annuler le titre selon les CGV.</p><ul>'+''.join('<li>'+esc(x)+'</li>' for x in GUARANTEES)+'</ul>'
    body+='''<fieldset><legend>Vos coordonnées</legend><div class="contact-form"><label>Votre nom<input name="nom" required maxlength="120" autocomplete="name"></label><label>Votre e-mail<input name="email" type="email" required maxlength="254" autocomplete="email"></label><label>Téléphone (facultatif)<input name="phone" type="tel" maxlength="40"></label><label>Adresse de facturation<input name="billing_address" maxlength="500" autocomplete="billing street-address" required></label></div></fieldset><fieldset id="recipient-fields"><legend>Le destinataire</legend><div class="contact-form"><label>Prénom et nom<input name="recipient_name" required maxlength="120" autocomplete="shipping name"></label><label>Adresse<input name="address" required maxlength="200" autocomplete="shipping address-line1"></label><label>Complément<input name="address_extra" maxlength="200"></label><label>Code postal<input name="postal_code" required maxlength="5" pattern="[0-9]{5}" autocomplete="shipping postal-code"></label><label>Ville<input name="city" required maxlength="120" autocomplete="shipping address-level2"></label><label>Pays<input name="country" value="France" readonly></label></div><label>Mot pour la carte<textarea name="card_message" maxlength="1000" rows="4"></textarea></label></fieldset><div class="contact-trap" aria-hidden="true"><input name="website" tabindex="-1" autocomplete="off" aria-label="Ne pas remplir"></div><label class="contact-consent"><input name="terms" type="checkbox" required> J’ai lu et j’accepte les <a href="/cgv/" target="_blank" rel="noopener noreferrer">CGV</a>.</label><label class="contact-consent"><input name="acknowledge" type="checkbox" required> Je comprends que cette demande n’entraîne aucun paiement et qu’une facture me sera adressée après vérification.</label><p>Vos données servent à traiter votre demande. <a href="/confidentialite/" target="_blank" rel="noopener noreferrer">Politique de confidentialité</a>.</p><label class="contact-consent"><input name="newsletter" type="checkbox"> Je souhaite recevoir la lettre d’information (facultatif).</label><p id="subscription-availability" role="status"></p><button id="subscription-submit" class="button primary" type="submit" disabled>Envoyer ma demande</button><p id="subscription-result" role="status" aria-live="polite" tabindex="-1"></p><button id="subscription-email" class="button light" type="button">Préparer un e-mail</button><button id="subscription-download" class="button light" type="button">Télécharger le récapitulatif</button><p>Pas de paiement sur cette page. Votre demande sera vérifiée avant l’établissement de la facture et le règlement par virement.</p><noscript><p>Contactez <a href="mailto:contact@lesplusgrandsracontes.fr">contact@lesplusgrandsracontes.fr</a> pour composer votre abonnement.</p></noscript></form></section>'''
    return body
