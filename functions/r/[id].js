// /r/<first 6 characters of a ride id>: the short link in a shared ride ("🚕 Sharing a taxi… rideup.pages.dev/r/7f3a2c").
// Rides only live a few hours, so the short code is matched against the last two days' rides.
import { read, ridePreview } from "../../lib/preview.js";

export async function onRequestGet({ request, params }) {
  const code = String(params.id || "").toLowerCase();
  let id = null;
  if (/^[0-9a-f]{6}$/.test(code)) {
    try {
      const since = new Date(Date.now() - 2 * 86400000).toISOString();
      const rows = (await read("cab_sessions?created_at=gt." + since + "&select=id&order=created_at.desc")) || [];
      const hit = rows.find((r) => r.id.startsWith(code));
      id = hit ? hit.id : null;
    } catch (e) {}
  }
  return ridePreview(request, id, new URL(request.url).searchParams.has("24"));
}
