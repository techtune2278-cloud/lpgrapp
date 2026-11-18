# Les plus grands racontés aux plus petits — V1.7.0

Version de publication. Abonnement libre, réservations et e-mails : **MAJ_V1.7.md**. Installation, domaine, configuration Brevo, référencement et mises à jour : **DEPLOIEMENT_V1.4.md**.

Le catalogue et les textes restent dans `content.json` et `textes-brief.json`. Le générateur Python produit le HTML complet dans `dist`. Les notes de préparation entre crochets ne sont pas affichées. Les dates manquantes ne bloquent pas le site. Les images locales sont automatiquement optimisées sans toucher aux originaux.

Compilation : `npm run build`, ou `python -m pip install -r requirements.txt` puis `python build.py`.

Aperçu : `python -m http.server 8080 --bind 127.0.0.1 --directory dist` puis http://127.0.0.1:8080.

Tests : `python -m unittest discover -s tests -p "test_*.py"` et `npm test`.

Production Vercel : Build Command `npm run build`, Output Directory `dist`. La variable `SITE_URL` détermine le domaine des canonical, données structurées et sitemap. Valeur par défaut : https://sitelpgrapp.vercel.app. Les secrets Brevo restent dans les variables Vercel. Les formulaires nécessitent les réglages de compte décrits dans le guide ; le serveur Python de prévisualisation ne les exécute pas.

L’atelier historique conserve les modifications dans le navigateur et ne publie pas directement. Les fichiers HTML, `dist/content.json`, WebP et cartes de partage sont générés. Les fichiers image originaux sont conservés. `seo-report.json` est un rapport local régénéré à chaque compilation.
