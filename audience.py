"""Mesure d’audience des pages publiques du domaine officiel."""
import os

MEASUREMENT_ID = 'G-R0SJSXH16B'
SITE_ORIGIN = 'https://www.lesplusgrandsracontes.fr'
PRIVATE_ROUTES = {'administration', 'atelier', '404', 'autrices', 'agenda', 'faq', 'newsletter-confirmee'}

PRIVACY = [
    'Le site utilise Google Analytics 4 (Google Ireland Limited) pour mesurer sa fréquentation : pages consultées, provenance générale des visites et caractéristiques du navigateur ou de l’appareil. Cette mesure est facultative et repose sur votre consentement. La balise Google est chargée uniquement si vous acceptez les statistiques.',
    'Après acceptation, Google Analytics utilise les cookies _ga et _ga_R0SJSXH16B pour distinguer les visites et conserver l’état de la session. Leur durée est réglée à six mois au maximum. Votre choix est conservé dans votre navigateur pendant six mois, que vous acceptiez ou refusiez.',
    'Vous pouvez retirer votre accord à tout moment via « Gérer mes cookies » en bas de page. Le site cesse alors la mesure sur ce navigateur et efface les cookies Analytics qu’il a déposés. Pour en savoir plus sur le traitement des données par Google : https://policies.google.com/technologies/partner-sites?hl=fr',
]


def enabled(origin):
    return origin == SITE_ORIGIN and os.environ.get('VERCEL_ENV') != 'preview'


def markup(origin, path, version):
    if not enabled(origin) or path in PRIVATE_ROUTES:
        return '', '', ''
    head = f'<script defer src="/audience.js?v={version}" data-ga-id="{MEASUREMENT_ID}" id="audience-script"></script>'
    footer = '<button type="button" id="audience-settings" hidden aria-controls="audience-choice" aria-expanded="false">Gérer mes cookies</button>'
    panel = '''<section id="audience-choice" class="audience-choice" aria-labelledby="audience-title" hidden>
<div><h2 id="audience-title">Statistiques de visite</h2>
<p>Avec votre accord, Google Analytics nous aide à savoir quelles pages sont consultées. Vous pouvez changer votre choix à tout moment. <a href="/confidentialite/#cookies">En savoir plus</a></p></div>
<div class="audience-actions"><button class="button light" type="button" id="audience-accept">Accepter</button><button class="button light" type="button" id="audience-refuse">Refuser</button></div>
</section>'''
    return head, footer, panel
