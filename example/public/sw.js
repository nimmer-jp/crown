const CACHE_NAME = 'crown-pwa-cache-v1';
const SYNC_STORE_NAME = 'crown-sync-queue';

async function getDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('CrownPWA', 1);
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains(SYNC_STORE_NAME)) {
        db.createObjectStore(SYNC_STORE_NAME, { keyPath: 'id', autoIncrement: true });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function queueRequest(request) {
  const db = await getDB();
  const tx = db.transaction(SYNC_STORE_NAME, 'readwrite');
  const store = tx.objectStore(SYNC_STORE_NAME);
  
  const serialized = {
    url: request.url,
    method: request.method,
    headers: [...request.headers.entries()],
    body: await request.clone().text(),
    timestamp: Date.now()
  };
  
  store.add(serialized);
}

async function flushQueue() {
  const db = await getDB();
  const tx = db.transaction(SYNC_STORE_NAME, 'readonly');
  const store = tx.objectStore(SYNC_STORE_NAME);
  const request = store.getAll();
  
  request.onsuccess = async () => {
    const items = request.result;
    if (!items || items.length === 0) return;
    
    for (const item of items) {
      try {
        await fetch(item.url, {
          method: item.method,
          headers: item.headers,
          body: item.body
        });
        const delTx = db.transaction(SYNC_STORE_NAME, 'readwrite');
        delTx.objectStore(SYNC_STORE_NAME).delete(item.id);
      } catch (e) {
        console.error('Failed to sync:', e);
      }
    }
  };
}

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(['/'])));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method === 'GET') {
    event.respondWith(
      fetch(req).then((response) => {
        const resClone = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(req, resClone));
        return response;
      }).catch(() => caches.match(req))
    );
  } else {
    event.respondWith(
      fetch(req).catch(async () => {
        await queueRequest(req);
        const isHtmx = req.headers.has('HX-Request');
        if (isHtmx) {
          return new Response(
            `<div style="opacity:0.8" class="p-4 mb-4 text-sm text-yellow-800 rounded-lg bg-yellow-50">[オフライン] リクエストをローカルに保存しました。通信復帰後に自動同期されます。</div>`, 
            { headers: { 'Content-Type': 'text/html' } }
          );
        } else {
          return new Response(
            JSON.stringify({ offline: true, queued: true }), 
            { headers: { 'Content-Type': 'application/json' } }
          );
        }
      })
    );
  }
});

self.addEventListener('sync', (event) => {
  if (event.tag === 'crown-sync') event.waitUntil(flushQueue());
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'FLUSH_QUEUE') flushQueue();
});

	flushQueue();
	