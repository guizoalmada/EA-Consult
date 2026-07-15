# Rota Viva v2 — Multicanal (Telegram) + Planilha Mestre com Dashboard — Plano de Implementação

> **Para executores:** implementar fase a fase. Cada fase termina em entregável testável e commit atômico. Passos com `- [ ]` são rastreáveis.

**Objetivo:** migrar o piloto do Rota Viva para 100% Telegram (WhatsApp dormente, sem tocar na Meta), consertar o W5 (gerar `.xlsx` no Google Drive em vez do node Microsoft Excel/OneDrive), criar o roteador de envio W0 e o sync de entradas W7, e entregar uma Planilha Mestre com aba Dashboard e abas de entrada editáveis.

**Arquitetura:** um sub-workflow roteador (W0) centraliza todo envio e escolhe o canal por `usuarios.canal`. Telegram é o caminho padrão; os nodes WhatsApp permanecem no lugar, dormentes. A Planilha Mestre é um `.xlsx` gerado pelo W5 (ExcelJS), com abas-espelho protegidas (sobrescritas) e abas de entrada (`⚙ Config`, `➕ Agenda Manual`) preservadas entre execuções e lidas pelo W7.

**Stack:** Supabase (schema `rotaviva`, projeto `zvqwjtndvbqryonjplal`), n8n self-hosted (`n8n.guizoalmada.com.br`), Telegram Bot API, Google Drive, ExcelJS/SheetJS em Code node, Whisper + Claude Haiku (áudio).

---

## Restrições globais (valem para TODAS as fases)

- **Nenhuma credencial real.** Placeholders nomeados: `CRED_TELEGRAM_BOT`, `CRED_GDRIVE_ROTAVIVA`, `CRED_SUPABASE_ROTAVIVA`, `CRED_GMAIL_RELATORIO`, `CRED_OPENAI_WHISPER`, `CRED_ANTHROPIC`, `CRED_GEOCODING`, `CRED_META_CLOUD` (nodes WhatsApp dormentes).
- **B-01 é bloqueante e agora vale para Telegram.** Existe exatamente **uma** credencial `telegramApi` na conta (`ARMCOM - Telegram Sarah Bot`, id `kNeRELzSDrJ5d3Eg`, de outro cliente). Todo node Telegram criado tende a ser auto-associado a ela. **Após CADA criação/edição de workflow, auditar** quais credenciais os nodes ficaram apontando e registrar em B-01/GO-LIVE que precisam ser trocadas manualmente antes do go-live.
- **Todos os workflows salvos INATIVOS.** Nunca publicar/ativar.
- **Header PostgREST** `Accept-Profile`/`Content-Profile: rotaviva` em todo acesso HTTP ao Supabase.
- **Proibido node Microsoft Excel** em qualquer ponto.
- **Nada na Meta:** não criar app, não mexer em templates, não ativar nodes WhatsApp.
- **Commits atômicos em PT-BR.** JSONs atualizados exportados em `rota-viva/n8n/workflows/`.
- **Loop de correção: máximo 3 iterações por problema.** Na 3ª falha, PARAR, registrar em `docs/BLOQUEIOS.md` e chamar o Guilherme.

## IDs de referência (estado vivo confirmado em 15 Jul 2026)

| Item | ID | Nós |
|---|---|---|
| W1 Ingestão Rota | `24dogumhR2c0AZtM` | 28 |
| W2 Conversa Campo | `AlnFEu0bffETX6UV` | 78 |
| W3 Rota Diária | `Ty2jLxBUD4fbMtB6` | 11 |
| W4 Relatório Diário | `tGFCtCr5GKSCVeYL` | 14 |
| W5 Espelho Excel | `Z0bzcrgLeK945NLn` | 13 |
| W6 Lembrete Retorno | `4jArhsdZUcRbEbau` | 7 |
| W0 Enviar Mensagem | (criar) | — |
| W7 Sync de Entradas | (criar) | — |
| Credencial Telegram ARMCOM (NÃO usar) | `kNeRELzSDrJ5d3Eg` | — |

