// Ride Up 2.0 · push-send: sends the queued notifications (push_queue) to the phones that allowed them.
// Called every minute by pg_cron (see supabase-setup.sql), only when something is waiting. It checks a shared secret
// (push_config.cron_secret), so nobody else can make it run. The first time it runs it makes the sender's own keys
// (VAPID) and keeps them in push_config, a private table only the server can read.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

Deno.serve(async (req: Request) => {
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const { data: cfg } = await db.from("push_config").select("k, v");
  const get = (k: string) => (cfg || []).find((r: { k: string; v: string }) => r.k === k)?.v;
  const secret = get("cron_secret");
  if (!secret || req.headers.get("x-cron") !== secret) return new Response("not allowed", { status: 401 });

  let pub = get("vapid_public"), priv = get("vapid_private");
  if (!pub || !priv) {
    const k = webpush.generateVAPIDKeys();
    pub = k.publicKey; priv = k.privateKey;
    await db.from("push_config").upsert([{ k: "vapid_public", v: pub }, { k: "vapid_private", v: priv }]);
  }
  webpush.setVapidDetails("mailto:cabwait.thermally.yours@gmail.com", pub, priv);

  const { data: rows } = await db.from("push_queue")
    .select("id, title, body, url, tries, push_subs(id, endpoint, p256dh, auth)")
    .is("sent_at", null).lt("tries", 3).order("id").limit(100);
  let sent = 0, gone = 0, failed = 0;
  for (const r of rows || []) {
    const s = (r as any).push_subs;
    if (!s) continue;
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        JSON.stringify({ title: r.title, body: r.body, url: r.url || "/" }), { TTL: 3600, urgency: "high" });
      await db.from("push_queue").update({ sent_at: new Date().toISOString() }).eq("id", r.id);
      sent++;
    } catch (e) {
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) { await db.from("push_subs").delete().eq("id", s.id); gone++; }   // the phone turned them off
      else { await db.from("push_queue").update({ tries: r.tries + 1 }).eq("id", r.id); failed++; }
    }
  }
  return new Response(JSON.stringify({ sent, gone, failed }), { headers: { "Content-Type": "application/json" } });
});
