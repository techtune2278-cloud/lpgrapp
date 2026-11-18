"""Blocs de la priorité 1 : commandes, formulaire, livraison et audio."""
from html import escape
from urllib.parse import urlsplit, quote


def safe_url(value):
    if not isinstance(value, str):
        return ''
    parsed = urlsplit(value.strip())
    if parsed.scheme == 'https' and parsed.hostname:
        return value.strip()
    return ''


def order_button(label, url, kind='primary'):
    return f'<a class="button {kind}" href="{escape(url, quote=True)}">{escape(label)} <span aria-hidden="true">↗</span></a>'


def book_order(book, shop_url):
    direct = safe_url(book.get('commande_url'))
    url = direct or safe_url(shop_url)
    return order_button('Commander ce livre' if direct else 'Voir la boutique', url)


def offer_order(key, settings, label='Commander cette formule', subject=''):
    direct = safe_url(settings.get('offer_urls', {}).get(key))
    if direct:
        return order_button(label, direct, 'text')
    return order_button('Demander cette formule', '/contact/?sujet=' + quote(subject or key), 'text')


def buying_help():
    return '<p class="buying-help">Paiement dans SumUp · Plusieurs titres dans un même panier.<br><a href="/livraison/#tarifs">Frais de port</a> · <a href="/livraison/#questions">Questions sur la commande</a></p>'


def contact_form(professional=False):
    profiles = ['Un particulier', 'Une librairie', 'Une bibliothèque ou médiathèque', 'Un musée ou une maison d’écrivain', 'Une école ou Alliance française', 'Un organisateur de salon', 'Un journaliste', 'Autre']
    if professional:
        profiles = ['Librairie', 'Bibliothèque ou médiathèque', 'Musée ou maison d’écrivain', 'Alliance française', 'École', 'Salon ou marché', 'Presse', 'Autre']
    city = '<label>Ville<input name="ville" maxlength="160" autocomplete="address-level2"></label>' if professional else ''
    subject = '<input name="sujet" type="hidden" value="Demande professionnelle">' if professional else '<label>Sujet<input name="sujet" required maxlength="160"></label>'
    quote = '<label class="full contact-consent"><input name="devis" type="checkbox"> <span>Je souhaite un devis</span></label>' if professional else ''
    options = ''.join(f'<option>{escape(p)}</option>' for p in profiles)
    return f'''<form id="contact-form" class="contact-form" action="/api/contact" method="post">
<label>Vous êtes<select name="profil">{options}</select></label>
<label>Nom / structure<input name="nom" required maxlength="120" autocomplete="name"></label>{city}
<label>Votre e-mail<input name="email" type="email" required maxlength="254" autocomplete="email"></label>
{subject}
<label class="full">Votre message<textarea name="message" rows="6" minlength="10" maxlength="5000" required></textarea></label>
{quote}<div class="contact-trap" aria-hidden="true"><label>Ne pas remplir ce champ<input name="website" tabindex="-1" autocomplete="off"></label></div>
<label class="full contact-consent"><input name="consent" type="checkbox" required> <span>J’accepte que les informations saisies soient utilisées pour répondre à ma demande. <a href="/confidentialite/">Confidentialité</a>.</span></label>
<p class="full muted" id="contact-availability" role="status">Vérification de la disponibilité du formulaire…</p>
<button class="button primary" type="submit" id="send-message" disabled>Envoyer mon message ↗</button>
<button class="button light" type="button" id="save-draft">Conserver un brouillon ↓</button>
<div id="message-result" class="full" role="status" aria-live="polite" tabindex="-1"></div>
<noscript><p class="notice full">Activez JavaScript pour utiliser le formulaire.</p></noscript>
</form>'''


