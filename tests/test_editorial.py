"""Contrôles de fidélité au document joint et de remplacement du vocabulaire."""
import json
import re
import unittest
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = json.loads((ROOT / 'textes-brief.json').read_text(encoding='utf-8'))['paragraphs']


class Reader(HTMLParser):
    def __init__(self):
        super().__init__()
        self.words = []

    def handle_data(self, data):
        self.words.append(data)


def normal(value):
    return ' '.join(re.sub(r'\s*\[[^\]]*\]', '', value).split())


def read(route):
    value = (ROOT / 'dist' / route / 'index.html').read_text(encoding='utf-8')
    parser = Reader()
    parser.feed(value)
    return normal(' '.join(parser.words)), value


class EditorialTests(unittest.TestCase):
    def test_home_visitor_paragraphs_are_complete(self):
        actual, _ = read('')
        for number in [66,67,68,69,73,74,75,100,103]:
            expected=SOURCE[str(number)].replace('écrivaine','écrivain') if number==59 else SOURCE[str(number)]
            self.assertIn(normal(expected), actual, f'Paragraphe {number} absent ou réécrit')
        for number in [62,65,70,72,77,90,96,99,102]:
            self.assertIn(normal(SOURCE[str(number)].split('H2 : ',1)[-1]), actual)
        self.assertIn(normal(SOURCE['71'].split(' Lien : ',1)[0]), actual)
        self.assertIn(normal(SOURCE['97'].split(' Lien : ',1)[0]), actual)
        self.assertIn('Soyez prévenu à chaque nouvelle parution.', actual)

    def test_author_biographies_are_not_summarized(self):
        actual, _ = read('auteurs')
        for number in [146,148]:
            self.assertIn(normal(SOURCE[str(number)]), actual)
        intro=SOURCE['144'].removeprefix('Introduction. ').split(' Photo des deux auteurs',1)[0]
        self.assertIn(normal(intro), actual)
        self.assertIn(normal(SOURCE['150'].split(' Lien vers ',1)[0]), actual)

    def test_professional_conditions_are_complete_and_form_has_requested_fields(self):
        actual, markup = read('professionnels')
        for number in [255,261,264,267,270,271]:
            self.assertIn(normal(SOURCE[str(number)]), actual)
        self.assertNotIn('30 %',actual)
        self.assertNotIn('remises',actual)
        self.assertIn('Vente ferme, sans dépôt.',actual)
        for field in ['profil','nom','ville','email','message','devis','consent']:
            self.assertIn('name="'+field+'"', markup)

    def test_manufacturing_and_subscription_texts_are_complete(self):
        actual,_=read('fabrique-en-france')
        for number in [471,472,473,474,475,476]:
            self.assertIn(normal(SOURCE[str(number)]), actual)
        actual,_=read('offrir')
        self.assertIn('Offrir un abonnement à une collection de livres pour enfants',actual)
        self.assertIn("Une carte et une dédicace d'Hervélina ou de Valérie.",actual)

    def test_no_old_word_or_unconfirmed_upper_age_in_public_copy(self):
        for path in (ROOT/'dist').rglob('*.html'):
            markup=path.read_text(encoding='utf-8')
            self.assertNotRegex(markup.lower(), r'\bautrices\b', path)
            if '/livres/' not in path.as_posix():
                self.assertNotRegex(markup, r'5[–-]10|5 à 10', path)

    def test_prescribed_metadata_and_hugo_heading(self):
        for route, title_no, description_no in [('',53,54),('auteurs',139,140),('livres/victor-hugo',155,156)]:
            text,_=read(route)
            self.assertIn(normal(SOURCE[str(title_no)].split(' : ',1)[1]),text)
            # Parser decodes the attribute values separately below.
            class Meta(HTMLParser):
                description=''
                def handle_starttag(self,tag,attrs):
                    attrs=dict(attrs)
                    if tag=='meta' and attrs.get('name')=='description': self.description=attrs['content']
            meta=Meta();meta.feed((ROOT/'dist'/route/'index.html').read_text(encoding='utf-8'))
            self.assertEqual(meta.description,SOURCE[str(description_no)].split(' : ',1)[1])
        _,hugo=read('livres/victor-hugo')
        self.assertIn('<h1>Victor Hugo raconté aux enfants</h1>',hugo)


if __name__ == '__main__':
    unittest.main()
