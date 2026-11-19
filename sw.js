// Ride Up 2.0 · notifications only (no offline cache): show a ping, and open Ride Up at the right ride when it's tapped.
self.addEventListener("install", function () { self.skipWaiting(); });
self.addEventListener("activate", function (e) { e.waitUntil(self.clients.claim()); });
self.addEventListener("push", function (e) {
  var d = {}; try { d = e.data ? e.data.json() : {}; } catch (x) { d = { title: "Ride Up", body: e.data ? e.data.text() : "" }; }
  e.waitUntil(self.registration.showNotification(d.title || "Ride Up", { body: d.body || "", icon: "/icon-192.png", badge: "/favicon-48.png", data: { url: d.url || "/" }, tag: d.url || "rideup" }));
});
self.addEventListener("notificationclick", function (e) {
  e.notification.close();
  var url = (e.notification.data && e.notification.data.url) || "/";
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(function (list) {
    for (var i = 0; i < list.length; i++) { if ("focus" in list[i]) { list[i].navigate(url).catch(function () {}); return list[i].focus(); } }
    return self.clients.openWindow(url);
  }));
});
