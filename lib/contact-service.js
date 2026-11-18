'use strict';

const { createHash } = require('node:crypto');
const MAX_BYTES = 24000;
const EMAIL = /^[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+$/;
const PROFILES = new Set(['Un particulier', 'Une librairie', 'Une bibliothèque ou médiathèque', 'Un musée ou une maison d’écrivain', 'Une école ou Alliance française', 'Un organisateur de salon', 'Un journaliste', 'Autre', 'Librairie', 'Bibliothèque ou médiathèque', 'Musée ou maison d’écrivain', 'Alliance française', 'École', 'Salon ou marché', 'Presse']);

function isConfigured(env) {
  return Boolean(env.BREVO_API_KEY && EMAIL.test(env.CONTACT_TO_EMAIL || '') && EMAIL.test(env.CONTACT_FROM_EMAIL || ''));
}

function createContactService({ env = process.env, fetchImpl = globalThis.fetch, now = Date.now } = {}) {
  env = { ...env, CONTACT_TO_EMAIL: env.CONTACT_TO_EMAIL || 'contact@lesplusgrandsracontes.fr' };
  // Lightweight per-instance throttle. It is deliberately not presented as a global quota.
  const attempts = new Map();
  return async function handle({ method, headers = {}, body, ip = '' }) {
    const reply = (status, data, extraHeaders = {}) => ({ status, data, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', ...extraHeaders } });
    if (method === 'GET') return reply(200, { enabled: isConfigured(env) });
    if (method !== 'POST') return reply(405, { error: 'Méthode non autorisée.' }, { Allow: 'GET, POST' });

    // Accept same-origin browser submissions only. No client-supplied destination is used.
    let source;
    try { source = new URL(headers.origin || ''); } catch { return reply(403, { error: 'Origine de la demande non autorisée.' }); }
    const host = headers.host;
    if (!host || source.host !== host || !['http:', 'https:'].includes(source.protocol)) return reply(403, { error: 'Origine de la demande non autorisée.' });
    if (!(headers['content-type'] || '').toLowerCase().startsWith('application/json')) return reply(415, { error: 'Format de message non accepté.' });
    const declaredSize = Number(headers['content-length']);
    if (declaredSize > MAX_BYTES) return reply(413, { error: 'Votre message est trop volumineux.' });
    let data;
    try {
      if (typeof body === 'string' && Buffer.byteLength(body) > MAX_BYTES) return reply(413, { error: 'Votre message est trop volumineux.' });
      data = typeof body === 'string' ? JSON.parse(body) : body;
      if (Buffer.byteLength(JSON.stringify(data) || '') > MAX_BYTES) return reply(413, { error: 'Votre message est trop volumineux.' });
    } catch { return reply(400, { error: 'Message illisible. Vérifiez votre saisie.' }); }
    if (!data || typeof data !== 'object' || Array.isArray(data)) return reply(400, { error: 'Message invalide.' });
    if (typeof data.website === 'string' && data.website.trim()) return reply(400, { error: 'Demande non acceptée. Veuillez réessayer.' });
    const bounds = { nom: [1, 120], email: [3, 254], sujet: [1, 160], message: [10, 5000] };
    for (const [field, [min, max]] of Object.entries(bounds)) {
      if (typeof data[field] !== 'string' || data[field].trim().length < min || data[field].trim().length > max) return reply(400, { error: 'Vérifiez le nom, l’e-mail, le sujet et le message (10 caractères minimum).' });
    }
    if (data.ville !== undefined && (typeof data.ville !== 'string' || data.ville.length > 160 || /[\r\n]/.test(data.ville))) return reply(400, { error: 'Vérifiez le nom de la ville.' });
    if (data.devis !== undefined && typeof data.devis !== 'boolean') return reply(400, { error: 'Vérifiez la demande de devis.' });
    const clean = Object.fromEntries(Object.keys(bounds).map(k => [k, data[k].trim()]));
    if (!EMAIL.test(clean.email) || /[\r\n]/.test(clean.nom + clean.email + clean.sujet) || !PROFILES.has(data.profil) || data.consent !== true) return reply(400, { error: 'Vérifiez vos coordonnées et l’accord d’utilisation des données.' });
    if (!Number.isFinite(data.startedAt) || now() - data.startedAt < 1800 || now() - data.startedAt > 86400000) return reply(400, { error: 'Veuillez patienter un instant, puis réessayer. Si la page est ancienne, rechargez-la.' });
    if (!isConfigured(env)) return reply(503, { error: 'L’envoi est temporairement indisponible. Votre texte est conservé ; vous pouvez télécharger un brouillon.' });

    const time = now();
    for (const [key, bucket] of attempts) if (time >= bucket.reset) attempts.delete(key);
    const key = createHash('sha256').update(ip || clean.email.toLowerCase()).digest('hex');
    const bucket = attempts.get(key) || { count: 0, reset: time + 600000 };
    if (bucket.count >= 5) return reply(429, { error: 'Trop de tentatives. Veuillez réessayer dans quelques minutes.' }, { 'Retry-After': String(Math.ceil((bucket.reset - time) / 1000)) });
    if (attempts.size >= 10000 && !attempts.has(key)) return reply(429, { error: 'L’envoi est momentanément occupé. Réessayez plus tard.' });
    bucket.count += 1;
    attempts.set(key, bucket);

    const payload = {
      sender: { name: env.CONTACT_FROM_NAME || 'Les plus grands racontés', email: env.CONTACT_FROM_EMAIL },
      to: [{ email: env.CONTACT_TO_EMAIL }],
      replyTo: { email: clean.email, name: clean.nom },
      subject: '[Site LPGR] ' + clean.sujet,
      textContent: `Nouvelle demande du site\n\nProfil : ${data.profil}\nNom / structure : ${clean.nom}\nE-mail : ${clean.email}\nVille : ${data.ville || "Non renseignée"}\nDemande de devis : ${data.devis ? "Oui" : "Non"}\n\n${clean.message}\n\nInformations transmises par le formulaire du site.`,
    };
    try {
      const response = await fetchImpl('https://api.brevo.com/v3/smtp/email', {
        method: 'POST', headers: { 'api-key': env.BREVO_API_KEY, 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(payload), signal: AbortSignal.timeout(10000),
      });
      // Only confirmed acceptance by the provider is reported as success.
      if (!response.ok) return reply(502, { error: 'Le service d’envoi n’a pas accepté le message. Votre texte est conservé. Vous pouvez réessayer plus tard.' });
      const result = await response.json();
      if (!result.messageId) return reply(502, { error: 'L’envoi n’a pas pu être confirmé. Votre texte est conservé.' });
      return reply(200, { ok: true, message: 'Votre message a été transmis au service d’envoi. Merci ! Nous vous répondrons par e-mail.' });
    } catch {
      return reply(502, { error: 'Le service d’envoi ne répond pas. Votre texte est conservé. Avant de réessayer, vous pouvez enregistrer un brouillon.' });
    }
  };
}

module.exports = { createContactService, isConfigured };
