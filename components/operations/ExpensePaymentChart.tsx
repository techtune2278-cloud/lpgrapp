"use client";
import {useCallback,useEffect,useState} from 'react';
import {getSupabase} from '@/lib/supabase';
import {euro,errorMessage} from '@/lib/format';
type Summary={paid:number;to_pay:number;recorded:number;by_payer:{payer:string;amount:number;count:number}[]};
export default function ExpensePaymentChart({revision}:{revision:number}){
 const sb=getSupabase();const[data,setData]=useState<Summary|null>(null),[error,setError]=useState('');
 const load=useCallback(async()=>{if(!sb)return;const r=await sb.rpc('expense_payment_summary');if(r.error)setError(errorMessage(r.error));else{setData(r.data);setError('')}},[sb]);useEffect(()=>{void load()},[load,revision]);
 const max=Math.max(1,...(data?.by_payer.map(p=>Number(p.amount))??[]));
 return <section className="panel workbook-section" aria-label="Répartition des dépenses payées"><div className="panel-head"><div><h2>Qui a payé quoi ?</h2><p>Toutes les dépenses de la base. Seules les dépenses marquées « Payée » alimentent les barres.</p></div><button className="btn secondary small" onClick={()=>void load()}>Actualiser les totaux</button></div>{error&&<div className="notice error">{error}</div>}{data&&<><div className="workbook-metrics"><div><strong>{euro(data.recorded)}</strong><span>dépenses enregistrées, hors annulations</span></div><div><strong>{euro(data.paid)}</strong><span>effectivement payées selon les fiches</span></div><div><strong>{euro(data.to_pay)}</strong><span>encore à payer</span></div></div><div className="panel-body">{!data.by_payer.length?<p>Aucune dépense marquée payée.</p>:data.by_payer.map(p=><div className="payer-row" key={p.payer}><div className="payer-label"><strong>{p.payer}</strong><span>{euro(p.amount)} · {p.count} dépense(s) · {Number(data.paid)>0?Math.round(Number(p.amount)/Number(data.paid)*100):0} %</span></div><div className="payer-track" aria-hidden="true"><div className="payer-bar" style={{width:`${Number(p.amount)/max*100}%`}}/></div></div>)}<p className="tiny muted">Le graphique indique les paiements attribués dans les fiches, sans calculer de dette entre associés. Il est indépendant de la recherche du registre ci-dessous.</p></div></>}</section>;
}
