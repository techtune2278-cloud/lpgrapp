import json,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class NovemberTests(unittest.TestCase):
 def test_release_calendar_and_prices(self):
  d=json.loads((ROOT/'dist/content.json').read_text());books={b['number']:b for b in d['books']}
  for n in [10,20,30]:self.assertEqual(books[n]['price'],16.5)
  for n in [12,13,14,15]:self.assertEqual(books[n]['release_month'],'2027-04');self.assertTrue(books[n]['subscription_payable'])
  for n in [16,17,18,19]:self.assertEqual(books[n]['release_month'],'2027-10');self.assertTrue(books[n]['subscription_payable'])
  self.assertEqual(books[10]['release_month'],'2026-12');self.assertEqual(books[20]['release_month'],'2027-12')
 def test_legal_documents_and_private_admin(self):
  cgv=(ROOT/'dist/cgv/index.html').read_text()
  for n in range(1,18):self.assertIn('ARTICLE '+str(n)+' —',cgv)
  self.assertIn('dernier bien',cgv);self.assertIn('virement',cgv);self.assertNotIn('plus de trois mois',cgv)
  admin=(ROOT/'dist/administration/index.html').read_text();self.assertIn('noindex,follow',admin);self.assertIn('admin-login-form',admin)
  self.assertNotIn('/administration/',(ROOT/'dist/index.html').read_text());self.assertTrue((ROOT/'dist/assets/documents/cgv-et-retractation.txt').is_file())
  self.assertTrue((ROOT/'dist/retractation/index.html').is_file())
 def test_both_authors_and_updated_copy(self):
  html=(ROOT/'dist/auteurs/index.html').read_text();self.assertIn('Hervélina Vyskoc',html);self.assertIn('Valérie Lemoine',html)
  html=(ROOT/'dist/index.html').read_text();self.assertIn('livres illustrés',html);self.assertIn('lire un véritable extrait',html)
  html=(ROOT/'dist/professionnels/index.html').read_text();self.assertIn('<br><cite>— Amélie Nothomb',html)
  html=(ROOT/'dist/offrir/index.html').read_text();self.assertIn('name="terms"',html);self.assertIn('name="acknowledge"',html);self.assertIn('name="newsletter"',html)
