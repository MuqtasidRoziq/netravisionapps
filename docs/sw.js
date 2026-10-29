// NetraVision Volunteer Service Worker (PWA & Background Notification)
const CACHE_NAME = 'netravision-v1';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// Tangani klik notifikasi OS (Windows / Android)
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const sessionUrl = (event.notification.data && event.notification.data.url) 
    ? event.notification.data.url 
    : '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.navigate(sessionUrl);
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(sessionUrl);
      }
    })
  );
});
