# Mise à jour des textes V1.2.0

## Installation

Décompressez le paquet hors du dossier du site. Dans le dossier obtenu, lancez :

    python installer_maj.py "C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp"

Les fichiers remplacés sont sauvegardés dans un dossier voisin. Le catalogue existant, les couvertures, les photos, le MP3 et les réglages SumUp/Brevo sont conservés. Les fichiers de modèles de pages sont remplacés par ceux de cette version. Si vous avez modifié ces modèles à la main depuis la livraison précédente, reportez vos adaptations depuis la sauvegarde.

Puis, dans le dossier habituel du site :

    git add .
    git commit -m "V1.2 - textes complets du brief et auteurs"
    git push

Aucune nouvelle variable Vercel n’est nécessaire pour les textes. Les paramètres Brevo restent ceux de la V1.1. La configuration technique demeure compatible avec le déploiement Vercel existant ; l’évocation d’OVH dans le cahier des charges ne déclenche pas de migration d’hébergement.

## Textes repris

Source : Site Les plus grands racontés aux plus petits contenu et brief 1.docx, transmis le 20 octobre 2026.

- Accueil : H1, title, description et les onze blocs dans l’ordre du document ; les dix titres disponibles, les quatre publics, la citation et les trois références de presse sont présents.
- Auteurs : introduction et biographies à la première personne intégralement reproduites ; texte de collaboration conservé.
- Professionnels : les six publics et leurs conditions, les documents attendus, les champs ville et demande de devis.
- Fiches : gabarit Victor Hugo, titres accordés au féminin lorsque nécessaire, données pratiques, dépôt légal, mention de TVA, extraits en attente, liens professionnels, précédent et suivant.
- Offrir : compositions, prix et frais d’envoi, texte des abonnements conservé.
- Fabriqué en France : les six paragraphes sur la fabrication et le prix sont repris.
- Presse : la citation courte autorisée, les trois journaux, dates et signatures du document. Aucune citation d’article n’a été inventée ; les images et citations manquantes restent à ajouter.

Les textes sont conservés dans textes-brief.json avec leurs numéros de paragraphes source. editorial_pages.py choisit leur emplacement et retire uniquement les étiquettes de rédaction (H1, H2, Introduction), les instructions de mise en page et les indications de lien. Les passages publics ne sont pas résumés. Les éléments entre crochets destinés à être complétés restent visibles lorsqu’ils accompagnent un texte public.

Les notes techniques, comparaisons d’hébergement, coûts d’impression, marges et conseils au comptable ne sont pas publiés. Ce sont des notes de préparation, conservées dans la source JSON hors du dossier public dist. Les recommandations juridiques internes ne sont pas converties en conditions contractuelles définitives.

## Points encore provisoires du document

- L’âge affiché devient « dès 5 ans ». La fourchette à confirmer n’est indiquée que dans les fiches pratiques.
- Le prix du Collector est affiché « à confirmer ». Aucune recommandation de prix du document n’est transformée en prix validé.
- Les passages manquants des livres, les coupures de presse, les PDF professionnels et les visuels restent des emplacements à compléter.
- La citation courte d’Amélie Nothomb est utilisée comme demandé ; aucun portrait ni qualification de marraine n’est publié.
- La lettre d’information reprend son libellé, mais ne prétend pas qu’une inscription automatique est déjà raccordée.

## Terminologie et adresses

Le terme « auteurs » est utilisé dans les menus, les titres, les textes, les formulaires et les messages d’envoi. La page est /auteurs/. Les chemins /ou-nous-trouver/ et /actualites/ de l’arborescence sont présents ; le blog attend ses premiers articles. Une redirection de l’ancienne adresse est conservée afin de ne pas casser les liens existants. Ce vieux segment technique n’est plus utilisé dans les liens de navigation ni dans les textes affichés.

## Fichiers utiles pour les prochaines modifications

- textes-brief.json : textes source du document, hors du dossier public.
- editorial_pages.py : choix des blocs et disposition des pages éditoriales.
- build.py : génération commune, en-tête, pied de page, métadonnées.
- site_features.py : formulaire, commandes, livraison et lecteur audio.
- content.json : couvertures et informations propres à chaque livre.
- dist/style.css et dist/app.js : présentation et interactions.

Après chaque modification des modèles ou des contenus : python build.py avant le push.

## Vérifications

Dix tests Python passent, dont six nouveaux contrôles éditoriaux : paragraphes complets, biographies, professionnels, fabrication/abonnements, vocabulaire et métadonnées. Huit tests serveur passent, dont les protections et les erreurs d’envoi. Les liens internes et ancres de toutes les pages sont vérifiés. Le contrôle visuel dans un navigateur reste à faire.