**Reversões de decisão que este plano registra (regra 5 — expor, não silenciar):** D-02/D-05 (Meta oficial no piloto) → WhatsApp dormente; D-04 (planilha read-only) → emendada com abas de entrada lidas pelo W7; **D-07 (Excel 365/OneDrive) → revertida para `.xlsx` no Google Drive**. Registrar como D-10/D-11/D-12 e marcar D-02/D-04/D-05/D-07 como superadas.

---

## Fase 0 — GATE técnico: ExcelJS/SheetJS no Code node

Bloqueia o desenho do Bloco 5. Fazer ANTES de planejar o W5 em detalhe.

- [ ] Criar workflow descartável com Manual Trigger → Code node que tenta `require('exceljs')` e `require('xlsx')`, retornando qual carrega e a versão.
- [ ] Executar e ler o resultado.
- [ ] **Se ExcelJS disponível:** seguir Bloco 5 com ExcelJS (proteção de aba + formatação condicional).
- [ ] **Se só SheetJS (`xlsx`):** seguir com SheetJS (sem proteção real de aba nem formatação condicional rica — degradar Dashboard para texto/emoji e registrar a limitação em D-12).
- [ ] **Se nenhuma:** PARAR o Bloco 5, registrar em BLOQUEIOS (opções: liberar `NODE_FUNCTION_ALLOW_EXTERNAL`, usar Edge Function Supabase para gerar o xlsx, ou HTTP a serviço externo) e chamar o Guilherme.
- [ ] Apagar o workflow de teste.

**Aceite:** decisão de biblioteca registrada; workflow de teste removido.

---

## Fase 1 — Migrations (Bloco 1)

**Arquivos:** criar migrations em `rota-viva/supabase/migrations/` (timestamp > `20260710150000`).

- [ ] `usuarios`: `add column canal text not null default 'telegram' check (canal in ('telegram','whatsapp'))`; `add column telegram_chat_id text unique`.
- [ ] `estado_conversa`: tabela vazia — recriar com PK `identidade text` (`tg:<chat_id>` | `wa:<telefone>`), mantendo `estado`, `contexto jsonb`, `atualizado_em`.
- [ ] `agenda_visitas`: refazer CHECK de `origem` para incluir `'manual'` (atual: `rota`,`retorno`,`reagendada`).
- [ ] `config`: `insert ... on conflict do nothing` de `telegram_habilitado=true`, `whatsapp_habilitado=false`.
- [ ] Aplicar via `apply_migration`; validar com `list_tables`/`select`.

**Aceite:** colunas e CHECK presentes no schema vivo; `config` com as 2 flags; PK de `estado_conversa` = `identidade`. Commit.

---

## Fase 2 — W0 "Enviar Mensagem" (Bloco 2, NOVO)

Sub-workflow chamado por Execute Workflow.

**Contrato de entrada:** `{ usuario_id | identidade, tipo: 'rota_diaria'|'lembrete_retorno'|'relatorio_diario'|'alerta_checkin_suspeito'|'alerta_rota_vazia'|'texto_livre', variaveis:{...}, botoes?:[{id,rotulo}] }`

- [ ] Execute Workflow Trigger + node de templates PT-BR (mesmas variáveis dos templates Meta).
- [ ] Buscar usuário → `canal` (Supabase, header `rotaviva`).
- [ ] Ramo `telegram`: montar texto do template e enviar via node Telegram (`CRED_TELEGRAM_BOT`); `botoes` → inline keyboard (`callback_data`=id).
- [ ] Ramo `whatsapp` (dormente): encaminhar aos nodes WhatsApp existentes; se `config.whatsapp_habilitado=false`, registrar e encerrar sem erro.
- [ ] Erro de envio: retornar `{ok:false, erro}` — nunca lançar exceção não tratada.
- [ ] **Auditar B-01** (Telegram!). Salvar inativo. Exportar JSON. Commit.

**Aceite:** W0 aceita o contrato, roteia por canal, degrada seguro com WhatsApp desabilitado.

---

