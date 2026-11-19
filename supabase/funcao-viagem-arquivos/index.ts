// Missão Ásia 2027: links assinados para enviar e ver fotos/áudios do bucket privado viagem-midias.
// A autenticação é o token de sessão do roteiro (viagem_login), conferido no banco.
// Publicar como Edge Function com o nome "viagem-arquivos" e "Verify JWT" DESLIGADO.
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });
const BUCKET = "viagem-midias";
const okId = (s: unknown) => typeof s === "string" && /^[A-Za-z0-9_-]{4,64}$/.test(s);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  let body: any;
  try { body = await req.json(); } catch { return json({ error: "json" }, 400); }
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const { data: uid, error: e1 } = await sb.rpc("viagem_token_usuario", { p_token: String(body?.token ?? "") });
  if (e1 || !uid) return json({ error: "sessao_invalida" }, 401);

  if (body.action === "upload") {
    if (!okId(body.id)) return json({ error: "id" }, 400);
    const { data, error } = await sb.storage.from(BUCKET).createSignedUploadUrl(body.id, { upsert: true });
    if (error) return json({ error: error.message }, 500);
    return json({ signedUrl: data.signedUrl, path: data.path });
  }
  if (body.action === "urls") {
    const ids = (Array.isArray(body.ids) ? body.ids : []).filter(okId).slice(0, 200);
    if (!ids.length) return json({ urls: {} });
    const { data, error } = await sb.storage.from(BUCKET).createSignedUrls(ids, 60 * 60 * 6);
    if (error) return json({ error: error.message }, 500);
    const urls: Record<string, string> = {};
    for (const d of data ?? []) if (d.path && d.signedUrl) urls[d.path] = d.signedUrl;
    return json({ urls });
  }
  return json({ error: "acao" }, 400);
});
