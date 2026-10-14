import {execFileSync} from 'node:child_process';
const files=execFileSync('git',['ls-files','-z'],{encoding:'utf8'}).split('\0').filter(Boolean);
const forbidden=files.filter(p=>/(^|\/)(private-workbook|private-seed|reprise-excel-privee|02_IMPORT_PRIVE|PRIVE_NE_PAS_PUBLIER)|(^|\/)\.env(\.|$)|\.(xlsx|xls|csv|zip)$/i.test(p)&&!/(^|\/)\.env\.example$/.test(p));
if(forbidden.length){console.error('Fichiers privés ou exports suivis par Git :\n'+forbidden.join('\n'));console.error('Retirez-les du suivi Git, vérifiez leur historique et conservez leurs copies dans votre stockage privé.');process.exitCode=1}else console.log('Aucun fichier privé attendu ni export de données trouvé dans les chemins suivis. Ce contrôle ne recherche pas les secrets dans le contenu ou les anciens commits.');
