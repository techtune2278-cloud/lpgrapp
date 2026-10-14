import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { createClient } from '@supabase/supabase-js';

async function main() {
  // Read local migration settings before making any Supabase request.
  // Existing shell environment variables take precedence over .env.migration.
  try {
    const envText = await readFile(path.resolve('.env.migration'), 'utf8');
    for (const line of envText.split(/\r?\n/)) {
      const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
      if (!match || match[1].startsWith('#') || process.env[match[1]]) continue;
      let value = match[2];
      if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
        value = value.slice(1, -1);
      }
      process.env[match[1]] = value;
    }
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
  }

  const url = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) {
    throw new Error('Renseignez SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY dans le fichier local .env.migration. N’utilisez pas la clé anon/publishable.');
  }

  const sourcePath = path.resolve(process.env.LEGACY_EXTRACT_PATH ?? './migration/private-workbook-extract.json');
  let source;
  try {
    source = JSON.parse(await readFile(sourcePath, 'utf8'));
  } catch (error) {
    if (error?.code === 'ENOENT') {
      throw new Error(`Fichier source introuvable : ${sourcePath}. Extrayez l’archive privée dans la racine du projet.`);
    }
    throw error;
  }
  const sourceFile = source.source_file ?? path.basename(sourcePath);
  if (!Array.isArray(source.sheets)) throw new Error('Format source invalide : le champ sheets est absent.');

  const sb = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const size = 150;
  let batch = [];
  let count = 0;
  let skipped = 0;

  async function flush() {
    if (!batch.length) return;
    const { error } = await sb.from('legacy_import_rows').upsert(batch, {
      onConflict: 'source_file,sheet_name,row_number',
    });
    if (error) {
      if (error.code === '42501' || /permission denied/i.test(error.message ?? '')) {
        throw new Error(
          'Supabase refuse l’écriture dans public.legacy_import_rows. Dans SQL Editor, exécutez CORRECTIF_DROITS_IMPORT_LEGACY.sql. Vérifiez aussi que .env.migration utilise bien la clé secrète/service_role du projet, et non la clé anon/publishable. Si SUPABASE_SERVICE_ROLE_KEY est définie dans PowerShell, elle prend priorité sur .env.migration.'
        );
      }
      throw new Error(`Import interrompu (${error.code ?? 'sans code'}) : ${error.message}`);
    }
    count += batch.length;
    batch = [];
    console.log(`${count} lignes sources conservées`);
  }

  for (const sheet of source.sheets) {
    for (let i = 0; i < (sheet.values ?? []).length; i++) {
      const values = sheet.values[i] ?? [];
      const formulas = (sheet.formulas ?? [])[i] ?? [];
      if ([...values, ...formulas].every(value => value === null || value === undefined || value === '')) {
        skipped++;
        continue;
      }
      const rowPayload = JSON.stringify({ sheet: sheet.name, row: i + 1, values, formulas });
      batch.push({
        source_file: sourceFile,
        sheet_name: sheet.name,
        row_number: i + 1,
        source_address: sheet.address ?? null,
        row_values: values,
        row_formulas: formulas,
        row_hash: createHash('sha256').update(rowPayload).digest('hex'),
      });
      if (batch.length >= size) await flush();
    }
  }

  await flush();
  console.log(`Terminé : ${count} lignes non vides importées, ${skipped} lignes vides ignorées.`);
  console.log('Les données sont conservées dans la zone de reprise. Aucun mouvement métier n’a été créé automatiquement.');
}

main().catch(error => {
  console.error(`\nÉCHEC DE L’IMPORT : ${error?.message ?? error}`);
  process.exitCode = 1;
});
