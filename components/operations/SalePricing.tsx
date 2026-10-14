"use client";
import {useEffect,useState} from 'react';
import {getSupabase} from '@/lib/supabase';
import {euro} from '@/lib/format';
import type {Book,SaleItemDraft} from '@/lib/types';
export default function SalePricing({items,books,onShipping,onReduced}:{items:SaleItemDraft[];books:Book[];onShipping:(n:number)=>void;onReduced:()=>void}){
 const sb=getSupabase();const[rates,setRates]=useState<{zone:string;quantity:number;amount:number}[]>([]),[minimum,setMinimum]=useState(5),[zone,setZone]=useState('France');
 useEffect(()=>{let active=true;if(!sb)return;void(async()=>{const[r,s]=await Promise.all([sb.from('shipping_rates').select('zone,quantity,amount').eq('is_active',true),sb.from('collection_settings').select('reduced_min_quantity').single()]);if(!active)return;if(!r.error)setRates(r.data??[]);if(s.data)setMinimum(s.data.reduced_min_quantity)})();return()=>{active=false}},[sb]);
 const quantity=items.filter(i=>i.book_id).reduce((n,i)=>n+Number(i.quantity||0),0),rate=rates.find(r=>r.zone===zone&&r.quantity===quantity),canReduced=quantity>=minimum&&items.filter(i=>i.book_id).every(i=>books.find(b=>b.id===i.book_id)?.price_reduced!=null);
 return <div className="notice info"><div className="head-actions"><label>Destination<select className="select" value={zone} onChange={e=>setZone(e.target.value)}>{['France','Europe','US'].map(z=><option key={z}>{z}</option>)}</select></label><span>{quantity} livre(s) · {rate?`Port proposé : ${euro(rate.amount)}`:'Pas de barème correspondant : saisir le port manuellement.'}</span>{rate&&<button type="button" className="btn secondary" onClick={()=>onShipping(Number(rate.amount))}>Appliquer ce port</button>}{canReduced&&<button type="button" className="btn secondary" onClick={onReduced}>Appliquer les prix réduits</button>}</div><small>Les propositions ne remplacent pas vos montants saisis sans action de votre part.</small></div>;
}
