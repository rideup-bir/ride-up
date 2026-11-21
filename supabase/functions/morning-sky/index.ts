// Ride Up 2.0 · morning-sky (sheet 65, "Morning sky"): at 8:30 am Bir time pg_cron calls push_morning_kick(), which calls
// this. It reads today's forecast for the SW take-off at Billing and, on a flyable day, asks the database to queue
// "☀ Billing looks flyable from 11 am · 3 rides going up today" for the phones that turned Morning sky on (off by default).
// Like push-send it checks the shared secret (push_config.cron_secret), so nobody else can make it run.
// "Flyable" here is a simple reading of the forecast, the same limits the app's Go verdict uses; pilots still decide.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const TO = { lat: 32.0574, lon: 76.7439, elev: 2404 };   // Billing, SW take-off
const LIM = { w: 15, g: 20, gap: 8 };                      // km/h: wind, gusts, gust gap (the app's "Go" limits)

Deno.serve(async (req: Request) => {
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const { data: cfg } = await db.from("push_config").select("v").eq("k", "cron_secret");
  const secret = cfg?.[0]?.v;
  if (!secret || req.headers.get("x-cron") !== secret) return new Response("not allowed", { status: 401 });

  const url = "https://api.open-meteo.com/v1/forecast?latitude=" + TO.lat + "&longitude=" + TO.lon + "&elevation=" + TO.elev +
    "&timezone=Asia%2FKolkata&wind_speed_unit=kmh&forecast_days=1" +
    "&hourly=wind_speed_10m,wind_gusts_10m,precipitation_probability,precipitation,weather_code,cape,cloud_cover_low,is_day";
  const r = await fetch(url);
  if (!r.ok) return new Response("no forecast", { status: 502 });
  const h = (await r.json()).hourly;
  const good = (i: number) => {
    const w = h.wind_speed_10m[i], g = h.wind_gusts_10m[i];
    return h.is_day[i] === 1 && w <= LIM.w && g <= LIM.g && g - w <= LIM.gap && (h.precipitation_probability[i] ?? 0) < 30 &&
      (h.precipitation[i] ?? 0) < 0.2 && h.weather_code[i] < 95 && (h.cape[i] ?? 0) < 1500 && (h.cloud_cover_low[i] ?? 0) < 80;
  };
  // the first hour from 9 am to 3 pm that starts at least two good hours in a row
  let from = -1;
  for (let i = 0; i < h.time.length - 1; i++) {
    const hr = parseInt(String(h.time[i]).slice(11, 13), 10);
    if (hr < 9 || hr > 15) continue;
    if (good(i) && good(i + 1)) { from = hr; break; }
  }
  if (from < 0) return new Response(JSON.stringify({ flyable: false }), { headers: { "Content-Type": "application/json" } });
  const label = from === 12 ? "12 pm" : from > 12 ? (from - 12) + " pm" : from + " am";
  const { data, error } = await db.rpc("push_morning", { p_from: label });
  return new Response(JSON.stringify({ flyable: true, from: label, queued: data ?? 0, error: error?.message ?? null }), { headers: { "Content-Type": "application/json" } });
});
