// Ride Up 2.0 · notifications, and a small offline copy so the app (and the Bir Road game) still opens with no signal.
// The page itself is always fetched fresh when there is a signal (network first); the copy is only used offline.
// Pictures and fonts are served from the copy and refreshed in the background. Nothing from Supabase is ever kept here.
var CACHE = "rideup-shell-v1";
var SHELL = ["/", "/manifest.webmanifest", "/icon-192.png", "/fonts/caveat-700.woff2",
  "/art/bg2-autumn-day.webp", "/art/road-strip.webp", "/art/car-taxi.webp", "/art/life-cow-walk.webp", "/art/life-walker-p.webp",
  "/art/glider-red.webp", "/art/glider-blue.webp", "/art/glider-yellow.webp"];
var LIBS = /^https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@/;
self.addEventListener("install", function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return Promise.all(SHELL.map(function (u) { return c.add(u).catch(function () {}); })); }));
  self.skipWaiting();
});
self.addEventListener("activate", function (e) {
  e.waitUntil(caches.keys().then(function (ks) {
    return Promise.all(ks.filter(function (k) { return k.indexOf("rideup-shell-") === 0 && k !== CACHE; }).map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});
self.addEventListener("fetch", function (e) {
  var r = e.request; if (r.method !== "GET") return;
  var u = new URL(r.url);
  // the page: fresh when online (and kept), the kept copy when offline
  if (r.mode === "navigate" && u.origin === location.origin) {
    e.respondWith(fetch(r).then(function (res) {
      if (res.ok && res.type === "basic") { var cp = res.clone(); caches.open(CACHE).then(function (c) { c.put("/", cp); }); }
      return res;
    }).catch(function () { return caches.match("/"); }));
    return;
  }
  // pictures, fonts, the icon, and the database library (a fixed version): the kept copy, refreshed in the background
  var mine = u.origin === location.origin && /^\/(art|fonts)\/|^\/(icon-192\.png|manifest\.webmanifest)$/.test(u.pathname);
  if (mine || LIBS.test(r.url)) {
    e.respondWith(caches.open(CACHE).then(function (c) {
      return c.match(r).then(function (hit) {
        var fresh = fetch(r).then(function (res) { if (res.ok) c.put(r, res.clone()); return res; }).catch(function () { return hit; });
        return hit || fresh;
      });
    }));
  }
});
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