## Fase 3 — W2 Conversa Campo multicanal (Bloco 3, mais complexa — 78 nós)

- [ ] Ler o W2 atual inteiro antes de editar; mapear onde o formato Meta é lido rio abaixo.
- [ ] Adicionar **Telegram Trigger** ao lado do webhook Meta.
- [ ] Node **Normalizador** após os dois triggers → payload único `{ identidade, canal, tipo_conteudo, conteudo, lat?, long?, file_id?, callback_data? }`. Toda a máquina de estados passa a operar sobre ele.
- [ ] **/start:** botão "Compartilhar contato" (request_contact) → casar `phone` com `usuarios.telefone` (E.164, tolerar ±55 e 9º dígito) → gravar `telegram_chat_id` → confirmar. Telefone não achado: orientar coordenador, **não** criar usuário.
- [ ] Guard allowlist: identidade → usuário ativo; senão ignorar em silêncio.
- [ ] Botões via `callback_data`; sempre `answerCallbackQuery`.
- [ ] Foto/áudio via getFile; foto → Storage `rotaviva-fotos`; áudio → Whisper → Haiku (JSON).
- [ ] Estado agora chaveado por `identidade` (não `telefone`).
- [ ] **Auditar B-01.** Inativo. Export. Commit.

**Aceite:** trigger Telegram + normalizador + /start com vinculação por contato; estado por identidade; WhatsApp preservado.

### Sub-plano detalhado do W2 (contrato extraído do workflow vivo, 15 Jul 2026)

**Decisão de arquitetura:** W2 vira **Telegram-primário**. Os nós WhatsApp existentes (trigger + I/O)
ficam no canvas **desabilitados** (dormentes, não apagados — regra do spec). Menos risco que plumbing
duplo em todo I/O.

**Contrato do payload unificado** (o que `Normalizar Mensagem` já emite, por item):
`{ telefone, tipoMensagem, texto, respostaId, lat, long, mediaId, waMessageId, comandoTipo, comandoCodcl }`
- `Validar Usuario Ativo` referencia `$('Normalizar Mensagem').first().json` e adiciona `usuarioId, papel, nomeUsuario`.
- `Buscar Usuario Ativo` hoje: `usuarios?telefone=eq.{{telefone}}&ativo=eq.true`.

**Mudanças:**
1. Novo `Telegram Trigger` → novo Code `Normalizar Telegram` emitindo o MESMO shape. Mapear:
   - texto → `texto`/`comandoTipo`/`comandoCodcl` (mesmas regex de `contrato X assinado`/`maquininha X ativada`).
   - `callback_query` → `respostaId` (= callback_data) e `tipoMensagem='interactive'`.
   - `location` → `lat`/`long`, `tipoMensagem='location'` (equivalente ao WhatsApp `location`).
   - foto/áudio → `mediaId` = `file_id` do Telegram, `tipoMensagem='image'|'audio'`.
   - Sempre: `canal='telegram'`, `identidade='tg:'+chat_id`, `chatId=chat_id`. Sem `telefone` (resolve por chat_id).
2. `Buscar Usuario Ativo`: URL montada no normalizador (`urlUsuario`) — Telegram busca por `telegram_chat_id`, WhatsApp por `telefone`. Node passa a usar `{{ $json.urlUsuario }}`.
   `Validar Usuario Ativo` também expõe `canal, chatId, telefone` do registro para os sends.
3. `estado_conversa` chaveado por `identidade` (migration já feita). Os nós `Buscar/Upsert Estado`
   passam a filtrar/gravar `identidade` no lugar de `telefone`.
4. **Mídia (Telegram getFile):** substituir `Buscar URL Midia Foto`/`Buscar URL Midia Audio`
   (whatsApp mediaUrlGet) por HTTP `getFile` (`https://api.telegram.org/bot<token>/getFile?file_id=`)
   + download `https://api.telegram.org/file/bot<token>/<file_path>`. Token via credencial Telegram.
   Foto → Storage `rotaviva-fotos` (nó de upload já existe). Áudio → Whisper→Haiku (já existe).
