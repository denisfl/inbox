// Service Worker for Inbox PWA
// Version: 2.0.0 - Network-first for dynamic content

const CACHE_VERSION = 'inbox-v2';
const OFFLINE_CACHE = 'inbox-offline-v2';

// Core app shell resources to cache on install
const APP_SHELL = [
  '/',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png',
  '/apple-touch-icon.png',
  '/icon.svg'
];

// Install event - cache app shell
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');
  
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then((cache) => {
        console.log('[Service Worker] Caching app shell');
        return cache.addAll(APP_SHELL);
      })
      .then(() => {
        console.log('[Service Worker] App shell cached');
        // Force the waiting service worker to become the active service worker
        return self.skipWaiting();
      })
      .catch((error) => {
        console.error('[Service Worker] Install failed:', error);
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((cacheName) => {
              // Delete old versions
              return cacheName !== CACHE_VERSION && cacheName !== OFFLINE_CACHE;
            })
            .map((cacheName) => {
              console.log('[Service Worker] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            })
        );
      })
      .then(() => {
        console.log('[Service Worker] Activated');
        // Take control of all clients immediately
        return self.clients.claim();
      })
  );
});

// Fetch event - network-first for dynamic content, cache-first for static assets
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }

  // Skip chrome-extension and other non-http(s) requests
  if (!url.protocol.startsWith('http')) {
    return;
  }

  // Determine caching strategy based on URL
  const isApiRequest = url.pathname.startsWith('/api/');
  const isDocumentPage = url.pathname.startsWith('/documents/');
  const isStaticAsset = url.pathname.startsWith('/assets/') || 
                        url.pathname.startsWith('/packs/') ||
                        url.pathname.match(/\.(js|css|png|jpg|jpeg|gif|svg|woff|woff2)$/);

  // Network-first strategy for API requests and document pages
  if (isApiRequest || isDocumentPage) {
    event.respondWith(
      fetch(request)
        .then((networkResponse) => {
          // Cache successful responses
          if (networkResponse && networkResponse.status === 200) {
            const responseToCache = networkResponse.clone();
            caches.open(OFFLINE_CACHE).then((cache) => {
              cache.put(request, responseToCache);
            });
          }
          return networkResponse;
        })
        .catch((error) => {
          console.log('[Service Worker] Network failed, trying cache:', url.pathname);
          // Fallback to cache if network fails
          return caches.match(request).then((cachedResponse) => {
            if (cachedResponse) {
              console.log('[Service Worker] Serving stale data from cache:', url.pathname);
              return cachedResponse;
            }
            // Return offline response
            return new Response('Offline - No cached data available', {
              status: 503,
              statusText: 'Service Unavailable',
              headers: new Headers({ 'Content-Type': 'text/plain' })
            });
          });
        })
    );
    return;
  }

  // Cache-first strategy for static assets
  event.respondWith(
    caches.match(request)
      .then((cachedResponse) => {
        // Return cached response if available
        if (cachedResponse) {
          console.log('[Service Worker] Serving from cache:', url.pathname);
          return cachedResponse;
        }

        // Otherwise fetch from network
        console.log('[Service Worker] Fetching from network:', url.pathname);
        
        return fetch(request)
          .then((networkResponse) => {
            // Cache successful responses
            if (networkResponse && networkResponse.status === 200) {
              // Only cache same-origin requests
              if (url.origin === location.origin) {
                const responseToCache = networkResponse.clone();
                
                caches.open(OFFLINE_CACHE)
                  .then((cache) => {
                    cache.put(request, responseToCache);
                  });
              }
            }
            
            return networkResponse;
          })
          .catch((error) => {
            console.error('[Service Worker] Fetch failed:', error);
            
            // Return offline page for navigation requests
            if (request.mode === 'navigate') {
              return caches.match('/');
            }
            
            // For other requests, return error
            return new Response('Offline', {
              status: 503,
              statusText: 'Service Unavailable',
              headers: new Headers({
                'Content-Type': 'text/plain'
              })
            });
          });
      })
  );
});

// Message event - handle skip waiting
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[Service Worker] Received SKIP_WAITING message');
    self.skipWaiting();
  }
});
