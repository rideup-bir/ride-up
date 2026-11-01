// /p/<day>-<month> (e.g. /p/2-nov, shared from 1.0.1) or /p/<YYYY-MM-DD> (older links): the link in a shared plan
// ("I'm heading up to fly tomorrow around 9:00 am… …/p/2-nov"). The small picture is the app icon (share/icon.png).
import { read, page, clockOf } from "../../lib/preview.js";

const MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
// "2-nov" → the next 2 Nov from about two months ago (so a link stays right across New Year)
function fromShort(t) {
  const m = /^(\d{1,2})-([a-z]{3})$/.exec(t);
  if (!m || MONTHS.indexOf(m[2]) === -1) return null;
  const bir = new Date(Date.now() + 330 * 60000), mon = MONTHS.indexOf(m[2]), day = +m[1];
  let y = bir.getUTCFullYear();
  if (Date.UTC(y, mon, day) < bir.getTime() - 60 * 86400000) y++;
  const d = new Date(Date.UTC(y, mon, day));
  if (d.getUTCMonth() !== mon) return null;
  return d.toISOString().slice(0, 10);
}

export async function onRequestGet({ request, params }) {
  const raw = String(params.date || "").toLowerCase();
  const date = /^\d{4}-\d{2}-\d{2}$/.test(raw) ? raw : fromShort(raw);
  const h24 = new URL(request.url).searchParams.has("24");
  if (!date) return page(request, { title: "Who's flying at Bir · Ride Up", description: "See who's heading up, and add your plan.", go: "/#plan" });
  let plans = [];
  try { plans = (await read("flight_plans?plan_date=eq." + date + "&select=time_slot")) || []; } catch (e) {}
  const day = new Date(date + "T00:00:00Z").toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short", timeZone: "UTC" });
  const times = plans.map((p) => p.time_slot).filter((t) => /^\d\d:\d\d$/.test(t || "")).sort();
  const n = plans.length;
  const title = n ? day + " · " + n + (n === 1 ? " pilot" : " pilots") + " heading up" : "Flying at Bir on " + day;
  const description = n && times.length ? "From " + clockOf(+times[0].slice(0, 2), +times[0].slice(3), h24) + ". Add your plan" : "See who's flying, and add your plan";
  return page(request, { title, description, go: "/#plan-" + date });
}
