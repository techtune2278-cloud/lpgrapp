# Mise à jour V1.2.1 — images, bonus et presse

## Installer le code mis à jour

Décompressez ce paquet hors du dossier du site, puis lancez depuis le dossier obtenu :

    python installer_maj.py "C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp"

L’installateur sauvegarde les fichiers remplacés, préserve le catalogue et les images existantes, raccorde les dossiers ci-dessous et ajoute le lien du bonus ainsi que le quatrième article Ouest-France. Il ne pousse rien sur GitHub.

## Où copier les images sur votre PC

Dossier de votre site :

    C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp

Décompressez d’abord les photos si elles sont encore dans une archive ZIP. Vous pouvez conserver les noms de votre capture et leurs véritables extensions. JPG, JPEG, PNG et WebP sont acceptés ; les majuscules et accents des noms sont pris en compte.

| Images de votre capture | Dossier de destination dans le projet |
|---|---|
| Hervelina Vyskoc ; Valérie Lemoine | dist\assets\photos\ |
| Balzac ; Colette ; Hugo ; Molière ; Proust ; Rimbaud ; Sand ; Ségur ; Verne ; Zola | dist\assets\couvertures\ |
| actu.fr 1er avril 2026 ; les deux fichiers Article magazine Le Flaneur… ; Article Ouest-France 28 avril 2026 ; article pyrénées | dist\assets\presse\ |

Les trois dossiers complets sont :

    C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp\dist\assets\photos
    C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp\dist\assets\couvertures
    C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp\dist\assets\presse

Ils sont créés par la mise à jour. Windows peut masquer les extensions : ne rajoutez pas .jpg au nom si cette extension existe déjà.

Les deux fichiers Flâneur sont regroupés sous le même article, avec deux liens d’agrandissement. Leur nom peut conserver la date qu’il contient ; la date affichée de l’article reste celle du cahier des charges, le 27 juin 2026. Les noms tronqués dans la capture ne posent pas de problème : la détection cherche Flaneur dans leur nom.

Les portraits individuels sont légendés avec les noms des auteurs, sans les présenter à tort comme une photo prise au Festival du Livre de Paris.

Si une couverture possède déjà une adresse explicite dans le champ cover de content.json, cette adresse reste prioritaire. Pour utiliser à la place le fichier déposé dans le dossier couvertures, videz uniquement ce champ cover du livre, puis régénérez.

## Afficher et publier

Après avoir copié les images :

    cd /d "C:\Techtune\Devt\Site Lpgrapp\Site lpgrapp"
    python build.py
    python -m http.server 8080 --bind 127.0.0.1 --directory dist

Ouvrez http://127.0.0.1:8080 et rechargez avec Ctrl+F5. Arrêtez le serveur avec Ctrl+C, puis :

    git add .
    git commit -m "V1.2.1 - images, bonus et article Ouest-France"
    git push

Attendez que le déploiement Vercel soit Ready, puis contrôlez https://sitelpgrapp.vercel.app/.

Vous n’avez pas besoin d’inscrire chaque image dans content.json lorsque vous utilisez les noms de la capture : le générateur les détecte au moment de python build.py. Un fichier déposé après la génération nécessite une nouvelle génération.

## Bonus et quatrième article

Le lien des bonus est ajouté sur /bonus/ et /bonus/moliere/ :
https://www.lescompagnonsderoute.com/les-bonus-de-la-collection-lpgrapp

C’est une page web externe, pas une adresse MP3 : le site utilise un bouton pour y accéder, sans essayer de la lire dans un lecteur audio. Le lecteur local reste disponible si un vrai MP3 est ajouté plus tard.

Le quatrième article Ouest-France apparaît dans la rubrique Ils parlent de nous sur l’accueil et sur la page Presse. L’image est repérée dans le dossier presse à partir de Ouest-France dans son nom.

Les textes du cahier des charges restent inchangés. Les images réelles n’ont pas été fournies dans cette conversation : seule la capture de leur liste a été reçue. Elles apparaîtront sur votre version locale et Vercel après leur copie et la génération.
