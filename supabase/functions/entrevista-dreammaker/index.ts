// Função PÚBLICA (deploy com --no-verify-jwt). NÃO expõe service_role nem publishable key.
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
// Aceita múltiplos códigos (um por pessoa) => cada código gera uma pesquisa separada.
// Pode sobrescrever pelo secret ENTREVISTA_ACCESS_CODE (lista separada por vírgula).
const ACCESS_CODES = new Set(
  (Deno.env.get("ENTREVISTA_ACCESS_CODE") ?? "653421,000888,646464")
    .split(",").map((c) => c.trim()).filter(Boolean)
);
const SLUG = "dreammaker-hollywood";

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, apikey, authorization",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST")    return json({ ok: false, erro: "metodo" }, 405);

  let p: any;
  try { p = await req.json(); } catch { return json({ ok: false, erro: "json" }, 400); }

  const { acao, codigo, respostas, fase, cliente_nome, concluido } = p ?? {};
  if (!ACCESS_CODES.has(String(codigo))) return json({ ok: false, erro: "codigo_invalido" }, 401);

  const db = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
  const t = db.schema("core").from("entrevistas");

  if (acao === "validar") {
    const { data, error } = await t
      .select("respostas, fase_atual, concluido, cliente_nome")
      .eq("formulario_slug", SLUG).eq("codigo_acesso", codigo)
      .maybeSingle();
    if (error) return json({ ok: false, erro: error.message }, 500);
    return json({ ok: true, existe: !!data, respostas: data?.respostas ?? {},
      fase: data?.fase_atual ?? 0, concluido: data?.concluido ?? false, cliente_nome: data?.cliente_nome ?? null });
  }

  if (acao === "salvar") {
    const row = {
      formulario_slug: SLUG, codigo_acesso: String(codigo),
      respostas: respostas ?? {}, fase_atual: Number.isInteger(fase) ? fase : 0,
      cliente_nome: cliente_nome ?? null, concluido: concluido === true,
      atualizado_em: new Date().toISOString(),
    };
    const { error } = await t.upsert(row, { onConflict: "formulario_slug,codigo_acesso" });
    if (error) return json({ ok: false, erro: error.message }, 500);
    return json({ ok: true });
  }
  return json({ ok: false, erro: "acao_desconhecida" }, 400);
});
