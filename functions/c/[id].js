// /c/<ride id>: the long ride link (shared before 1.0.1). New shares use the short /r/<6 characters>.
import { ridePreview } from "../../lib/preview.js";

export async function onRequestGet({ request, params }) {
  const id = String(params.id || "").toLowerCase();
  return ridePreview(request, /^[0-9a-f-]{36}$/.test(id) ? id : null, new URL(request.url).searchParams.has("24"));
}