5. **Sends → Telegram:** trocar por node Telegram sendMessage (texto) ou inline keyboard:
   - `Pedir Foto Fachada`, `Avisar Sem Visita Pendente`, `Confirmar Contrato Assinado`,
     `Confirmar Maquininha Ativada`, `Enviar Texto Checkout` → Telegram sendMessage.
   - `Enviar Pergunta Decisor`, `Enviar Botoes Checkout`, `Enviar Lista Checkout` (interativos Graph)
     → Telegram sendMessage com `inline_keyboard` (callback_data = id das opções).
   - `Enviar Template Checkin Suspeito` (alerta coordenador) → chamar **W0** (tipo `alerta_checkin_suspeito`).
6. **/start:** ramo no `Normalizar Telegram`/Switch para `text='/start'` → responder com botão nativo
   `request_contact`; ao receber `contact`, casar `phone_number` (E.164, tolerar ±55 e 9º dígito) com
   `usuarios.telefone`, gravar `telegram_chat_id`, confirmar. Não encontrado → orientar coordenador, não criar usuário.
7. **allowlist:** `Validar Usuario Ativo` já retorna `[]` (ignora) quando não acha usuário — manter.
8. **answerCallbackQuery:** após tratar `callback_query`, chamar `answerCallbackQuery` (HTTP Telegram) para destravar o cliente.

**Nós WhatsApp a DESABILITAR (dormentes):** WhatsApp Trigger, Buscar URL Midia Foto/Audio, Pedir Foto
Fachada, Avisar Sem Visita Pendente, Confirmar Contrato Assinado, Confirmar Maquininha Ativada,
Enviar Texto Checkout, Enviar Pergunta Decisor, Enviar Lista/Botoes Checkout, Enviar Template Checkin
Suspeito. Preservados no canvas.

---

## Fase 4 — W1, W3, W4, W6 via W0 (Bloco 4)

- [ ] **W1:** aceitar XLSX do coordenador chegando pelo Telegram (além do Meta dormente); confirmações via W0.
- [ ] **W3/W4/W6:** trocar envio direto por Execute Workflow → W0 (mantendo montagem de variáveis). W4: e-mail segue `CRED_GMAIL_RELATORIO` (inalterado).
- [ ] Reconfirmar no W4: ranking com todos `faz_visitas=true`; meta efetiva individual; check-in suspeito do coordenador escala ao gerente.
- [ ] **Auditar B-01** em cada um. Inativo. Export. Commit por workflow.

**Aceite:** W1–W4 e W6 enviam exclusivamente via W0; nodes WhatsApp preservados dormentes.

---

## Fase 5 — W5 refeito: Planilha Mestre `.xlsx` no Google Drive (Bloco 5)

Cron 21:00. Depende da Fase 0.

- [ ] Buscar `config.excel_workbook_id`. Se preenchido: baixar o `.xlsx` atual do Drive e extrair intactas `⚙ Config` e `➕ Agenda Manual`.
- [ ] Buscar dados no Supabase com nomes legíveis (joins usuário/loja).
- [ ] Code node (ExcelJS/SheetJS conforme Fase 0) monta `RotaViva_Master.xlsx`, abas nesta ordem:
  1. **📊 Dashboard** (1ª aba): cabeçalho com data/hora; visitas no mês vs meta 280 com barra textual; tabela por pessoa (visitas hoje/mês, meta efetiva, % — condicional <70% vermelho, ≥100% verde); funil (visita→decisor→analisar→fechou) com % entre etapas; contratos por etapa + parados > `sla_dias_padrao` em destaque; top 3 motivos de perda; retornos vencidos; faturamento acumulado do mês.
  2. **Visitas** (espelho) 3. **Oportunidades** 4. **Contratos** (com vendas mês 1–6) 5. **Ranking** 6. **⚙ Config** (entrada) 7. **➕ Agenda Manual** (entrada).
  - Abas-espelho: linha 1 banner "⚠ GERADA AUTOMATICAMENTE…", proteção de aba, cabeçalhos congelados.
  - 1º run: `⚙ Config` gerada do banco (chave/valor/descrição + `meta_visitas_dia:<nome>` por usuário); `➕ Agenda Manual` com cabeçalhos data/cod_loja/responsavel/status_importacao/observacao_erro.
