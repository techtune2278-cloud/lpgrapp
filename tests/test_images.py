import tempfile
import unittest
from pathlib import Path
from urllib.parse import unquote
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from image_assets import apply_book_images, find_images, press_images
from site_features import audio_body


class ImageTests(unittest.TestCase):
    def test_original_names_accents_and_extensions_are_supported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder, name in [('couvertures','Ségur.JPG'),('photos','Valérie Lemoine.jpeg'),('presse','Article Ouest-France 28 avril 2026.JPG')]:
                target = root / 'dist/assets' / folder / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b'test-fixture')
            books = [{'number':3,'title':'La Comtesse de Ségur','slug':'la-comtesse-de-segur','cover':''}]
            apply_book_images(books,root)
            self.assertEqual(unquote(books[0]['cover']),'/assets/couvertures/Ségur.JPG')
            self.assertEqual(len(find_images(root,'photos','Valerie Lemoine')),1)
            self.assertEqual(len(press_images(root,'ouest-france')),1)

    def test_explicit_cover_is_preserved_and_both_flaneur_files_are_used(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            folder=root/'dist/assets/presse';folder.mkdir(parents=True)
            for name in ['Article magazine Le Flaneur 30 juin page 1.jpg','Article magazine Le Flaneur 30 juin page 2.jpg']:
                (folder/name).write_bytes(b'test-fixture')
            self.assertEqual(len(press_images(root,'flaneur')),2)
            books=[{'number':1,'title':'Arthur Rimbaud','slug':'arthur-rimbaud','cover':'https://example.org/existing.webp'}]
            apply_book_images(books,root)
            self.assertEqual(books[0]['cover'],'https://example.org/existing.webp')

    def test_external_bonus_page_is_not_treated_as_an_mp3(self):
        with tempfile.TemporaryDirectory() as directory:
            url='https://www.lescompagnonsderoute.com/les-bonus-de-la-collection-lpgrapp'
            result=audio_body({'bonus_page_url':url},Path(directory))
            self.assertIn('href="'+url+'"',result)
            self.assertNotIn('<audio',result)


if __name__=='__main__':
    unittest.main()
