# V1.8.9 — Audios et films dans les bonus

Installez les fichiers du ZIP dans la racine du SITE contenant build.py, package.json et content.json.
Ne les installez pas dans un autre projet, même si son nom contient Lpgrapp.
Le ZIP préserve content.json : il ne remplace aucun livre, événement ou bonus enregistré dans l’Admin.

1. Avant la copie : git pull --rebase origin main
2. Copiez les fichiers du ZIP en conservant les sous-dossiers.
3. Lancez python build.py pour vérifier, puis git add ., git commit et git push.
   Les variables SITE_URL et INDEXATION_ENABLED de Vercel restent inchangées.

## Après le déploiement

Ouvrez /administration/ et actualisez la page.
Sélectionnez Bonus et activités, puis chaque bonus existant :
- Type : Audio local — lecteur sur le site.
- Fichier audio déjà déployé : choisissez le fichier dans la liste.
- Ou saisissez son chemin commençant par /audio/.
- Publiez les modifications et attendez le déploiement.

Les deux fichiers joints sont fournis sous des noms simples :
- public/audio/orthographe-moliere.mp3 → /audio/orthographe-moliere.mp3
- public/audio/kreol-baudelaire.mp3 → /audio/kreol-baudelaire.mp3

Le lecteur apparaît sur /bonus/ en cliquant sur Écouter le bonus.
La lecture ne démarre pas automatiquement. Un seul audio joue à la fois.
Si un fichier est absent, la page reste utilisable et affiche un message.
Les anciens liens externes audio restent compatibles jusqu’à leur remplacement.

Pour un film : Type Film — lien vers un site externe, puis URL HTTPS INA, YouTube, etc.
Le film s’ouvre dans un nouvel onglet ; aucun lecteur vidéo tiers n’est intégré au site.

## Prochain audio

Ajoutez un MP3 dans public/audio/, de préférence avec un nom simple sans espaces ni accents.
Poussez ce fichier dans GitHub et attendez Vercel.
Le fichier apparaîtra alors dans la liste de l’Admin.
Ajoutez ou modifiez le bonus, puis publiez pour l’afficher.
Seuls les fichiers audio directement placés dans public/audio/ sont publiés, sans sous-dossier.
L’Admin référence les audios déjà déployés : il ne téléverse pas de MP3 depuis le navigateur.
