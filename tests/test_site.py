import json
import sys
import tempfile
import unittest
from urllib.parse import unquote
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from site_features import audio_body, book_order, offer_order


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.h1 = 0
        self.ids = set()
        self.links = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.h1 += tag == 'h1'
        if 'id' in attrs:
            self.ids.add(attrs['id'])
        for key in ['href', 'src']:
            if attrs.get(key, '').startswith('/'):
                self.links.append(attrs[key])


class SiteTests(unittest.TestCase):
    def test_generated_links_and_fragment_targets(self):
        parsed = {}
        for path in (ROOT / 'dist').rglob('*.html'):
            parser = Links()
            parser.feed(path.read_text(encoding='utf-8'))
            self.assertEqual(parser.h1, 1, path)
            parsed[path] = parser
        for path, parser in parsed.items():
            for link in parser.links:
                route, _, fragment = link.partition('#')
                route = unquote(route.split('?')[0])
                if route.startswith('/api/'):
                    continue
                dest = ROOT / 'dist' / route.lstrip('/')
                self.assertTrue(dest.exists(), (path, link))
                if fragment:
                    self.assertIn(fragment, parsed[dest / 'index.html'].ids)

    def test_available_books_use_distinct_real_product_links(self):
        books = json.loads((ROOT / 'content.json').read_text(encoding='utf-8'))['books']
        available = [b for b in books if b['available']]
        self.assertEqual(len(available), 10)
        self.assertEqual(len({b['commande_url'] for b in available}), 10)
        for book in available:
            page = (ROOT / 'dist/livres' / book['slug'] / 'index.html').read_text(encoding='utf-8')
            self.assertIn('href="' + book['commande_url'] + '"', page)
            self.assertIn('/product/', book['commande_url'])
        self.assertNotIn('javascript:', book_order({'commande_url': 'javascript:alert(1)'}, 'https://example.org'))

    def test_missing_offer_is_a_contact_request_and_configured_offer_is_direct(self):
        result = offer_order('duo', {'offer_urls': {}}, subject='Duo pour Noël')
        self.assertIn('/contact/?sujet=', result)
        self.assertNotIn('sumup', result)
        direct = offer_order('duo', {'offer_urls': {'duo': 'https://example.org/duo'}})
        self.assertIn('href="https://example.org/duo"', direct)

    def test_audio_never_inserts_missing_mp3(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertNotIn('<audio', audio_body({}, root))
            audio = root / 'dist/assets/audio/moliere.mp3'
            audio.parent.mkdir(parents=True)
            audio.write_bytes(b'test-fixture')
            self.assertIn('src="/assets/audio/moliere.mp3"', audio_body({}, root))
            self.assertIn('src="https://example.org/audio.mp3"', audio_body({'moliere_audio_url': 'https://example.org/audio.mp3'}, root))


if __name__ == '__main__':
    unittest.main()
