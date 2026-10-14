import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "LPGR’APP — Les plus grands racontés aux plus petits",
    short_name: "LPGR’APP",
    description: "Ventes, stocks, inventaires, prêts et dépôts-vente de la collection.",
    start_url: "/",
    display: "standalone",
    background_color: "#f5f6f2",
    theme_color: "#214b3b",
    icons: [
      { src: "/icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any" },
      { src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "maskable" },
      { src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
