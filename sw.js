/**
 * 母亲膳食管家 - Service Worker
 * 策略：HTML 和静态资源用 stale-while-revalidate，
 *       JS/JSON 数据文件用 network-first，确保更新后优先取最新版。
 *       SW 版本通过 CACHE_NAME 变化触发更新。
 *       /api/ 请求完全走网络，不经过 Service Worker。
 */
const CACHE_NAME = 'mom-diet-v7';
const CORE_ASSETS = [
  './', './index.html', './add.html', './foods.html',
  './stats.html', './settings.html',
  './src/common.css', './src/common.js',
  './manifest.json',
  './assets/icons/icon-192.svg', './assets/icons/icon-512.svg'
];
const DATA_FILES = [
  './src/db.js', './src/foods_data.js', './src/data-service.js', './src/api-client.js'
];

/* 安装：缓存核心 HTML/CSS/图标 */
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE_NAME).then(async cache => {
      for (const url of CORE_ASSETS) {
        try {
          await cache.add(url);
        } catch (err) {
          console.warn('SW cache add failed:', url, err);
        }
      }
    })
  );
  self.skipWaiting();
});

/* 激活：清理旧缓存 */
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
    )).then(() => self.clients.claim())
  );
});

/* 请求拦截 */
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = e.request.url;

  // API 请求直接走网络，避免 Service Worker 缓存/转换报错
  if (url.includes('/api/')) return;

  // 数据文件：network-first（优先取最新，失败用缓存）
  if (DATA_FILES.some(f => url.endsWith(f))) {
    e.respondWith(
      fetch(e.request)
        .then(r => {
          const clone = r.clone();
          caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
          return r;
        })
        .catch(() => caches.match(e.request).then(c => c || new Response('', { status: 503 })))
    );
    return;
  }

  // 其他资源：stale-while-revalidate（先返回缓存，后台更新）
  e.respondWith(
    caches.match(e.request).then(cached => {
      const fetchPromise = fetch(e.request)
        .then(r => {
          const clone = r.clone();
          caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
          return r;
        })
        .catch(() => cached || new Response('', { status: 503 }));
      return cached || fetchPromise;
    })
  );
});
