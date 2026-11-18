import json
import tempfile
import unittest
from pathlib import Path
from bonus_audio import audio_filename, publish_audio, render_bonus


class BonusAudioTests(unittest.TestCase):
    def test_public_files_are_copied_and_removed_files_disappear(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'public/audio'
            out = root / 'dist'
            source.mkdir(parents=True)
            out.mkdir()
            (source / 'lecture Molière.mp3').write_bytes(b'audio')
            (source / 'private.txt').write_text('non publié')
            (source / 'sous-dossier').mkdir()
            manifest = publish_audio(root, out)
            self.assertEqual(manifest, [{'name': 'lecture Molière.mp3', 'url': '/audio/lecture%20Moli%C3%A8re.mp3'}])
            self.assertEqual((out / 'audio/lecture Molière.mp3').read_bytes(), b'audio')
            (source / 'lecture Molière.mp3').unlink()
            self.assertEqual(publish_audio(root, out), [])
            self.assertFalse((out / 'audio/lecture Molière.mp3').exists())

    def test_local_reader_missing_file_external_link_and_escaping(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'public/audio/lecture.mp3'
            path.parent.mkdir(parents=True)
            bonus = dict(author='Molière & amis', title='Le "texte"', type='audio', url='/audio/lecture.mp3')
            missing = render_bonus(bonus, root)
            self.assertNotIn('<audio', missing)
            path.write_bytes(b'audio')
            player = render_bonus(bonus, root)
            self.assertIn('<audio controls preload="none"', player)
            self.assertIn('src="/audio/lecture.mp3"', player)
            self.assertIn('<strong>Molière &amp; amis</strong>', player)
            self.assertIn('aria-label="Le &quot;texte&quot;"', player)
            film = render_bonus({**bonus, 'type': 'video', 'url': 'https://www.youtube.com/watch?v=abc'}, root)
            self.assertIn('target="_blank" rel="noopener noreferrer"', film)
            self.assertNotIn('<audio', film)
            self.assertEqual(render_bonus({**bonus, 'url': 'javascript:alert(1)'}, root), '')
            self.assertIn('Accéder au bonus', render_bonus({**bonus, 'url': 'https://example.org/ancien-bonus'}, root))

    def test_local_path_limits(self):
        for url in ['/audio/../secret.mp3', '/audio/%2e%2e%2fsecret.mp3', '/audio/test.mp3?q=1', '//evil.test/a.mp3', '/audio/test.exe']:
            self.assertIsNone(audio_filename(url))
        self.assertEqual(audio_filename('/audio/lecture%20Moli%C3%A8re.mp3'), 'lecture Molière.mp3')


if __name__ == '__main__':
    unittest.main()
