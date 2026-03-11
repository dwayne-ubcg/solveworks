const CACHE = 'fs-v1';
const ASSETS = ['/boutique/', '/boutique/index.html'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => 
    Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
  ));
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  if (e.request.url.includes('/data/')) {
    // Always fetch fresh data files
    e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
  } else {
    // Cache-first for app shell
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request)));
  }
});
