import type { Metadata,Viewport } from "next"; import "./globals.css";
export const metadata:Metadata={title:"Collection Livres | Gestion",description:"Gestion des ventes, des stocks et des mouvements de la collection.",applicationName:"Collection Livres",manifest:"/manifest.webmanifest"};
export const viewport:Viewport={themeColor:"#214b3b",width:"device-width",initialScale:1};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="fr"><body>{children}</body></html>}
