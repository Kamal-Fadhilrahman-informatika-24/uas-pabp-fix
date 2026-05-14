// ============================================================
// sw.js - SERVICE WORKER (PWA)
// Fitur: Cache file statis → app bisa dibuka offline
// ============================================================

const CACHE_NAME   = 'spindecide-v3';
const OFFLINE_URL  = 'login.html';

// File yang di-cache saat install
const ASSETS_TO_CACHE = [
  'login.html',
  'register.html',
  'dashboard.html',
  'history.html',
  'truth-dare.html',
  'double-spin.html',
  'multiplayer.html',
  'style.css',
  'truth-dare.css',
  'double-spin.css',
  'multiplayer.css',
  'supabase.js',
  'auth.js',
  'spin.js',
  'history.js',
  'truth-dare-data.js',
  'truth-dare.js',
  'double-spin.js',
  'multiplayer.js',
  'manifest.json',
];

// ── Install: cache semua asset ────────────────────────────────
self.addEventListener('install', event => {
  console.log('[SW] Installing…');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(ASSETS_TO_CACHE))
      .then(() => self.skipWaiting()) // aktif langsung
  );
});

// ── Activate: hapus cache lama ────────────────────────────────
self.addEventListener('activate', event => {
  console.log('[SW] Activating…');
  event.waitUntil(
    caches.keys().then(cacheNames =>
      Promise.all(
        cacheNames
          .filter(name => name !== CACHE_NAME)
          .map(name => caches.delete(name))
      )
    ).then(() => self.clients.claim())
  );
});

// ── Fetch: strategi "Cache First, Network Fallback" ───────────
//
//   1. Coba ambil dari cache → cepat & offline-ready
//   2. Kalau tidak ada di cache → ambil dari network
//   3. Kalau request ke Supabase (API) → langsung ke network
//      karena data harus selalu fresh
//
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // Biarkan request ke Supabase API langsung ke network
  if (url.hostname.includes('supabase.co')) {
    return; // tidak di-intercept
  }

  // Biarkan request CDN langsung ke network
  if (url.hostname.includes('cdn.jsdelivr.net')) {
    return;
  }

  // Cache-first untuk asset lokal
  event.respondWith(
    caches.match(event.request)
      .then(cached => {
        if (cached) return cached;

        // Tidak ada di cache → fetch dari network
        return fetch(event.request)
          .then(response => {
            // Hanya cache response yang valid
            if (!response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }

            // Clone response (karena stream bisa dibaca 1x)
            const responseClone = response.clone();
            caches.open(CACHE_NAME)
              .then(cache => cache.put(event.request, responseClone));

            return response;
          })
          .catch(() => {
            // Kalau network gagal DAN tidak ada cache → tampilkan halaman offline
            if (event.request.destination === 'document') {
              return caches.match(OFFLINE_URL);
            }
          });
      })
  );
});
