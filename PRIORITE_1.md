# Mise à jour V1.1.0 — priorité 1

## Installer sur votre PC

Le petit paquet de mise à jour contient un installateur et les fichiers modifiés. Décompressez-le hors du dossier du site, puis lancez depuis ce dossier :

```bat
python installer_maj.py "C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp"
```

L’installateur sauvegarde les fichiers remplacés dans un dossier voisin, conserve les photos et le catalogue existants, ajoute les liens SumUp aux livres et régénère les pages. Il ne fait pas de push. Si vous avez modifié vous-même les modèles dans build.py, les anciennes versions restent dans cette sauvegarde : comparez-les pour reporter vos modifications.

Ensuite, dans le dossier habituel du site :

```bat
git status
git add .
git commit -m "V1.1 - commandes directes, contact, livraison et audio"
git push
```

Attendez le statut Ready du déploiement Vercel.

## Commandes

Les dix livres disponibles ont leur lien direct dans `commande_url`, dans `content.json`. Les prochains titres restent non commandables.

Les offres groupées et abonnements n’ont pas de page dans le catalogue SumUp consulté le 20 octobre 2026. Leurs boutons ouvrent une demande préremplie, sans paiement. Après création des produits dans SumUp, renseignez leurs URL dans `offer_urls`, dans `site-settings.json`, puis régénérez et poussez. Les boutons deviennent alors des liens de commande directs.

## Activer l’envoi des messages

Le formulaire et la fonction Vercel sont codés. L’envoi nécessite un compte Brevo et un expéditeur validé chez Brevo. Aucun e-mail n’est envoyé tant que la configuration n’est pas présente.

Dans Vercel, ouvrez le projet puis **Settings → Environment Variables** et ajoutez :

| Nom | Valeur à renseigner |
|---|---|
| `BREVO_API_KEY` | Votre clé API Brevo |
| `CONTACT_FROM_EMAIL` | Adresse d’expéditeur validée dans Brevo |
| `CONTACT_TO_EMAIL` | Adresse qui reçoit les demandes |
| `CONTACT_FROM_NAME` | Facultatif : Les plus grands racontés aux plus petits |

Choisissez les environnements concernés, puis redéployez le dernier commit pour appliquer les variables. Ne placez jamais la clé API dans GitHub, dans un fichier de contenu ou dans le navigateur.

La future adresse contact@lesplusgrandsracontes.fr ne peut servir d’expéditeur qu’une fois créée et validée. En attendant, utilisez une adresse que vous contrôlez et que Brevo accepte comme expéditeur.

Le bouton Envoyer s’active quand la fonction annonce que ses paramètres sont présents. Cette vérification ne valide pas les identifiants chez Brevo : après configuration, faites un essai et vérifiez la réception. Le succès est affiché uniquement après acceptation de l’envoi par Brevo ; il ne garantit pas le placement dans la boîte de réception plutôt que les indésirables.

La protection antispam est discrète : champ piège, délai minimal, validation serveur, contrôle d’origine et limitation de tentatives par instance de serveur. Elle ne constitue pas une limite globale partagée entre toutes les instances. En cas d’abus réel, une protection complémentaire pourra être ajoutée.

Avec le simple serveur Python local ou dans l’aperçu statique privé ChatGPT, la fonction Vercel ne tourne pas. Le formulaire y reste indisponible, mais le bouton de brouillon fonctionne. L’essai d’envoi doit se faire sur le déploiement Vercel configuré.

## FAQ et livraison

La page `/livraison/` regroupe tarifs et questions. Elle est accessible depuis le pied de page et près des commandes. Les tarifs sont dans `shipping`, dans `site-settings.json`. Les réponses sont dans `site_features.py`, fonction `shipping_body`.

Le délai de 2–3 jours reste indicatif : son point de départ et les modalités par destination doivent être confirmés. Aucune nouvelle condition de retour ni option cadeau n’est inventée.

## Activer le bonus Molière

Déposez le véritable fichier sous le nom :

```text
dist/assets/audio/moliere.mp3
```

Puis lancez `python build.py` et les commandes Git habituelles. Le lecteur apparaît automatiquement : lecture, pause, déplacement dans l’enregistrement, recul de dix secondes et vitesse réglable. Sans fichier, la page reste dans un état d’attente explicite, sans faux lecteur ni fichier manquant.

Autre possibilité : indiquez une URL HTTPS du MP3 dans `moliere_audio_url`, dans `site-settings.json`. L’URL doit servir directement le fichier audio, pas une page web.

La page stable est `/bonus/moliere/`. Le QR imprimé pointe actuellement vers Les Compagnons de Route : sur cet ancien site, remplacez le contenu de la page existante par un lien ou configurez sa redirection vers `https://sitelpgrapp.vercel.app/bonus/moliere/`. Un changement dans le nouveau site ne modifie pas l’ancien domaine. Une redirection du chemin historique est aussi prévue sur le nouveau domaine pour une migration future.

## Vérifications faites

Sept tests serveur passent avec un service d’e-mail simulé : envoi accepté, configuration manquante, erreur prestataire, validation, antispam et limitation. Quatre tests Python vérifient les liens internes et ancres, les dix liens produits, les offres non raccordées et l’activation du lecteur audio. Aucun message réel n’a été envoyé. Le rendu dans un navigateur et l’essai réel sur votre Vercel restent à vérifier.

Références techniques : https://developers.brevo.com/reference/send-transac-email et https://vercel.com/docs/functions/runtimes/node-js/advanced-node-configuration (consultées le 20 octobre 2026).
