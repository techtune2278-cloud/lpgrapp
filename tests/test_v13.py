import re
import unittest
from html.parser import HTMLParser
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from page_helpers import external_links, subscription_books
import json


class Anchors(HTMLParser):
    def __init__(self):
        super().__init__();self.links=[]
    def handle_starttag(self,tag,attrs):
        if tag=='a':self.links.append(dict(attrs))


class V13Tests(unittest.TestCase):
    def test_external_links_and_pdf_use_new_tabs_but_internal_navigation_does_not(self):
        for page in (ROOT/'dist').rglob('index.html'):
            parser=Anchors();parser.feed(page.read_text(encoding='utf-8'))
            for link in parser.links:
                url=link.get('href','')
                if url.startswith(('https://','http://')) or url.split('?')[0].endswith('.pdf'):
                    self.assertEqual(link.get('target'),'_blank',(page,url))
                    self.assertIn('noopener',link.get('rel',''))
        self.assertEqual(external_links('<a href="/livres/">Livres</a>'),'<a href="/livres/">Livres</a>')

    def test_free_builder_includes_available_cheap_titles(self):
        books=json.loads((ROOT/'dist/content.json').read_text())['books']
        eligible=subscription_books(books)
        self.assertTrue({1,2}.issubset(b['number'] for b in eligible))
        markup=(ROOT/'dist/offrir/index.html').read_text()
        self.assertIn('id="subscription-builder"',markup)
        self.assertIn('id="subscription-schedule"',markup)

    def test_assets_and_publisher_details_are_present(self):
        prof=(ROOT/'dist/professionnels/index.html').read_text(encoding='utf-8')
        self.assertIn('/assets/documents/dossier-alliances-francaises-lpgrapp.pdf',prof)
        self.assertIn('/assets/optimized/',prof)
        self.assertTrue((ROOT/'dist/assets/photos/musee-jules-verne-nantes.jpg').is_file())
        self.assertTrue((ROOT/'dist/assets/documents/dossier-alliances-francaises-lpgrapp.pdf').is_file())
        for path in (ROOT/'dist/livres').rglob('index.html'):
            if path.parent.name=='livres':continue
            markup=path.read_text(encoding='utf-8')
            self.assertIn('<dt>Auteurs</dt><dd>Hervélina Vyskoc et Valérie Lemoine</dd>',markup)
            self.assertIn('<dt>Édition</dt><dd>Sur le chemin des arts</dd>',markup)
        mentions=(ROOT/'dist/mentions-legales/index.html').read_text(encoding='utf-8')
        self.assertIn('953 755 477 00015',mentions)
        self.assertIn('Valérie Lemoine',mentions)
        self.assertNotIn('Atelier de contenu',(ROOT/'dist/index.html').read_text(encoding='utf-8'))


if __name__=='__main__':unittest.main()