def shipping_body(settings):
    rows = ''.join('<tr>' + ''.join(f'<td>{escape(row[k])}</td>' for k in ['quantity', 'france', 'europe', 'us']) + '</tr>' for row in settings['shipping'])
    questions = [
        ('Comment commander plusieurs titres ?', 'Choisissez un premier livre dans notre catalogue, puis ouvrez sa fiche SumUp. Ajoutez-le au panier et poursuivez vos achats dans la même boutique. Vous réglez l’ensemble en une seule commande.'),
        ('Quand ma commande arrive-t-elle ?', 'L’envoi est prévu en lettre suivie. Le délai indicatif annoncé est de 2 à 3 jours ; le point de départ de ce délai et les conditions selon la destination restent à préciser. Si une date est importante, contactez-nous avant de commander. Aucune réception à une date précise n’est garantie ici.'),
        ('Comment suivre mon envoi ?', 'La livraison est prévue avec suivi. Si vous ne disposez pas du numéro ou si vous rencontrez un problème, contactez-nous avec votre référence de commande SumUp.'),
        ('Puis-je commander depuis l’étranger ?', 'La grille présente les tarifs prévus pour la France, l’Europe et les États-Unis. Pour confirmer votre destination ou un autre pays, demandez un devis. Vérifiez la destination et le montant final dans SumUp avant paiement.'),
        ('Comment fonctionnent les offres cadeaux ?', 'Les achats à l’unité sont réalisés dans SumUp. Pour offrir un abonnement, composez votre sélection sur la page Offrir : la demande est vérifiée, puis une facture est envoyée pour règlement par virement. Aucun paiement n’est demandé sur le formulaire.'),
        ('Une dédicace ou un emballage cadeau sont-ils possibles ?', 'Pour l’abonnement cadeau, une carte et la dédicace d’un des auteurs sont prévues. Pour les autres commandes et pour l’emballage cadeau, contactez-nous pour confirmer les possibilités avant le paiement.'),
        ('Comment fonctionne l’abonnement ?', 'Composez un abonnement de 3 à 12 exemplaires : plusieurs exemplaires du même titre sont possibles, y compris les Collectors à 16,50 €. Choisissez le mois de chaque ouvrage et les colis de 1 à 3 livres, sans date antérieure à la parution annoncée. Port France métropolitaine par colis : 4,50 € pour 1 livre, 7 € pour 2 ou 3. Nous vérifions votre demande et adressons une facture valable 15 jours. Le règlement s’effectue en une fois par virement, sans prélèvement ni reconduction. Une carte et une dédicace d’Hervélina ou de Valérie sont comprises.'),
        ('Et pour plus de douze livres ou une commande professionnelle ?', 'Contactez-nous pour un devis adapté. Librairies, bibliothèques, écoles et musées peuvent utiliser le formulaire de l’espace professionnels.'),
        ('Ma commande a un problème ou je souhaite un retour : que faire ?', 'Contactez-nous avec votre référence de commande et la description du problème. Les conditions applicables sont celles consultables dans la boutique au moment de l’achat. Cette FAQ ne remplace pas les conditions générales de vente.'),
    ]
    faq = ''.join(f'<details><summary>{escape(q)}</summary><p>{escape(a)}</p></details>' for q, a in questions)
    return f'''<section class="section shipping-section" id="tarifs"><h2>Les frais de livraison</h2><p>Grille prévue pour les livres de la collection. Le montant et la destination doivent être confirmés dans SumUp avant paiement.</p><div class="table-scroll" tabindex="0" role="region" aria-label="Tarifs de livraison"><table class="shipping-table"><thead><tr><th scope="col">Quantité</th><th scope="col">France — Lettre suivie</th><th scope="col">Europe</th><th scope="col">États-Unis</th></tr></thead><tbody>{rows}</tbody></table></div><p class="muted">Au-delà de 12 livres : sur devis. Le port des abonnements est calculé par colis selon cette grille.</p><a class="underlink" href="/contact/?sujet=Livraison">Une question sur votre livraison ? →</a></section><section class="section faq-section" id="questions"><p class="eyebrow">Avant de commander</p><h2>Vos questions, simplement.</h2><div class="faq-list">{faq}</div></section>'''


def audio_body(settings, root):
    url = safe_url(settings.get('moliere_audio_url'))
    local_file = root / 'dist/assets/audio/moliere.mp3'
    if not url and local_file.is_file() and local_file.stat().st_size > 0:
        url = '/assets/audio/moliere.mp3'
    if not url and safe_url(settings.get('bonus_page_url')):
        external = escape(settings['bonus_page_url'], quote=True)
        return '<section class="section"><div class="audio-panel"><h2>Écouter le bonus de Molière</h2><p>Le bonus est accessible sur le site Les Compagnons de Route.</p><a class="button primary" href="'+external+'">Accéder au bonus ↗</a></div></section>'
    if not url:
        return '''<section class="section"><div class="audio-panel"><span class="sound-icon" aria-hidden="true">♫</span><h2>L’enregistrement sera bientôt disponible</h2><p>Cette page accueillera la lecture théâtrale qui accompagne le tome 11. Revenez ici pour l’écouter.</p><a class="underlink" href="/livres/moliere/">Découvrir le livre Molière →</a></div></section>'''
    escaped = escape(url, quote=True)
    return f'''<section class="section"><div class="audio-panel"><p class="eyebrow">À écouter ensemble</p><h2>Le théâtre prend vie.</h2><p>Installez-vous et lancez la lecture. Vous pouvez mettre en pause et reprendre à tout moment.</p><audio id="moliere-audio" controls preload="metadata" aria-label="Lecture théâtrale du bonus de Molière" src="{escaped}">Votre navigateur ne permet pas de lire ce fichier audio.</audio><div class="audio-tools"><button type="button" class="button light" id="audio-back">Reculer de 10 s</button><label>Vitesse <select id="audio-speed"><option value="0.75">0,75 ×</option><option value="1" selected>Normale</option><option value="1.25">1,25 ×</option><option value="1.5">1,5 ×</option></select></label></div><p id="audio-status" role="status"></p><a class="underlink" href="{escaped}">Ouvrir le fichier audio ↗</a></div><p><a class="underlink" href="/livres/moliere/">Retrouver le livre Molière →</a></p></section>'''
