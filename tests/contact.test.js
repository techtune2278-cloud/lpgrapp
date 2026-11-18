'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createContactService } = require('../lib/contact-service');
const NOW = 1700000000000;
const env = { BREVO_API_KEY: 'mock-key', CONTACT_FROM_EMAIL: 'site@example.org', CONTACT_TO_EMAIL: 'auteurs@example.org' };
const request = (body = {}) => ({
  method: 'POST', headers: { origin: 'https://sitelpgrapp.vercel.app', host: 'sitelpgrapp.vercel.app', 'content-type': 'application/json' }, ip: '127.0.0.1',
  body: { profil: 'Un particulier', nom: 'Camille', email: 'camille@example.org', sujet: 'Une question', message: 'Bonjour, quelle est la prochaine parution ?', consent: true, website: '', startedAt: NOW - 5000, ...body },
});
const accepted = async () => ({ ok: true, json: async () => ({ messageId: 'mock-message' }) });

test('valid message is sent to the fixed recipient with a reply address, without newsletter subscription', async () => {
  let call;
  const service = createContactService({ env, now: () => NOW, fetchImpl: async (url, options) => { call = { url, options }; return accepted(); } });
  const response = await service(request({ to: 'attacker@example.org', message: 'Bonjour <script>alert(1)</script>, merci de votre réponse.' }));
  assert.equal(response.status, 200);
  const sent = JSON.parse(call.options.body);
  assert.equal(call.url, 'https://api.brevo.com/v3/smtp/email');
  assert.deepEqual(sent.to, [{ email: env.CONTACT_TO_EMAIL }]);
  assert.equal(sent.sender.email, env.CONTACT_FROM_EMAIL);
  assert.equal(sent.replyTo.email, 'camille@example.org');
  assert.equal(sent.htmlContent, undefined);
  assert.equal(sent.listIds, undefined);
});

test('unconfigured site reports unavailable and does not send', async () => {
  let called = false;
  const service = createContactService({ env: {}, now: () => NOW, fetchImpl: async () => { called = true; } });
  assert.deepEqual((await service({ method: 'GET' })).data, { enabled: false });
  assert.equal((await service(request())).status, 503);
  assert.equal(called, false);
});

test('cross-origin request, invalid consent and header injection are rejected before sending', async () => {
  let calls = 0;
  const service = createContactService({ env, now: () => NOW, fetchImpl: async () => { calls++; return accepted(); } });
  const cross = request();cross.headers.origin = 'https://other.example';
  assert.equal((await service(cross)).status, 403);
  assert.equal((await service(request({ consent: false }))).status, 400);
  assert.equal((await service(request({ sujet: 'Sujet\r\nBcc: attacker@example.org' }))).status, 400);
  assert.equal((await service(request({ email: '<bad>' }))).status, 400);
  assert.equal(calls, 0);
});

test('honeypot, too-fast submission, malformed and oversized payloads are rejected', async () => {
  const service = createContactService({ env, now: () => NOW, fetchImpl: () => { throw Error('must not send'); } });
  assert.equal((await service(request({ website: 'spam' }))).status, 400);
  assert.equal((await service(request({ startedAt: NOW }))).status, 400);
  assert.equal((await service({ ...request(), body: '{' })).status, 400);
  assert.equal((await service(request({ message: 'x'.repeat(25000) }))).status, 413);
});

test('provider refusal, timeout and ambiguous acceptance never report success', async () => {
  for (const fetchImpl of [async () => ({ ok: false }), async () => { throw Error('network'); }, async () => ({ ok: true, json: async () => ({}) })]) {
    const response = await createContactService({ env, now: () => NOW, fetchImpl })(request());
    assert.equal(response.status, 502);
    assert.notEqual(response.data.ok, true);
  }
});

test('per-instance throttle blocks the sixth attempt, then expires', async () => {
  let time = NOW;
  const service = createContactService({ env, now: () => time, fetchImpl: accepted });
  for (let i = 0; i < 5; i++) assert.equal((await service(request())).status, 200);
  assert.equal((await service(request())).status, 429);
  time += 600001;
  assert.equal((await service(request({ startedAt: time - 5000 }))).status, 200);
});

test('status endpoint exposes availability only, never secrets or recipient', async () => {
  const service = createContactService({ env });
  const response = await service({ method: 'GET' });
  assert.deepEqual(response.data, { enabled: true });
  assert.equal(response.headers['Cache-Control'], 'no-store');
  assert.equal((await service({ method: 'DELETE' })).status, 405);
});

test('professional request preserves city and quote request in the email', async () => {
  let sent;
  const service = createContactService({ env, now: () => NOW, fetchImpl: async (_, options) => { sent = JSON.parse(options.body); return accepted(); } });
  assert.equal((await service(request({ profil: 'Librairie', ville: 'Lannion', devis: true }))).status, 200);
  assert.match(sent.textContent, /Ville : Lannion/);
  assert.match(sent.textContent, /Demande de devis : Oui/);
  assert.equal((await service(request({ ville: 'Une ville\r\nBcc: unwanted' }))).status, 400);
});
