import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from xml.etree import ElementTree
from html.parser import HTMLParser
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from publication import site_url,public_copy
from media_pipeline import MediaPipeline
from content_features import editorial_lists

class Metadata(HTMLParser):
    def __init__(self):super().__init__();self.meta={};self.h1=0;self.canonical='';self.images=[]
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if tag=='meta':self.meta[attrs.get('name',attrs.get('property'))]=attrs.get('content')
        if tag=='h1':self.h1+=1
        if tag=='link' and attrs.get('rel')=='canonical':self.canonical=attrs['href']
        if tag=='img':self.images.append(attrs)

class PublicationTests(unittest.TestCase):
    def test_public_pages_have_unique_metadata_real_og_and_json_graph(self):
        report=json.loads((ROOT/'seo-report.json').read_text());titles=set();descriptions=set()
        for page in report['pages']:
            value=(ROOT/'dist'/page['route']/'index.html').read_text();p=Metadata();p.feed(value)
            self.assertEqual(p.h1,1,page['route']);self.assertEqual(p.canonical,page['canonical'])
            self.assertTrue(p.meta['twitter:card']);self.assertTrue(p.meta['og:image'].startswith(report['site_url']+'/'))
            with Image.open(ROOT/'dist'/page['sharing'].lstrip('/')) as image:self.assertEqual(image.size,(1200,630))
            import re
            graph=json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>',value).group(1))['@graph']
            self.assertTrue(any(e['@type']=='WebSite' for e in graph));self.assertTrue(any(e['@type']=='WebPage' for e in graph))
            if page['book']:
                book=next(e for e in graph if isinstance(e.get('@type'),list) and 'Book' in e['@type'])
                self.assertEqual(len(book['author']),2)
                if 'À paraître' in page['description']:self.assertNotIn('offers',book)
            if page['index']:
                self.assertTrue(p.meta['robots'].startswith('index,follow'));self.assertNotIn(page['title'],titles);self.assertNotIn(page['description'],descriptions)
                titles.add(page['title']);descriptions.add(page['description'])
            else:self.assertTrue(p.meta['robots'].startswith('noindex,'))
            for image in p.images:
                self.assertTrue(image.get('alt'));self.assertIn('width',image);self.assertIn('height',image)
    def test_sitemap_matches_only_public_canonicals_and_robots_unblocks(self):
        report=json.loads((ROOT/'seo-report.json').read_text());actual=ElementTree.parse(ROOT/'dist/sitemap.xml')
        urls={e.text for e in actual.findall('.//{*}loc')};self.assertEqual(urls,{p['canonical'] for p in report['pages'] if p['index']})
        robots=(ROOT/'dist/robots.txt').read_text();self.assertNotIn('Disallow: /\n',robots);self.assertIn('Sitemap: '+report['site_url']+'/sitemap.xml',robots)
        self.assertFalse(any('/atelier/' in u or '/actualites/' in u for u in urls))
    def test_domain_config_and_editorial_notes(self):
        with patch.dict(os.environ,{'SITE_URL':'https://books.example.org/'}):self.assertEqual(site_url({}),'https://books.example.org')
        with patch.dict(os.environ,{'SITE_URL':'https://example.org/path'}):
            with self.assertRaises(ValueError):site_url({})
        self.assertEqual(public_copy('Le livre [note interne].'),'Le livre.')
    def test_local_images_create_webp_srcset_without_mutating_originals(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);asset=root/'dist/assets/couvertures/Été.jpg';asset.parent.mkdir(parents=True);Image.new('RGB',(720,900),'red').save(asset);raw=asset.read_bytes()
            pipe=MediaPipeline(root);markup=pipe.optimize_html('<img class="real-cover" src="/assets/couvertures/%C3%89t%C3%A9.jpg" alt="Été">');p=Metadata();p.feed(markup);image=p.images[0]
            self.assertTrue(image['src'].endswith('.webp'));self.assertIn('srcset',image);self.assertEqual(image['loading'],'eager');self.assertEqual(asset.read_bytes(),raw)
    def test_incomplete_events_are_omitted_and_completed_events_create_schema(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);entries={'books':[],'events':[{'title':'Sans date'},{'slug':'rencontre','title':'Rencontre','start_date':'2026-12-10','place':'Bibliothèque','city':'Montaut'}]};(root/'content.json').write_text(json.dumps(entries));calls=[]
            import html
            ctx={'ROOT':root,'SITE_URL':'https://example.org','settings':{},'page':lambda *a,**k:calls.append((a,k)),'esc':lambda s:html.escape(str(s),quote=True),'heading':lambda k,t:'<h1>'+t+'</h1>'}
            cards,_=editorial_lists(ctx);self.assertEqual(len(calls),1);self.assertNotIn('Sans date',cards);self.assertEqual(calls[0][1]['structured']['@type'],'Event');self.assertEqual(calls[0][1]['structured']['startDate'],'2026-12-10')

if __name__=='__main__':unittest.main()
