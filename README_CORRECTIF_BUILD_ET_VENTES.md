# LPGR'APP — correctif Build + consultation des ventes historiques

## Contenu du correctif

- `app/manifest.ts` : corrige les valeurs de `purpose` en séparant `any` et `maskable`, comme l'attend le type de manifest Next.js.
- `lib/format.ts` : supprime la propriété `to_review` déclarée deux fois dans l'objet des statuts.
- `app/(app)/ventes/page.tsx` : conserve le formulaire et l'historique des ventes opérationnelles, et ajoute un tableau en lecture seule pour les lignes de l'onglet Excel `04 VENTES` présentes dans `public.legacy_import_rows`.
- `supabase/diagnostics/VERIFIER_DONNEES_EXCEL.sql` : requêtes en lecture seule pour vérifier les volumes importés et l'absence éventuelle de transactions opérationnelles.

## Installation

Extraire le ZIP directement dans la racine du projet local (par exemple `C:\\Techtune\\Devt\\Lpgrapp`) et remplacer les fichiers existants.

Puis lancer :

```powershell
npm run build
```

Le build complet n'a pas pu être exécuté dans l'environnement de préparation car l'installation des dépendances npm a expiré. Le correctif traite les deux erreurs TypeScript citées et doit être vérifié avec le build de votre environnement.

## Important sur les ventes historiques

Le script `npm run import:legacy` copie les valeurs et formules Excel dans `public.legacy_import_rows`. Il ne crée pas de lignes dans `public.sales`, `public.sale_items` ou `public.payments`.

Le nouveau tableau de la page Ventes affiche donc les lignes source de `04 VENTES` en lecture seule, sous un avertissement indiquant qu'elles restent à rapprocher. Elles ne sont volontairement pas comptées comme des ventes opérationnelles : dans le classeur, de nombreuses dates et valeurs de prix/CA manquent, et des encaissements de souscription couvrent plusieurs ouvrages. Il faut les valider avant de les convertir afin de ne pas fabriquer des chiffres comptables ou des sorties de stock incorrects.

Exécuter `supabase/diagnostics/VERIFIER_DONNEES_EXCEL.sql` dans Supabase pour vérifier les volumes réels de votre base.
