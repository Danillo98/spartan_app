// Service Worker para PWA - Spartan App
const CACHE_NAME = 'spartan-app-v1';
const RESOURCES = {
  "/": "index.html",
  "main.dart.js": "main.dart.js",
  "flutter.js": "flutter.js",
  "favicon.png": "favicon.png",
  "icons/Icon-72.png": "icons/Icon-72.png",
  "icons/Icon-96.png": "icons/Icon-96.png",
  "icons/Icon-144.png": "icons/Icon-144.png",
  "icons/Icon-192.png": "icons/Icon-192.png",
  "icons/Icon-512.png": "icons/Icon-512.png",
  "icons/Icon-maskable-192.png": "icons/Icon-maskable-192.png",
  "icons/Icon-maskable-512.png": "icons/Icon-maskable-512.png",
  "manifest.json": "manifest.json",
};

// Instala o service worker e faz cache dos recursos
self.addEventListener("install", (event) => {
  console.log('[Service Worker] Installing...');
  self.skipWaiting();
  
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[Service Worker] Caching app shell');
      return cache.addAll(Object.keys(RESOURCES));
    }).catch((error) => {
      console.error('[Service Worker] Cache failed:', error);
    })
  );
});

// Ativa o service worker e limpa caches antigos
self.addEventListener("activate", (event) => {
  console.log('[Service Worker] Activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      console.log('[Service Worker] Claiming clients');
      return self.clients.claim();
    })
  );
});

// Estratégia: Network First, fallback para Cache
self.addEventListener("fetch", (event) => {
  // Ignora requisições que não são GET
  if (event.request.method !== 'GET') {
    return;
  }

  // Ignora requisições para APIs externas (Supabase, etc)
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Se a resposta for válida, clona e armazena no cache
        if (response && response.status === 200) {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
        }
        return response;
      })
      .catch(() => {
        // Se falhar, tenta buscar do cache
        return caches.match(event.request).then((cachedResponse) => {
          if (cachedResponse) {
            console.log('[Service Worker] Serving from cache:', event.request.url);
            return cachedResponse;
          }
          
          // Se não houver no cache e for navegação, retorna index.html
          if (event.request.mode === 'navigate') {
            return caches.match('/');
          }
          
          return new Response('Offline - Recurso não disponível', {
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

// Mensagens do cliente
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
