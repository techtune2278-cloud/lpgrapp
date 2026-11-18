// Compile avec un Python et un Pillow isolés des paquets injectés par l'hébergeur.
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const python = process.env.LPGR_PYTHON || (process.platform === 'win32' ? 'python' : 'python3');
const venvPython = resolve(root, '.build-venv', process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python');
const env = { ...process.env };
// Vercel peut fournir un PYTHONPATH vers des paquets d'un autre interpréteur.
delete env.PYTHONPATH;
delete env.PYTHONHOME;

function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, env, stdio: 'inherit' });
  if (result.error) {
    console.error(`Impossible de lancer ${command} : ${result.error.message}`);
    process.exit(1);
  }
  if (result.status !== 0) process.exit(result.status || 1);
}

// Recréer aussi un éventuel environnement conservé dans le cache Vercel.
// -I ignore les chemins Python injectés et les paquets utilisateur.
run(python, ['-I', '-m', 'venv', '--clear', '.build-venv']);
run(venvPython, ['-I', '-m', 'pip', '--isolated', 'install', '--disable-pip-version-check', '--only-binary=:all:', '-r', 'requirements.txt']);
// Importer PIL seul ne vérifie pas son extension native _imaging.
run(venvPython, ['-I', '-c', [
  'import PIL',
  'from PIL import Image, ImageDraw, ImageFont, ImageOps, features',
  'assert 12 <= int(PIL.__version__.split(".")[0]) < 13, "Version Pillow incompatible"',
  'assert features.check("webp"), "Support WebP absent"',
  'Image.new("RGB", (1, 1)).tobytes()',
  'print("Pillow et WebP valides dans l’environnement de compilation isolé.")',
].join('; ')]);
// Le générateur a besoin des modules du projet, ajoutés explicitement en mode -I.
run(venvPython, ['-I', '-c', 'import runpy, sys; from pathlib import Path; root = Path(sys.argv[1]); sys.path.insert(0, str(root)); runpy.run_path(str(root / "build.py"), run_name="__main__")', root]);
