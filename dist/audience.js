(() => {
  'use strict';
  if (location.origin !== 'https://www.lesplusgrandsracontes.fr') return;
  const id = document.getElementById('audience-script')?.dataset.gaId;
  if (!/^G-[A-Z0-9]+$/.test(id || '')) return;
  const panel = document.getElementById('audience-choice');
  const settings = document.getElementById('audience-settings');
  const accept = document.getElementById('audience-accept');
  const refuse = document.getElementById('audience-refuse');
  const key = 'lpgr-audience-consent-v1';
  const lifetime = 180 * 86400;
  const disable = 'ga-disable-' + id;
  const adsDenied = {ad_storage:'denied', ad_user_data:'denied', ad_personalization:'denied'};
  let tag;
  let fallback = '';
  let storedLocally = false;
  window[disable] = true;

  function choice() {
    try {
      const saved = JSON.parse(localStorage.getItem(key));
      if (!storedLocally && fallback) return fallback;
      if (saved?.until > Date.now() && ['yes','no'].includes(saved.value)) return saved.value;
      return '';
    } catch { return fallback; }
  }

  function show(visible) {
    panel.hidden = !visible;
    settings.setAttribute('aria-expanded', String(visible));
  }

  function cleanCookies() {
    const names = ['_ga', '_ga_' + id.slice(2)];
    for (const name of names) {
      for (const domain of ['', '; Domain=' + location.hostname, '; Domain=lesplusgrandsracontes.fr']) {
        document.cookie = name + '=; Max-Age=0; Path=/; Secure; SameSite=Lax' + domain;
      }
    }
  }

  function start() {
    if (tag) return;
    window[disable] = false;
    window.dataLayer = window.dataLayer || [];
    function gtag() { window.dataLayer.push(arguments); }
    gtag('consent','default',{...adsDenied, analytics_storage:'denied'});
    gtag('consent','update',{...adsDenied, analytics_storage:'granted'});
    gtag('js', new Date());
    let referrer = null;
    try { if (document.referrer) referrer = new URL(document.referrer); } catch {}
    gtag('config', id, {
      allow_google_signals:false,
      allow_ad_personalization_signals:false,
      cookie_expires:lifetime,
      cookie_update:false,
      cookie_domain:location.hostname,
      page_location:location.origin + location.pathname,
      page_referrer:referrer ? referrer.origin + referrer.pathname : ''
    });
    tag = document.createElement('script');
    tag.async = true;
    tag.referrerPolicy = 'no-referrer';
    tag.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(id);
    document.head.append(tag);
  }

  function apply() {
    const saved = choice();
    if (saved === 'yes') start();
    else {
      window[disable] = true;
      cleanCookies();
      // A loaded script cannot be unloaded. Reload without the Google tag.
      if (tag) { location.reload(); return; }
    }
    show(!saved);
  }

  function save(value) {
    fallback = value;
    try {
      localStorage.setItem(key, JSON.stringify({value, until:Date.now() + lifetime * 1000}));
      storedLocally = true;
    } catch { storedLocally = false; }
    apply();
    settings.focus();
  }

  settings.hidden = false;
  settings.addEventListener('click', () => {
    const visible = panel.hidden;
    show(visible);
    if (visible) accept.focus();
  });
  accept.addEventListener('click', () => save('yes'));
  refuse.addEventListener('click', () => save('no'));
  window.addEventListener('storage', e => { if (e.key === key || e.key === null) apply(); });
  window.addEventListener('pageshow', e => { if (e.persisted) apply(); });
  apply();
})();
