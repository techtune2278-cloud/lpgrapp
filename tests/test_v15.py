import unittest
from pathlib import Path
from html.parser import HTMLParser
ROOT=Path(__file__).resolve().parents[1]
class Reader(HTMLParser):
 def __init__(self):super().__init__();self.text=[];self.attrs=[]
 def handle_data(self,data):self.text.append(data)
 def handle_starttag(self,tag,attrs):self.attrs.append((tag,dict(attrs)))
def read(route):
 text=(ROOT/'dist'/route/'index.html').read_text();p=Reader();p.feed(text);return text,' '.join(p.text),p
class V15Tests(unittest.TestCase):
 def test_new_subscription_copy_prices_and_removed_sentences(self):
  markup,text,p=read('offrir')
  for phrase in ['Choisir vos livres','Mois et composition des colis','colis de 1 à 3 livres','virement']:
   self.assertIn(phrase,text)
  for route in ['offrir','cgv','livraison','faq']:
   markup,text,_=read(route)
   for phrase in ['120 €','30 € de port','au même prix','Une offre simple, sans remise','Aucune remise sur les livres (prix unique du livre)']:
    self.assertNotIn(phrase,text)
 def test_new_pictures_and_bookstores_are_present(self):
  for route,alt in [('offrir','Une petite fille'),('livres','Les dix livres'),('fabrique-en-france','tranches colorées')]:
   _,_,p=read(route);self.assertTrue(any(tag=='img' and alt in attrs.get('alt','') for tag,attrs in p.attrs))
  markup,text,p=read('ou-nous-trouver');self.assertLess(text.index('Chez votre libraire'),text.index('Salons et dédicaces'))
  for value in ['16 place de la Liberté','22260 Pontrieux','15 Rue des Chapeliers','22300 Lannion','02 96 92 95 62','02 96 37 40 53']:self.assertIn(value,text)
  for url in ['tel:0296929562','tel:0296374053']:self.assertTrue(any(tag=='a' and attrs.get('href')==url for tag,attrs in p.attrs))
 def test_centered_quote_and_correct_museum_caption(self):
  for route in ['professionnels','presse']:
   markup,text,_=read(route);self.assertIn('nothomb-quote quote-centered',markup);self.assertNotIn('Courte citation à ajouter.',text)
  _,text,_=read('professionnels');self.assertIn('Le livre Jules Verne dans la boutique du musée de Nantes.',text);self.assertNotIn('musée Jules Verne',text)
