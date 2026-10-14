import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { createClient } from '@supabase/supabase-js';
const sourcePath = path.resolve(process.env.LEGACY_EXTRACT_PATH ?? './migration/private-workbook-extract.json');
const source = JSON.parse(await readFile(sourcePath, 'utf8'));
const sourceFile = source.source_file ?? path.basename(sourcePath);
const url = process.env.SUPABASE_URL, serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !serviceKey) { console.error('Définissez localement SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY.'); process.exit(1); }
if (!Array.isArray(source.sheets)) { console.error('Format source invalide : le champ sheets est absent.'); process.exit(1); }
const sb = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
const size=150; let batch=[], count=0, skipped=0;
async function flush(){if(!batch.length)return;const{error}=await sb.from('legacy_import_rows').upsert(batch,{onConflict:'source_file,sheet_name,row_number'});if(error)throw new Error(`Import interrompu : ${error.message}`);count+=batch.length;batch=[];console.log(`${count} lignes sources conservées`)}
for(const sheet of source.sheets){for(let i=0;i<(sheet.values??[]).length;i++){const values=sheet.values[i]??[],formulas=(sheet.formulas??[])[i]??[];if([...values,...formulas].every(v=>v===null||v===undefined||v==='')){skipped++;continue;}const hash=JSON.stringify({sheet:sheet.name,row:i+1,values,formulas});batch.push({source_file:sourceFile,sheet_name:sheet.name,row_number:i+1,source_address:sheet.address??null,row_values:values,row_formulas:formulas,row_hash:createHash('sha256').update(hash).digest('hex')});if(batch.length>=size)await flush();}}
await flush();console.log(`Terminé : ${count} lignes non vides importées, ${skipped} lignes vides ignorées. Aucun mouvement métier créé automatiquement.`);
