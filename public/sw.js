/* Installability shell only. Never cache authenticated API or financial/inventory data. */
const CACHE_NAME="collection-livres-shell-v1";
self.addEventListener("install",event=>event.waitUntil((async()=>{const c=await caches.open(CACHE_NAME);await c.addAll(["/icon.svg","/icon-192.png","/icon-512.png"]);await self.skipWaiting()})()));
self.addEventListener("activate",event=>event.waitUntil((async()=>{for(const key of await caches.keys())if(key!==CACHE_NAME)await caches.delete(key);await self.clients.claim()})()));
self.addEventListener("fetch",event=>{const r=event.request;if(r.method!=="GET")return;const u=new URL(r.url);if(u.origin!==self.location.origin||u.pathname.startsWith("/rest/")||u.pathname.startsWith("/auth/"))return;if(!["image","font"].includes(r.destination))return;event.respondWith(caches.match(r).then(hit=>hit||fetch(r))) });