- [ ] Upload no Drive (`CRED_GDRIVE_ROTAVIVA`): update por fileId; se vazio, criar na pasta `1f30JmulRQ0deksfTYtMregOop8zKVWQk` e gravar o fileId em `config.excel_workbook_id`.
- [ ] Renomear workflow/descrição (remover Google Sheets/gsheets_id/Excel 365). **Zero nodes Microsoft.**
- [ ] **Auditar B-01.** Inativo. Export. Commit.

**Aceite:** gera `.xlsx` (Dashboard 1ª, 7 abas) no Google Drive, preserva abas de entrada, zero nodes Microsoft.

---

## Fase 6 — W7 Sync de Entradas (Bloco 6, NOVO)

Cron 06:00 e 20:30.

- [ ] Baixar `RotaViva_Master.xlsx`; se `excel_workbook_id` vazio, encerrar sem erro.
- [ ] **⚙ Config:** aplicar diffs em `rotaviva.config` e `usuarios.meta_visitas_dia`. Validar (numérico/HH:MM); inválido → não aplica + aviso (p/ relatório 18h). Chaves protegidas: `excel_workbook_id`, `emails_relatorio`.
- [ ] **➕ Agenda Manual:** por linha com `status_importacao` vazio → validar (data ≥ hoje; `cod_loja` existe em `lojas.codcl`; `responsavel` = usuário ativo `faz_visitas=true`). Válida → insert `agenda_visitas` (origem='manual', status='pendente') + marcar `✔ importada {dd/mm HH:mm}`. Inválida → `✖ erro` + motivo. Regravar só essas células.
- [ ] Idempotência por `status_importacao` preenchido.
- [ ] **Auditar B-01.** Inativo. Export. Commit.

**Aceite:** W7 processa Config + Agenda Manual, idempotente, 2 execuções/dia.

---

## Fase 7 — Documentação (Bloco 7)

- [ ] `DECISOES.md`: D-10 (multicanal + W0; piloto Telegram; WhatsApp dormente), D-11 (Planilha Mestre única, abas espelho protegidas + entrada lidas pelo W7; sem sync bidirecional livre; pull agendado idempotente), D-12 (Dashboard 1ª aba, KPIs pré-calculados; sem gráficos nativos). Marcar D-02/D-04/D-05/D-07 como superadas.
- [ ] `GO-LIVE.md`: reescrever caminho do piloto SEM Meta (BotFather → `CRED_TELEGRAM_BOT`; credenciais; UPDATE telefones; /start+contato; 1º run manual W5; ordem de ativação W0→W2→W1→W3→W6→W4→W5→W7; checklist de 13 itens). Conteúdo Meta/templates → anexo "Produção WhatsApp (futuro)".
- [ ] `CREDENCIAIS.md`: incluir CRED_TELEGRAM_BOT; CRED_META_CLOUD = "produção futura"; remover Microsoft.
- [ ] Atualizar B-01 (risco Telegram cross-cliente), fechar/atualizar B-02 e B-03.

**Aceite:** docs refletem a arquitetura v2; nada de Meta criado/alterado.

---

## Critérios de aceite globais (do spec)

- [ ] Migrations aplicadas (canal, telegram_chat_id, identidade, origem manual, flags)
- [ ] W0 criado; W1–W4 e W6 enviando só via W0; nodes WhatsApp dormentes
- [ ] W2 com trigger Telegram + normalizador + /start
- [ ] W5 gera .xlsx (Dashboard 1º, 7 abas) no Drive, preservando entradas; zero Microsoft
- [ ] W7 criado (Config + Agenda Manual, idempotente, 2x/dia)
- [ ] Nenhuma credencial real (B-01 auditado em todos)
- [ ] Todos inativos; JSONs exportados; docs atualizados; commits atômicos
- [ ] Nada criado/alterado na Meta
