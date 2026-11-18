"""Repérage des images déposées par l’utilisateur, sans imposer de renommage."""
import re
import unicodedata
from urllib.parse import quote

EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp'}


def normalize(value):
    plain = unicodedata.normalize('NFKD', value).encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]', '', plain)


def find_images(root, folder, *aliases, contains=False):
    directory = root / 'dist/assets' / folder
    if not directory.is_dir():
        return []
    candidates = sorted((p for p in directory.iterdir() if p.is_file() and p.suffix.lower() in EXTENSIONS), key=lambda p: p.name.casefold())
    wanted = [normalize(a) for a in aliases]
    matches = []
    for p in candidates:
        name = normalize(p.stem)
        if any((a in name if contains else a == name) for a in wanted):
            matches.append('/' + quote(p.relative_to(root / 'dist').as_posix(), safe='/'))
    return matches


def apply_book_images(books, root):
    aliases = {1:'Rimbaud',2:'Hugo',3:'Ségur',4:'Proust',5:'Sand',6:'Verne',7:'Zola',8:'Balzac',9:'Colette',11:'Molière'}
    for book in books:
        if not book.get('cover'):
            matches = find_images(root, 'couvertures', book['title'], book['slug'], aliases.get(book['number'], book['title']))
            if matches:
                book['cover'] = matches[0]


def portraits(root, esc):
    found = []
    has_photo = False
    for name, aliases in [('Hervélina Vyskoc', ['Hervélina Vyskoc','Hervelina Vyskoc']), ('Valérie Lemoine', ['Valérie Lemoine','Valerie Lemoine'])]:
        preferred = root / 'dist/assets/photos/hervelina-portrait.jpg'
        if name == 'Hervélina Vyskoc' and preferred.is_file():
            paths = ['/assets/photos/hervelina-portrait.jpg']
        else:
            paths = find_images(root, 'photos', *aliases)
        if paths:
            has_photo = True
            found.append('<figure><img src="'+esc(paths[0])+'" alt="'+name+'" loading="lazy"><figcaption>'+name+'</figcaption></figure>')
        else:
            found.append('<figure class="portrait-missing"><span aria-hidden="true">✳</span><figcaption>'+name+'</figcaption></figure>')
    if not has_photo:
        return ''
    return '<div class="author-portraits">'+''.join(found)+'</div>'


def press_images(root, key):
    aliases = {'pyrenees':['pyrenees'], 'tregor':['actufr','tregor'], 'flaneur':['flaneur'], 'ouest-france':['ouestfrance']}
    return find_images(root, 'presse', *aliases[key], contains=True)
