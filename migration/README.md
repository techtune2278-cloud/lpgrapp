# Reprise Excel — données confidentielles

Le classeur source et l'extraction JSON sont remis dans une archive privée distincte pour ne pas mélanger les données nominatives au code applicatif. Copiez `private-workbook-extract.json` dans ce dossier avant d'exécuter `scripts/import-legacy-staging.mjs`.

La zone `legacy_import_rows` conserve les valeurs et les formules de chaque ligne non vide, avec le nom de feuille, le numéro de ligne et un hash de contrôle. Elle sert à la revue et au rapprochement. Elle n'est pas le journal commercial opérationnel et ne crée pas automatiquement des ventes, encaissements ou quantités en stock.

Voir `ANALYSE_CLASSEUR.md` pour les anomalies et la méthode de reprise. N'ajoutez jamais le fichier source ni les coordonnées des contacts au dépôt Git.
