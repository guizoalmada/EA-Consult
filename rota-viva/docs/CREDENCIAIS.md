# Credenciais — Rota Viva

Nenhuma credencial real foi criada ou inserida durante a Fase 1. Todo node que precisa de
autenticação referencia um placeholder nomeado (`newCredential('CRED_X')` no n8n) — o n8n mostra
esse node com a credencial "não configurada" até que alguém crie a credencial real com o nome
abaixo e a associe ao node.

| Placeholder | O que é | Onde criar | Onde inserir no n8n | Workflows que usam |
|---|---|---|---|---|
| `CRED_TELEGRAM_BOT` | Token do bot Telegram do Rota Viva (canal padrão do piloto — D-10) | Telegram → @BotFather → `/newbot` → copiar o token | n8n → Credentials → New → "Telegram API" → nome exato `CRED_TELEGRAM_BOT` | W0, W2 (e W1 se receber XLSX pelo Telegram) |
| `CRED_GOOGLE_SHEETS` | OAuth2 do Google com escopos `spreadsheets` + `drive.file` (planilha "RotaViva Master" é a fonte de verdade — D-13; e export `.xlsx` do W8) | Google Cloud Console → OAuth consent + credenciais OAuth2 com os escopos acima | n8n → Credentials → New → "Google Sheets OAuth2 API" (e reaproveitada no node Google Drive do W8) → nome exato `CRED_GOOGLE_SHEETS` | W5, W7, W8 |
| `CRED_SUPABASE_ROTAVIVA` | `service_role` key do projeto Supabase Morgana Ops (schema `rotaviva` — agora outbox/auditoria, D-13) | Supabase Dashboard → projeto Morgana Ops → Project Settings → API → `service_role` key (secreta) | n8n → Credentials → New → "HTTP Custom Auth" com headers `apikey: <service_role_key>` e `Authorization: Bearer <service_role_key>` → nome exato `CRED_SUPABASE_ROTAVIVA` | W0, W1, W2, W3, W4, W5, W6, W7 |
| `CRED_GMAIL_RELATORIO` | OAuth2 de uma conta Gmail (ou conta de serviço) autorizada a enviar e-mail do relatório diário | Google Cloud Console → OAuth consent + credenciais OAuth2 (ou usar conta já autorizada no n8n) | n8n → Credentials → New → "Gmail OAuth2" → nome exato `CRED_GMAIL_RELATORIO` | W4 |
| `CRED_OPENAI_WHISPER` | API key da OpenAI (usada só para transcrição de áudio via Whisper) | https://platform.openai.com/api-keys | n8n → Credentials → New → "OpenAI API" → nome exato `CRED_OPENAI_WHISPER` | W2 |
| `CRED_ANTHROPIC` | API key da Anthropic (Claude Haiku 4.5, usada só para estruturar observações em JSON) | https://console.anthropic.com/settings/keys | n8n → Credentials → New → "Anthropic API" → nome exato `CRED_ANTHROPIC` | W2 |
| `CRED_GEOCODING` | API key de um provedor de geocodificação de endereços (ex.: Google Geocoding API, ou outro à escolha) | Provedor escolhido pelo cliente (ex.: Google Cloud Console → ativar "Geocoding API" → criar chave restrita) | n8n → Credentials → New → conforme o provedor (ex.: "Query Auth" ou "Header Auth") → nome exato `CRED_GEOCODING` | W1 |
| `CRED_META_CLOUD` | **Produção futura (dormente).** Token da Meta WhatsApp Cloud API + Phone Number ID — só quando/se o WhatsApp for reativado (`config.whatsapp_habilitado=true`) | Meta for Developers → App → WhatsApp → API Setup / System Users | n8n → Credentials → New → "WhatsApp API" → nome exato `CRED_META_CLOUD` | W0 (ramo dormente), nodes WhatsApp desabilitados do W2 |

## Observações

- **Nunca** cole nenhuma dessas chaves em texto no repositório, em conversas ou em qualquer
  arquivo versionado — elas só existem dentro do cofre de credenciais do n8n e do painel do
  Supabase/Meta/Google/OpenAI/Anthropic.
- O nome da credencial no n8n deve ser **exatamente** igual ao placeholder (ex.: `CRED_META_CLOUD`)
  para que o n8n consiga vincular automaticamente aos nodes que já referenciam esse nome ao abrir
  cada workflow pela primeira vez após a criação da credencial. Se o n8n não vincular sozinho, abra
  cada node marcado com credencial pendente e selecione manualmente a credencial pelo nome.
- `CRED_SUPABASE_ROTAVIVA` é usada por HTTP Request (não pelo node nativo Supabase) porque os
  nodes precisam enviar o header de schema do PostgREST (`Accept-Profile`/`Content-Profile:
  rotaviva`) em toda chamada — ver `SPEC.md` e as migrations em `supabase/migrations/`.
- Antes de `CRED_SUPABASE_ROTAVIVA` funcionar, o schema `rotaviva` também precisa estar na lista de
  "Exposed schemas" do PostgREST (Supabase Dashboard → Project Settings → API → Data API Settings →
  adicionar `rotaviva` em "Exposed schemas") — sem isso a API REST retorna 404 para qualquer tabela
  do schema, mesmo com a credencial correta. Este passo está no `GO-LIVE.md`.
