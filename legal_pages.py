"""Publication des documents fournis, avec retrait des notes internes à compléter."""
import json,re,html
from pathlib import Path
MED='Centre d’Affaires Stéphanois, Immeuble l’Horizon – Esplanade de France, 3 rue J. Constant Milleret, 42000 Saint-Étienne'

def clean_line(text):
    text=text.replace('[date à compléter]','3 novembre 2026').replace('[date de mise en ligne]','3 novembre 2026').replace('[à compléter après confirmation de l\'adhésion]','')
    if text.startswith(('Code APE :','Immatriculation :','[Coordonnées','[À compléter','[Coordonnées postales','Les durées suivantes constituent','La liste définitive des prestataires','Avant la mise en ligne,','les conditions contractuelles de traitement','les lieux de stockage et les éventuels transferts','les garanties juridiques','les éventuels autres prestataires')):return ''
    if text.startswith('Téléphone :') or text=='par téléphone : [à compléter].':return 'Téléphone : 06 18 37 69 14.'
    if text.startswith('Adresse postale :'):return 'Adresse postale : '+MED+'.'
    if text.startswith('Site internet dédié à la médiation :'):return 'Site internet dédié à la médiation : https://www.medconsodev.eu/.'
    if text.startswith('Demandes de contact sans suite commerciale'):return 'Demandes de contact sans suite commerciale : trois ans après le dernier échange.'
    if 'un livre en attente dans un colis groupé ne peut être conservé plus de trois mois' in text:return 'Le client choisit le mois d’envoi de chaque ouvrage. Ce mois ne peut pas être antérieur à la parution annoncée ; tous les livres d’un même colis ont le même mois d’envoi.'
    if 'Les livres déjà parus peuvent être expédiés dès' in text:return 'Les livres déjà parus sont expédiés après paiement, au mois choisi pour l’abonnement. Les achats à l’unité sont expédiés selon les conditions de la boutique.'
    if text.startswith('Les livres déjà parus sont expédiés dans un délai'):return 'Pour un départ immédiat, les livres déjà parus sont expédiés sous cinq jours ouvrés suivant le paiement ; pour un abonnement planifié, ils sont expédiés au mois choisi.'
    if text.startswith('Les colis contenant des livres à paraître sont expédiés'):return 'Les colis contenant des livres à paraître sont expédiés dans les dix jours suivant la parution du dernier livre du colis, ou au mois ultérieur choisi par le client.'
    if 'de 3 à 12 livres parmi' in text:return text.replace('livres parmi','exemplaires (plusieurs exemplaires d’un même titre sont possibles) parmi')
    if 'Pour une commande comprenant plusieurs biens livrés séparément' in text:return text
    if text.startswith('Lorsque le consentement est requis') or text.startswith('Une rubrique dédiée') or text.startswith('accepter les cookies') or text.startswith('les refuser aussi') or text.startswith('modifier son choix') or text=='Le visiteur doit pouvoir :':return ''
    if text.startswith('Le site peut utiliser des cookies'):
        return 'Le site utilise des polices hébergées localement. Les liens externes n’intègrent pas de carte ou de vidéo tierce dans la page. Aucun traceur publicitaire n’est installé. Si une mesure d’audience est activée, ses modalités sont précisées sur cette page.'
    if 'du prestataire de gestion des formulaires' in text:return 'de Brevo, pour les formulaires, accusés de réception et la lettre d’information ;'
    if 'du prestataire de paiement, si' in text:return 'de SumUp pour les achats à l’unité réalisés dans la boutique ; les abonnements sont réglés par virement après facture ;'
    return re.sub(r'\[[^\]]*\]','',text).strip()

def render_legal(ctx):
    root,esc,page,heading=ctx['ROOT'],ctx['esc'],ctx['page'],ctx['heading'];docs=json.loads((root/'legal-documents.json').read_text(encoding='utf-8-sig'))
    dest=root/'dist/assets/documents';dest.mkdir(parents=True,exist_ok=True)
    retraction="""FORMULAIRE TYPE DE RÉTRACTATION
À : Sur le Chemin des Arts — Valérie Lemoine
22 rue de Lassun, 64800 Montaut
contact@lesplusgrandsracontes.fr

Je vous notifie ma rétractation du contrat portant sur les biens suivants :
........................................................................
Commande / facture n° : .................................................
Date de la commande : ...................................................
Date de réception du dernier livre : ....................................
Nom du consommateur : ...................................................
Adresse : ...............................................................
Date : ..................................................................
Signature (uniquement sur papier) : .....................................
"""
    for name,route,title in [('Mentions légales.docx','mentions-legales','Mentions légales'),('Conditions générales de vente.docx','cgv','Conditions générales de vente'),('Politique de confidentialité.docx','confidentialite','Politique de confidentialité')]:
        lines=[clean_line(x) for x in docs[name] if x.strip()];lines=[x for x in lines if x];body=heading('Informations',title)+'<section class="section copy-section">';public=[]
        for i,line in enumerate(lines):
            if i==0:continue
            if line.startswith('ANNEXE —'):break
            if '[numéro]' in line:continue
            public.append(line)
            tag='h2' if re.match(r'^(ARTICLE \d+|\d+\.|[A-D]\. )',line) else 'p'
            if line.startswith('Version du'):tag='p'
            body+='<'+tag+'>'+esc(line)+'</'+tag+'>'
        if route in ['cgv','mentions-legales']:body+='<h2>Médiateur</h2><p>MED CONSO DEV — '+esc(MED)+'. <a href="https://www.medconsodev.eu/">Saisir le médiateur</a>.</p>'
        if route=='confidentialite' and ctx['settings'].get('analytics_enabled'):body+='<p>Vercel Web Analytics mesure les visites de façon agrégée sans cookie de suivi entre sites.</p>'
        if route=='confidentialite':body+='<h2>Administration du contenu</h2><p>Les modifications publiques du catalogue et de l’agenda sont conservées dans GitHub et déployées par Vercel. Aucune donnée de commande ni adresse de destinataire n’est écrite dans ce dépôt. Une session sécurisée est utilisée uniquement dans l’espace privé d’administration.</p>'
        text='\n\n'.join(public)+(('\n\n'+retraction) if route=='cgv' else '')
        filename='cgv-et-retractation.txt' if route=='cgv' else route+'.txt';(dest/filename).write_text(text,encoding='utf-8')
        body+='<p><a href="/assets/documents/'+filename+'" download>Télécharger ce document (texte)</a></p>'
        if route=='cgv':body+='<p><a href="/retractation/">Formulaire de rétractation</a></p>'
        page(route,title,body+'</section>')
    (dest/'formulaire-retractation.txt').write_text(retraction,encoding='utf-8')
    page('retractation','Rétractation : formulaire et contact',heading('Commandes','Exercer votre droit de rétractation')+'<section class="section copy-section"><p>Adressez ce formulaire ou une déclaration sans ambiguïté à contact@lesplusgrandsracontes.fr, ou par courrier à Sur le Chemin des Arts, 22 rue de Lassun, 64800 Montaut.</p><p><a href="/assets/documents/formulaire-retractation.txt" download>Télécharger le formulaire de rétractation</a></p><pre class="legal-form">'+esc(retraction)+'</pre><p><a href="mailto:contact@lesplusgrandsracontes.fr?subject=Rétractation">Préparer un e-mail de rétractation</a></p><p><a href="/cgv/">Conditions de retour et de remboursement</a></p></section>')
