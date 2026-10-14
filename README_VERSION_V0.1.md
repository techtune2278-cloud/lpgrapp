# LPGR’APP — affichage de la version V0.1

Ce correctif contient uniquement les deux fichiers modifiés pour afficher un badge `VERSION V0.1` dans la barre supérieure de l'application.

## Installation
1. Décompresser le ZIP à la racine du projet `C:\Techtune\Devt\Lpgrapp`.
2. Accepter le remplacement des fichiers :
   - `components/AppShell.tsx`
   - `app/globals.css`
3. Vérifier en local avec `npm run build`.
4. Pour mettre à jour Vercel, il faut aussi publier le changement :
   - si le projet est relié à GitHub : `git add components/AppShell.tsx app/globals.css`, puis `git commit -m "Add LPGRAPP version badge V0.1"` et `git push` ;
   - sinon, si Vercel CLI est configuré pour le projet : lancer `vercel --prod` depuis la racine du projet.

Le simple `npm run build` vérifie le build local et ne déploie pas le site sur Vercel.
