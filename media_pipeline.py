"""Optimisation des fichiers locaux et cartes de partage, sans modifier les originaux."""
import base64
import hashlib
import html
import io
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit
from PIL import Image, ImageDraw, ImageFont, ImageOps


class MediaPipeline:
    def __init__(self, root):
        self.root=Path(root)
        self.out=self.root/'dist'
        self.optimized=self.out/'assets/optimized'
        self.sharing=self.out/'assets/sharing'
        self.optimized.mkdir(parents=True,exist_ok=True)
        self.sharing.mkdir(parents=True,exist_ok=True)
        self.cache={}
        self.warnings=[]

    def read_source(self, source):
        if source.startswith('data:image/'):
            header,encoded=source.split(',',1)
            if ';base64' not in header:return None
            raw=base64.b64decode(encoded,validate=True)
            if len(raw)>8*1024*1024:raise ValueError('Image intégrée trop grande')
            return raw
        if not source.startswith('/') or source.startswith('//'):return None
        path=(self.out/unquote(urlsplit(source).path).lstrip('/')).resolve()
        if not path.is_relative_to(self.out.resolve()) or not path.is_file():return None
        if path.suffix.lower() not in {'.jpg','.jpeg','.png','.webp'}:return None
        return path.read_bytes()

    def image(self, source):
        if source in self.cache:return self.cache[source]
        raw=self.read_source(source)
        if raw is None:return None
        try:
            with Image.open(io.BytesIO(raw)) as original:
                im=ImageOps.exif_transpose(original).convert('RGB')
                im.load()
        except Exception as error:
            self.warnings.append('Image non optimisée : '+source[:100]+' ('+type(error).__name__+')')
            return None
        digest=hashlib.sha256(raw+b'lpgr-webp-v1').hexdigest()[:18]
        sizes=[]
        for width in sorted(set(min(im.width,w) for w in [320,640,960,1600])):
            height=max(1,round(im.height*width/im.width))
            target=self.optimized/(digest+'-'+str(width)+'.webp')
            if not target.exists():
                resized=im.resize((width,height),Image.Resampling.LANCZOS)
                resized.save(target,'WEBP',quality=82,method=5)
            sizes.append({'src':'/'+target.relative_to(self.out).as_posix(),'width':width,'height':height})
        result={'sizes':sizes,'width':im.width,'height':im.height,'digest':digest,'image':im}
        self.cache[source]=result
        return result

    def optimize_html(self, markup):
        position=[0]
        def replace(match):
            attrs=dict((name,html.unescape(value)) for name,value in re.findall(r'([\w:-]+)="([^"]*)"',match.group(1)))
            source=attrs.get('src','')
            if source.startswith('/assets/optimized/'):return match.group(0)
            data=self.image(source)
            if not data:return match.group(0)
            cover='real-cover' in attrs.get('class','')
            variants=[v for v in data['sizes'] if v['width']<= (960 if cover else 1600)] or data['sizes'][:1]
            best=variants[-1]
            attrs.update(src=best['src'],width=str(best['width']),height=str(best['height']),decoding='async')
            attrs['srcset']=', '.join(v['src']+' '+str(v['width'])+'w' for v in variants)
            attrs['sizes']=('(max-width: 600px) 90vw, (max-width: 1100px) 45vw, 540px' if 'cover-hero' in attrs.get('class','') else '(max-width: 600px) 44vw, (max-width: 1100px) 23vw, 280px') if cover else '(max-width: 800px) 92vw, 900px'
            attrs['loading']='eager' if position[0]==0 else 'lazy'
            if position[0]==0:attrs['fetchpriority']='high'
            position[0]+=1
            return '<img '+ ' '.join(key+'="'+html.escape(value,quote=True)+'"' for key,value in attrs.items())+'>'
        return re.sub(r'<img\b([^>]*)>',replace,markup)

    def font(self,size,bold=False):
        name='Poppins-SemiBold.ttf' if bold else 'Poppins-Regular.ttf'
        return ImageFont.truetype(str(self.out/'assets/fonts'/name),size)

    def wrap(self,value,font,width):
        draw=ImageDraw.Draw(Image.new('RGB',(1,1)))
        lines=[];line=''
        for word in value.split():
            candidate=(line+' '+word).strip()
            if line and draw.textbbox((0,0),candidate,font=font)[2]>width:
                lines.append(line);line=word
            else:line=candidate
        if line:lines.append(line)
        return lines

    def share_image(self,route,title,cover=''):
        data=self.image(cover) if cover else None
        signature=hashlib.sha256((route+title+(data['digest'] if data else '')+'og-v2').encode()).hexdigest()[:18]
        path=self.sharing/(signature+'.jpg')
        if not path.exists():
            canvas=Image.new('RGB',(1200,630),'#fffcf7');draw=ImageDraw.Draw(canvas)
            draw.rectangle((0,0,22,630),fill='#704575')
            draw.ellipse((900,-130,1350,320),fill='#f7e2ce')
            draw.rounded_rectangle((65,55,260,105),radius=24,fill='#704575')
            draw.text((86,67),'Dès 5 ans',font=self.font(24,True),fill='white')
            width=660 if data else 1040
            display=title.split(' | ')[0]
            size=52
            while size>30 and len(self.wrap(display,self.font(size,True),width))>5:size-=2
            y=145
            for line in self.wrap(display,self.font(size,True),width):
                draw.text((65,y),line,font=self.font(size,True),fill='#38283b');y+=int(size*1.34)
            if data:
                book=data['image'].copy();book.thumbnail((350,420),Image.Resampling.LANCZOS)
                x=1140-book.width;y=160+(420-book.height)//2
                canvas.paste(book,(x,y))
            draw.line((65,540,1135,540),fill='#e4d4dc',width=2)
            draw.text((65,562),'Les plus grands racontés aux plus petits',font=self.font(24),fill='#704575')
            draw.text((65,594),'Sur le Chemin des Arts',font=self.font(17),fill='#766a77')
            canvas.save(path,'JPEG',quality=87,optimize=True)
        return '/'+path.relative_to(self.out).as_posix()

    def icons(self):
        svg='''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="#704575"/><path d="M10 16c8-3 15-2 22 3 7-5 14-6 22-3v32c-8-3-15-2-22 3-7-5-14-6-22-3z" fill="#fffcf7"/><path d="M32 20v29M17 25l8 2M17 32l8 2M40 27l7-2M40 34l7-2" stroke="#ce8fa8" stroke-width="3" fill="none"/></svg>'''
        (self.out/'favicon.svg').write_text(svg,encoding='utf-8')
        im=Image.new('RGB',(180,180),'#704575');draw=ImageDraw.Draw(im)
        draw.rounded_rectangle((30,40,150,140),radius=6,fill='#fffcf7');draw.line((90,42,90,141),fill='#d298b1',width=5)
        im.save(self.out/'apple-touch-icon.png')
        im.save(self.out/'favicon.ico',sizes=[(16,16),(32,32),(48,48)])
