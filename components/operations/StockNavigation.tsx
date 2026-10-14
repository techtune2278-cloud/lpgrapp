"use client";
import Link from 'next/link';
import {usePathname} from 'next/navigation';
export default function StockNavigation(){const path=usePathname();return <nav className="toolbar stock-navigation" aria-label="Opérations de stock">{[['/mouvements','Dons et pertes'],['/prets','Prêts et retours'],['/depot-vente','Dépôts-vente']].map(([href,label])=><Link key={href} href={href} aria-current={path===href?'page':undefined} className={`btn ${path===href?'primary':'secondary'}`}>{label}</Link>)}</nav>}
