import json,re,sys,tempfile,unittest
from pathlib import Path
from html.parser import HTMLParser
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from subscription_content import prepare_catalog,TITLE,DESCRIPTION,H1,INTRO,NEXT,LATER,GROUP,INCLUDED,GUARANTEES
class Reader(HTMLParser):
 def __init__(self):super().__init__();self.text=[];self.attrs=[]
 def handle_data(self,value):self.text.append(value)
 def handle_starttag(self,tag,attrs):self.attrs.append((tag,dict(attrs)))
class V16Tests(unittest.TestCase):
 def test_exact_page_copy_and_metadata(self):
  html=(ROOT/'dist/offrir/index.html').read_text();p=Reader();p.feed(html);text=' '.join(p.text)
  for value in [TITLE,H1,INTRO,INCLUDED,*GUARANTEES]:self.assertIn(value,text)
  meta=next(attrs for tag,attrs in p.attrs if tag=='meta' and attrs.get('name')=='description');self.assertEqual(meta['content'],DESCRIPTION)
  self.assertNotIn('Pack «',text)
  for name in ['nom','email','recipient_name','address','postal_code','city','card_message','terms','acknowledge']:
   self.assertTrue(any(attrs.get('name')==name for _,attrs in p.attrs))
  for tag,attrs in p.attrs:
   if tag=='a' and attrs.get('href','').startswith('/livres/') and attrs.get('target'):
    self.assertEqual(attrs['target'],'_blank');self.assertIn('noopener',attrs['rel'])
 def test_catalog_statuses_dates_and_unpublished_pages(self):
  books=json.loads((ROOT/'dist/content.json').read_text())['books'];self.assertEqual(len([b for b in books if b['status']=='prochain']),10)
  self.assertEqual({b['number'] for b in books if b['status']=='prochain'},{10,12,13,14,15,16,17,18,19,20})
  catalog=(ROOT/'dist/livres/index.html').read_text()
  for book in books:
   self.assertEqual((ROOT/'dist/livres'/book['slug']/'index.html').is_file(),book['has_page'])
   if not book['has_page']:self.assertNotIn('href="/livres/'+book['slug']+'/',catalog)
  self.assertIn('Me prévenir',catalog)
  future=next(b for b in books if b['number']==12);self.assertTrue(future['subscription_payable'])
  future['release_month']='2027-02';prepare_catalog(books);self.assertTrue(future['subscription_payable'])
  future['release_month']='2027-99'
  with self.assertRaises(ValueError):prepare_catalog(books)
 def test_home_purchase_path_and_email(self):
  html=(ROOT/'dist/index.html').read_text();p=Reader();p.feed(html)
  self.assertTrue(any(tag=='a' and attrs.get('href')=='/livres/' for tag,attrs in p.attrs))
  self.assertIn('Offrir un abonnement',html);self.assertIn('Acheter',html)
  for route in ['','contact','mentions-legales','cgv']:
   self.assertIn('contact@lesplusgrandsracontes.fr',(ROOT/'dist'/route/'index.html').read_text())
