// Service Worker for Inbox PWA
// Version: 3.0.0 — Network-only for navigation/API, cache only app shell icons for offline.
// Static assets (JS/CSS) are fingerprinted by Propshaft and cached at the HTTP level.

const CACHE_VERSION = "inbox-v3.0";

// Minimal app shell — only icons and manifest for offline/install support.
// HTML, JS, CSS are NOT cached by the SW; Propshaft digest + HTTP headers handle those.
const APP_SHELL = [
  "/manifest.json",
  "/icon-192.png",
  "/icon-512.png",
  "/apple-touch-icon.png",
  "/icon.svg",
];

// Install — cache only the app shell icons, then activate immediately
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE_VERSION)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting()),
  );
});

// Activate — delete all old caches, take control of clients immediately
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((names) =>
        Promise.all(
          names
            .filter((name) => name !== CACHE_VERSION)
            .map((name) => caches.delete(name)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

// Fetch — network-only for everything except cached app shell icons
self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Only intercept GET requests to our own origin
  if (request.method !== "GET" || !url.protocol.startsWith("http")) {
    return;
  }

  // Navigation requests (HTML pages) and API calls — always go to network.
  // If offline, show a minimal offline message.
  if (request.mode === "navigate" || url.pathname.startsWith("/api/")) {
    event.respondWith(
      fetch(request).catch(() => {
        if (request.mode === "navigate") {
          return new Response(
            '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Offline</title>' +
              "<style>body{font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;background:#f9fafb;color:#374151}" +
              ".box{text-align:center;padding:2rem}.btn{margin-top:1rem;padding:.5rem 1.5rem;background:#2563eb;color:#fff;border:none;border-radius:.375rem;cursor:pointer;font-size:.875rem}" +
              ".btn:hover{background:#1d4ed8}</style></head>" +
              '<body><div class="box"><h1>You are offline</h1><p>Check your connection and try again.</p>' +
              '<button class="btn" onclick="location.reload()">Retry</button></div></body></html>',
            {
              status: 503,
              headers: { "Content-Type": "text/html; charset=utf-8" },
            },
          );
        }
        return new Response("Offline", {
          status: 503,
          headers: { "Content-Type": "text/plain" },
        });
      }),
    );
    return;
  }

  // App shell icons — serve from cache, fall back to network
  const isAppShell = APP_SHELL.some((path) => url.pathname === path);
  if (isAppShell) {
    event.respondWith(
      caches.match(request).then((cached) => cached || fetch(request)),
    );
    return;
  }

  // Everything else (static assets, images, fonts) — network only.
  // Propshaft adds digest hashes to URLs; HTTP cache headers handle caching correctly.
  // No SW caching needed — avoids stale asset problems after deploys.
});

// Handle SKIP_WAITING message from the app
self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});
