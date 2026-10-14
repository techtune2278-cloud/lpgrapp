"use client";
import OpeningBalances from '@/components/operations/OpeningBalances';
import WorkbookHistory from '@/components/workbook/WorkbookHistory';
import WorkbookStock from '@/components/workbook/WorkbookStock';
import WorkbookSources from '@/components/workbook/WorkbookSources';
export default function WorkbookRecovery(){return <>
 <div className="page-head"><div><div className="eyebrow-small">REPRISE DES DONNÉES</div><h1>Reprise Excel</h1><p>Retrouvez le dernier classeur, rapprochez les commandes et préparez le stock d’ouverture.</p></div></div>
 <div className="notice info">Les données sources sont conservées dans une version identifiée. Les corrections sont enregistrées séparément ; aucun historique ne retire de nouveau des exemplaires du stock.</div>
 <OpeningBalances/><WorkbookSources/><WorkbookHistory/><WorkbookStock prepare/>
 </>}
