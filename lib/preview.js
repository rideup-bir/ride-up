// Shared bits for the link-preview pages (/c/<ride id> and /p/<date>).
// WhatsApp, iMessage and Telegram read the og: tags of the page a link points at, so each shared ride or
// plan gets a tiny page with its own title, then sends people on to the app at the right spot.
// Only public, read-only data is read (the same the app shows to anyone): no names, no numbers.
export const SUPABASE_URL = "https://ysmsvepwsortccnjkpdd.supabase.co";
export const SUPABASE_KEY = "sb_publishable_8f1-9dArOD9FtXidDrpaKw_42w5i3ur";

export async function read(path) {
  const r = await fetch(SUPABASE_URL + "/rest/v1/" + path, { headers: { apikey: SUPABASE_KEY } });
  if (!r.ok) return null;
  return r.json();
}

const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

// "9:10 am" (the app's default) or "09:10" when the sender uses the 24 h clock (?24 on the link)
export function clockOf(hh, mm, h24) {
  if (h24) return String(hh).padStart(2, "0") + ":" + String(mm).padStart(2, "0");
  return (hh % 12 || 12) + ":" + String(mm).padStart(2, "0") + " " + (hh < 12 ? "am" : "pm");
}
export function istClock(iso, h24) {
  const d = new Date(new Date(iso).getTime() + 330 * 60000);  // Bir is on India time (UTC + 5:30)
  return clockOf(d.getUTCHours(), d.getUTCMinutes(), h24);
}

export function page(request, { title, description, go }) {
  // closed for the 1.1 rebuild: every shared link previews and lands the same
  title = "Under Renovation 🛠️"; description = "Back soon! Till then, happy thermalling."; go = "/";
  const origin = new URL(request.url).origin;
  const target = origin + go;
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta property="og:type" content="website">
<meta property="og:site_name" content="Ride Up">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${esc(request.url)}">
<meta property="og:image" content="${origin}/share/icon.png">
<meta property="og:image:width" content="160">
<meta property="og:image:height" content="160">
<meta name="twitter:card" content="summary">
<meta http-equiv="refresh" content="0; url=${esc(target)}">
<style>body{font:16px system-ui,sans-serif;background:#0B141A;color:#E9EDEF;display:grid;place-items:center;min-height:100vh;margin:0}a{color:#00A884}</style>
</head><body><p>Opening <a href="${esc(target)}">Ride Up</a>…</p>
<script>location.replace(${JSON.stringify(target)});</script></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=60" } });
}

// A shared ride (/c/<full id> or the short /r/<first 6 of the id>). Every shared ride or plan shows the app icon as its
// small picture (share/icon.png, 160 px, from art-sources/icon-master-alto.png); the words say what it is.
export async function ridePreview(request, id, h24) {
  const fallback = { title: "A ride up to take-off · Ride Up", description: "Shared taxis from the Bir landing up to take-off.", go: "/" };
  let s = null;
  if (id) {
    try {
      const rows = await read("cab_sessions?id=eq." + id + "&select=capacity,car_type,status,vehicle,pickup,leave_time,created_at,cab_passengers(extra,left_at)");
      s = rows && rows[0];
    } catch (e) {}
  }
  if (!s) return page(request, id ? { ...fallback, go: "/#ride-" + id } : fallback);

  const used = (s.cab_passengers || []).filter((p) => !p.left_at).reduce((n, p) => n + 1 + (p.extra || 0), 0);
  const left = Math.max(0, s.capacity - used);
  const lift = s.vehicle === "own";
  const old = Date.now() - new Date(s.created_at).getTime() > 3 * 3600000;  // the app stops showing rides long before this
  const seats = s.status === "departed" ? "left already" : old ? "ended" : s.status === "cancelled" ? "called off"
    : s.status === "full" || left === 0 ? "full" : left + (left === 1 ? " seat left" : " seats left");
  let when = istClock(s.created_at, h24);
  if (lift && /^\d\d:\d\d$/.test(s.leave_time || "")) when = clockOf(+s.leave_time.slice(0, 2), +s.leave_time.slice(3), h24);
  const title = lift ? "Lift" + (s.pickup ? " from " + s.pickup : "") + " · " + seats + " · ~" + when
    : (s.car_type || "Taxi") + " · " + seats + " · ~" + when;
  const description = lift ? "A lift up to take-off at Bir" : "Shared taxi from the Bir landing to take-off";
  return page(request, { title, description, go: "/#ride-" + id });
}
