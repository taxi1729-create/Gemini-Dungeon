// 以前の版で登録された Service Worker を解除し、古いキャッシュを消して最新版を読み直させるためのファイル。
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		const keys = await caches.keys();
		await Promise.all(keys.map((k) => caches.delete(k)));
		await self.registration.unregister();
		const clients = await self.clients.matchAll({ type: 'window' });
		clients.forEach((c) => c.navigate(c.url));
	})());
});
