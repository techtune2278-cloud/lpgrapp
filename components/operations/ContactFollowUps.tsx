"use client";
import Link from 'next/link';
import {useCallback,useEffect,useState} from 'react';
import {getSupabase} from '@/lib/supabase';
import {today,dateFr,errorMessage} from '@/lib/format';
type Row={id:string;name:string;follow_up_on:string;follow_up_reason:string|null;ntfy_enabled:boolean};
export default function ContactFollowUps({revision=0,onChanged}:{revision?:number;onChanged?:()=>void}){
 const sb=getSupabase();const[rows,setRows]=useState<Row[]>([]),[total,setTotal]=useState(0),[error,setError]=useState(''),[busy,setBusy]=useState(false);
 const load=useCallback(async()=>{if(!sb)return;const r=await sb.from('contacts').select('id,name,follow_up_on,follow_up_reason,ntfy_enabled',{count:'exact'}).eq('is_active',true).not('follow_up_on','is',null).order('follow_up_on').order('id').limit(8);if(r.error)setError(errorMessage(r.error));else{setRows(r.data??[]);setTotal(r.count??0);setError('')}},[sb]);
 useEffect(()=>{void load();const refresh=()=>{if(document.visibilityState==='visible')void load()};document.addEventListener('visibilitychange',refresh);const timer=window.setInterval(refresh,60000);return()=>{document.removeEventListener('visibilitychange',refresh);window.clearInterval(timer)}},[load,revision]);
 async function done(id:string){if(!sb)return;setBusy(true);setError('');const r=await sb.from('contacts').update({follow_up_on:null,follow_up_reason:null,ntfy_enabled:false}).eq('id',id).select('id').single();if(r.error)setError(errorMessage(r.error));else{await load();onChanged?.()}setBusy(false)}
 if(!rows.length&&!error)return null;
 return <section className="panel workbook-section"><div className="panel-head"><div><h2>Contacts à suivre</h2><p>Relances datées directement dans les fiches contacts.</p></div><Link className="btn secondary" href="/contacts">Contacts</Link></div><div className="panel-body">{error&&<div className="notice error">{error}</div>}{rows.map(r=><div className="list-row" key={r.id}><span className={`badge ${r.follow_up_on<today()?'red':r.follow_up_on===today()?'amber':'blue'}`}>{dateFr(r.follow_up_on)}</span><div className="list-row-main"><strong>{r.name}</strong><span>{r.follow_up_reason||'Prendre contact'}{r.ntfy_enabled?' · Rappel ntfy demandé':''}</span></div><button className="btn secondary small" disabled={busy} onClick={()=>void done(r.id)}>Relance faite</button></div>)}{total>8&&<p className="tiny muted">Les 8 premières échéances sur {total} sont affichées. Les autres restent consultables dans Contacts.</p>}</div></section>;
}
