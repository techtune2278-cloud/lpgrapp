"""Publication des audios locaux et rendu des bonus sans service tiers."""
import json
import shutil
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit
from html import escape

EXTENSIONS = {'.mp3', '.m4a', '.wav', '.ogg', '.aac', '.flac', '.webm'}


def audio_filename(url):
    if not isinstance(url, str) or not url.startswith('/audio/'):
        return None
    parsed = urlsplit(url)
    name = unquote(parsed.path.removeprefix('/audio/'))
    if parsed.query or parsed.fragment or not name or any(c in name for c in '/\\\x00') or name in {'.', '..'}:
        return None
    return name if Path(name).suffix.lower() in EXTENSIONS else None


def publish_audio(root, out):
    source = root / 'public' / 'audio'
    target = out / 'audio'
    # Le répertoire de sortie est généré ; la source reste public/audio.
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True, exist_ok=True)
    files = []
    if source.is_dir():
        for path in sorted(source.iterdir()):
            if not path.is_file() or path.is_symlink() or path.suffix.lower() not in EXTENSIONS:
                continue
            shutil.copy2(path, target / path.name)
            files.append({'name': path.name, 'url': '/audio/' + quote(path.name)})
    (out / 'audio-files.json').write_text(json.dumps(files, ensure_ascii=False), encoding='utf-8')
    return files


def render_bonus(bonus, root):
    url = bonus.get('url', '')
    local = audio_filename(url)
    audio = bonus.get('type') == 'audio'
    if local and audio:
        if (root / 'public' / 'audio' / local).is_file():
            player = '<details class="bonus-player"><summary>Écouter le bonus</summary><audio controls preload="none" aria-label="'+escape(bonus['title'], quote=True)+'" src="/audio/'+quote(local)+'">Votre navigateur ne permet pas de lire cet audio.</audio><p class="bonus-audio-error" role="status" hidden>Ce fichier audio est momentanément indisponible. Réessayez plus tard.</p></details>'
        else:
            player = '<p class="muted">Ce fichier audio sera disponible prochainement.</p>'
    else:
        parsed = urlsplit(url)
        if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
            return ''
        # Compatibilité avec les bonus existants, publiés avant les lecteurs locaux.
        label = 'Accéder au bonus' if audio else 'Voir le film'
        player = '<a class="button text" href="'+escape(url, quote=True)+'" target="_blank" rel="noopener noreferrer">'+label+' ↗</a>'
    icon = '♫' if audio else '🎞'
    return '<article class="bonus-card"><span class="sound-icon" aria-hidden="true">'+icon+'</span><div><h2><strong>'+escape(bonus['author'])+'</strong></h2><p>'+escape(bonus['title'])+'</p>'+player+'</div></article>'
