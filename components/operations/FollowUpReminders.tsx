"use client";
import Link from 'next/link';
import {useCallback,useEffect,useState} from 'react';
import {getSupabase} from '@/lib/supabase';
import {dateFr,errorMessage,today} from '@/lib/format';
type Reminder={id:string;due_date:string;summary:string;next_action:string|null;contact_name:string};
type Data={overdue:number;today:number;next_seven_days:number;total:number;rows:Reminder[]};
export default function FollowUpReminders({revision=0}:{revision?:number}){
 const sb=getSupabase();const[data,setData]=useState<Data|null>(null),[error,setError]=useState('');
 const load=useCallback(async()=>{if(!sb)return;const r=await sb.rpc('commercial_reminders',{p_today:today()});if(r.error)setError(errorMessage(r.error));else{setData(r.data);setError('')}},[sb]);
 useEffect(()=>{void load();const refresh=()=>{if(document.visibilityState==='visible')void load()};document.addEventListener('visibilitychange',refresh);const timer=window.setInterval(refresh,60000);return()=>{document.removeEventListener('visibilitychange',refresh);window.clearInterval(timer)}},[load,revision]);
 return <section className="panel workbook-section"><div className="panel-head"><div><h2>Relances commerciales</h2><p>Actions datées « À faire » ou « En attente ». Alerte dans l’application, sans envoi d’e-mail ni notification du téléphone.</p></div><Link className="btn secondary" href="/crm">Suivi commercial</Link></div>{error&&<div className="notice error">{error}</div>}{data&&<div className="panel-body"><p><strong>{data.overdue}</strong> en retard · <strong>{data.today}</strong> aujourd’hui · <strong>{data.next_seven_days}</strong> dans les 7 prochains jours.</p>{data.rows.map(r=><div className="list-row" key={r.id}><span className={`badge ${r.due_date<today()?'red':r.due_date===today()?'amber':'blue'}`}>{dateFr(r.due_date)}</span><div className="list-row-main"><strong>{r.contact_name}</strong><span>{r.next_action||r.summary}</span></div></div>)}{!data.total&&<p>Aucune relance datée à suivre. Ajoutez une action dans le suivi commercial.</p>}{data.total>8&&<p>Les 8 prochaines échéances sont affichées. Toutes les actions restent dans le suivi commercial.</p>}</div>}</section>;
}
