# Audit initial du classeur — Collection Livres

Fichier analysé : `Suivi_Collection_Livres_CRM_Stocks_PRO.xlsx`.

## Structure repérée

Le classeur comprend 28 onglets : tableaux de bord et mode d'emploi, paramètres, catalogue/stock, ventes, clients, dépenses, réimpressions, tarifs postaux, projections, CRM, événements, édition/ISBN, ventes professionnelles et particulières, financements 2025/2026, coûts et prix, communications, salons, festivals, presse et écoles.

Le catalogue contient 33 positions de tome dont 11 publiées dans le tableau principal. La feuille centralisée des ventes contient environ 143 lignes de vente/lignes de commande, le registre client environ 43 fiches et les dépenses environ 12 lignes. Le tableau `07 REIMPRESSIONS` possède ses en-têtes mais aucune ligne de tirage renseignée.

## Écarts nécessitant une reprise contrôlée

- Le calcul historique « stock initial + réimpressions saisies − ventes » fait ressortir le tome 10 à −4 exemplaires. Ce chiffre n'est pas un stock physique fiable.
- Certains abonnements couvrent plusieurs tomes, y compris des ouvrages à venir : leur recette ne doit pas être ventilée arbitrairement entre titres.
- Une vente professionnelle liée au Musée de Nantes comporte une quantité de cinq et un montant de 46 € placé dans une colonne de prix unitaire, sans total clairement identifié.
- Certaines lignes de vente ne permettent pas une ventilation certaine des quantités ou montants ; elles doivent être rapprochées avec un justificatif.
- Des identifiants ISBN/EAN entre le catalogue et la fiche éditoriale nécessitent une vérification avant publication ou nouvelle impression.
- Les informations de production, financements, prix et dépenses apparaissent dans plusieurs feuilles historiques : elles ne constituent pas encore un journal unique et exhaustif des commandes, réceptions et règlements.

## Politique retenue

1. Précharger le catalogue, mais ne pas considérer les anciennes formules de stock comme stock opérationnel.
2. Effectuer un inventaire physique d'ouverture par tome avant de saisir de nouvelles ventes.
3. Conserver chaque ligne source, les valeurs et les formules, dans `legacy_import_rows` pour rapprocher l'historique.
4. N'importer les ventes, paiements, dépenses et tirages historiques dans les tables opérationnelles qu'après validation d'une règle de rapprochement explicite. Une ligne ambiguë reste signalée, jamais transformée automatiquement en opération supposée.
5. Séparer les dons, prêts, dépôts-vente, pertes, régularisations d'inventaire et réceptions d'impression des ventes réelles.
