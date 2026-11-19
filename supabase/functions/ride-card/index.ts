// Ride Up 2.0 · ride-card: the picture in a shared ride's WhatsApp preview (P3: the time and the seats drawn in).
// It only ever shows things that repeat (time, car, seats taken of seats, today / tomorrow), never a name or a note, so each
// picture is drawn ONCE, kept in Supabase storage (bucket ride-cards) and reused by every later ride that looks the same.
// Free plan: drawing happens here (2 s of computing allowed), not on Cloudflare (10 ms).
import React from "https://esm.sh/react@18.2.0";
import { ImageResponse } from "https://deno.land/x/og_edge@0.0.6/mod.ts";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const BG = ["https://rideup.pages.dev/share/card-bg.jpg", "https://test.rideup.pages.dev/share/card-bg.jpg"];
const CARS = ["ALTO", "BOLERO", "EECO", "OTHER", "TAXI"];
const h = React.createElement;
const png = (b: BodyInit) => new Response(b, { headers: { "Content-Type": "image/png", "Cache-Control": "public, max-age=31536000, immutable" } });

async function bg(): Promise<string> {
  for (const u of BG) {
    try { const r = await fetch(u); if (r.ok && (r.headers.get("content-type") || "").includes("image")) {
      const b = new Uint8Array(await r.arrayBuffer()); let s = ""; for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
      return "data:image/jpeg;base64," + btoa(s); } } catch (_) { /* next */ }
  }
  return "";
}

Deno.serve(async (req: Request) => {
  const q = new URL(req.url).searchParams;
  const t = q.get("t") || "", car = (q.get("car") || "TAXI").toUpperCase(), cap = parseInt(q.get("cap") || "4", 10), n = parseInt(q.get("n") || "1", 10), d = q.get("d") || "";
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(t) || !CARS.includes(car) || !(cap >= 1 && cap <= 12) || !(n >= 0 && n <= cap) || !["", "today", "tomorrow"].includes(d))
    return new Response("bad picture", { status: 400 });
  const key = `v1/${t.replace(":", "")}-${car}-${cap}-${n}-${d || "x"}.png`;
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const have = await db.storage.from("ride-cards").download(key);
  if (have.data) return png(await have.data.arrayBuffer());

  const hh = parseInt(t.slice(0, 2), 10), time = `${hh % 12 || 12}:${t.slice(3)} ${hh < 12 ? "am" : "pm"}`;
  const left = cap - n, line = left > 0 ? `${car === "TAXI" ? "Taxi" : car} · ${left} spot${left === 1 ? "" : "s"} left` : `${car === "TAXI" ? "Taxi" : car} · full, ${cap} going`;
  const dots = [];
  for (let i = 0; i < cap; i++) dots.push(h("div", { key: i, style: { width: 26, height: 26, borderRadius: 13, marginRight: 7,
    background: i < n ? "#3C9AA0" : "transparent", border: i < n ? "none" : "3px dashed #E8E2D6", boxSizing: "border-box" } }));
  const img = await bg();
  const el = h("div", { style: { width: 600, height: 315, display: "flex", position: "relative", fontFamily: "sans-serif" } },
    img ? h("img", { src: img, width: 600, height: 315, style: { position: "absolute", left: 0, top: 0 } }) : null,
    h("div", { style: { position: "absolute", left: 22, bottom: 22, display: "flex", flexDirection: "column", padding: "14px 20px 16px",
      borderRadius: 18, background: "rgba(10,16,22,.72)" } },
      h("div", { style: { display: "flex", fontSize: 54, fontWeight: 800, color: "#F3C77A", lineHeight: 1 } }, time,
        d ? h("span", { style: { fontSize: 22, color: "#E8E2D6", marginLeft: 12, marginTop: 26 } }, d) : null),
      h("div", { style: { display: "flex", fontSize: 22, color: "#FFFFFF", marginTop: 6 } }, line),
      h("div", { style: { display: "flex", marginTop: 10 } }, ...dots)),
    h("div", { style: { position: "absolute", right: 18, top: 16, display: "flex", fontSize: 18, color: "#fff", padding: "4px 12px", borderRadius: 999, background: "rgba(10,16,22,.55)" } }, "Ride Up · Bir"));
  const out = new ImageResponse(el, { width: 600, height: 315 });
  const buf = await out.arrayBuffer();
  await db.storage.from("ride-cards").upload(key, buf, { contentType: "image/png", upsert: false }).catch(() => {});
  return png(buf);
});
