# Bloqueios — Rota Viva

## B-01 — n8n substitui o nome de placeholders de credencial pelo nome de credenciais reais existentes

**Onde ocorre:** todo node que exige um tipo de credencial para o qual já existe **exatamente uma**
credencial real daquele tipo na conta n8n (de outro cliente/projeto) — confirmado para
`WhatsApp Business Cloud` (`n8n-nodes-base.whatsApp`/`n8n-nodes-base.whatsAppTrigger`, credencial
`CRED_META_CLOUD`) nos workflows W1, W2, W3, W4 e W6, e para o **Anthropic Chat Model**
(`@n8n/n8n-nodes-langchain.lmChatAnthropic`, credencial `CRED_ANTHROPIC`) no W2 — nesse caso a
ferramenta auto-associou "ARMCOM - Anthropic". **Confirmado de forma independente em 5 dos 6
workflows (W1, W2, W3, W4, W6)** — comportamento sistemático da ferramenta de criação/atualização
de workflows do n8n, não uma falha pontual de um agente. No W1, o mesmo problema também afetou o
WhatsApp Trigger e o node `mediaUrlGet` (auto-atribuídos a "ARMCOM - WhatsApp Trigger"/"ARMCOM -
WhatsApp Cloud API"). **Importante:** isso significa que o mesmo risco se aplica a QUALQUER
credencial nova que o cliente configurar no futuro para um tipo já usado por outro
projeto/cliente na mesma conta n8n (ex.: se só existir uma credencial `openAiApi` ou
`gmailOAuth2` no momento em que outro workflow desta conta for criado/editado por uma ferramenta
similar) — não é exclusivo do WhatsApp nem do Anthropic, é uma característica geral da ferramenta
de criação de workflows quando há exatamente um candidato de credencial do tipo exigido.

**O que foi tentado (3 tentativas por workflow, repetido de forma independente em pelo menos
quatro workflows — W1, W3, W4 e W6 — sempre com o mesmo resultado):**

1. `create_workflow_from_code` especificando `credentials: { whatsAppApi: newCredential('CRED_META_CLOUD') }`
   no código do node → a resposta da ferramenta trouxe
   `"autoAssignedCredentials":[{"nodeName":"...","credentialName":"ARMCOM - WhatsApp Cloud API","credentialType":"whatsAppApi"}]`.
2. `update_workflow` (removeNode + addNode) sem nenhum campo `credentials` → mesmo resultado.
3. `update_workflow` (removeNode + addNode) com `credentials: { whatsAppApi: { name: "CRED_META_CLOUD" } }`
   (explicitamente sem `id`) → mesmo resultado.
4. `setNodeCredential` com `credentialId` vazio, tentando "desvincular" → rejeitado pela API:
   `"credential '' not found or not accessible"` (o parâmetro exige um ID de credencial já
   existente).

**Erro/comportamento exato:** em todos os casos, o campo final do node ficou como
`"credentials": { "whatsAppApi": { "name": "ARMCOM - WhatsApp Cloud API" } }` — ou seja, o NOME do
placeholder é substituído pelo nome da única credencial `whatsAppApi` já existente na conta n8n
(pertencente a outro projeto/cliente, "ARMCOM", credential id `qxbrAen7zi4DhywY`). Confirmamos via
`list_credentials` que não existe nenhuma credencial chamada `CRED_META_CLOUD` na conta — apenas
essa credencial real da ARMCOM do tipo `whatsAppApi`.

**Hipótese:** o backend do n8n (ou a camada MCP) tem uma heurística de conveniência que, ao
processar um node com `predefinedCredentialType` sem uma credencial correspondente ao nome pedido,
"ajuda" o usuário associando automaticamente a única credencial daquele tipo existente na conta —
mesmo quando o nome não bate. Não existe, nas ferramentas MCP do n8n disponíveis nesta sessão,
nenhuma forma de: (a) criar uma credencial-placeholder de fato (não há `create_credential`), (b)
impedir esse auto-preenchimento de nome, ou (c) desvincular um node de credencial sem apontar para
um ID de credencial real já existente.

**Risco real avaliado:** ~~BAIXO~~ → **ALTO**. Corrigido em 10 Jul 2026 na auditoria de D-06.

A avaliação original ("o campo gravado tem apenas `name`, sem `id`, logo é uma referência solta e
não uma vinculação funcional") estava **errada**. Ela descrevia os JSONs exportados para
`n8n/workflows/`, que de fato só carregam `name`. Mas a auditoria direta da instância n8n
(`n8n.guizoalmada.com.br`) mostra que os nodes **têm o `id` funcional da credencial da ARMCOM**:

| Workflow | Node | Credencial vinculada |
|---|---|---|
| W1 | WhatsApp Trigger | `oWOgKLFpUr5DdRWd` — ARMCOM - WhatsApp Trigger |
| W1 | Obter URL do Media | `qxbrAen7zi4DhywY` — ARMCOM - WhatsApp Cloud API |
| W1 | Responder Coordenador | `qxbrAen7zi4DhywY` — ARMCOM - WhatsApp Cloud API |
| W2 | WhatsApp Trigger | `oWOgKLFpUr5DdRWd` — ARMCOM - WhatsApp Trigger |
| W2 | Enviar Template Checkin Suspeito | `qxbrAen7zi4DhywY` — ARMCOM - WhatsApp Cloud API |
| W2 | Modelo Anthropic Claude Haiku | `KRPStNscv88T1xYa` — ARMCOM - Anthropic |
| W3 | Enviar Rota Diária / Enviar Alerta Rota Vazia | `qxbrAen7zi4DhywY` — ARMCOM - WhatsApp Cloud API |
| W4 | Enviar WhatsApp Gerente | ARMCOM - WhatsApp Cloud API |
| W6 | Enviar Lembrete Retorno | `qxbrAen7zi4DhywY` — ARMCOM - WhatsApp Cloud API |

Consequência prática: **se qualquer um desses workflows for ativado hoje, ele autentica e dispara
mensagens reais pela WABA da ARMCOM** — outro cliente, outro número, outra conta de faturamento.
Não é confusão humana; é envio cross-cliente. Os workflows estão salvos inativos, que é o único
motivo de isso ainda não ter acontecido.

Os nodes que falam com o Supabase (`httpCustomAuth`) não têm credencial nenhuma vinculada — esses
falham fechado (erro de autenticação), não abrem para outro cliente.

**Mitigação aplicada:** cada node WhatsApp Business Cloud afetado recebeu uma nota (`notes`)
explícita no próprio workflow explicando o problema e instruindo a correção manual. Além disso,
adicionamos um passo explícito no `GO-LIVE.md` (seção de credenciais) pedindo para verificar/
corrigir esse campo antes de ativar qualquer workflow.

**Ação humana necessária antes do go-live:** em cada workflow (W1, W2, W3, W4, W6), abrir todo node
"WhatsApp Business Cloud" na UI do n8n e confirmar/trocar explicitamente a credencial para a
`CRED_META_CLOUD` real do Rota Viva (criada conforme `CREDENCIAIS.md`) — nunca reutilizar
"ARMCOM - WhatsApp Cloud API". No W2, também abrir o node "Anthropic Chat Model" e confirmar/trocar
para a `CRED_ANTHROPIC` real do Rota Viva — nunca reutilizar "ARMCOM - Anthropic". Ao configurar
qualquer credencial nova nesta conta n8n compartilhada, é prudente verificar, logo após criar o
workflow, se algum node ficou apontando para uma credencial de outro projeto antes de ativar.

**Isso agora é bloqueante, não uma recomendação.** Nenhum workflow do Rota Viva pode ser ativado
antes que a tabela acima esteja toda apontando para credenciais do Rota Viva.

**Adendo (15 Jul 2026, v2 multicanal): o mesmo vale para o Telegram.** Existe exatamente **uma**
credencial `telegramApi` na conta — `ARMCOM - Telegram Sarah Bot` (id `kNeRELzSDrJ5d3Eg`), de outro
cliente. Ao criar o **W0** (`[RotaViva] W0 - Enviar Mensagem`, id `YnkTgdXycHXNBJci`), a ferramenta
auto-associou:

| Workflow | Node | Credencial auto-associada (TROCAR) |
|---|---|---|
| W0 | Enviar Telegram | `kNeRELzSDrJ5d3Eg` — ARMCOM - Telegram Sarah Bot |
| W0 | Enviar WhatsApp (dormente) | `qxbrAen7zi4DhywY` — ARMCOM - WhatsApp Cloud API |

Consequência: se o W0 fosse ativado hoje, o Telegram do Rota Viva **enviaria pelo bot da ARMCOM**.
Mitigação aplicada: `notes` em ambos os nodes. Ação humana antes do go-live: criar
`CRED_TELEGRAM_BOT` (BotFather do Rota Viva) e trocar a credencial do node "Enviar Telegram" do W0
— e de todo node Telegram criado nas próximas fases (W2, e W1 se receber documento pelo Telegram).
Auditar `autoAssignedCredentials` após cada criação/edição de workflow com node Telegram/WhatsApp.

**✅ RESOLVIDO (Telegram) — 15 Jul 2026:** o Guilherme criou a credencial real
`ROTA-VITA - Telegram - Morgana` (id `9B3nW4btlkMwlbYj`, tipo `telegramApi`). Ela foi vinculada via
`setNodeCredential` a **todos os nós Telegram**: W0 (`Enviar Telegram`) e W2 (`Telegram Trigger`,
`Pedir Contato (/start)`, `Confirmar Vinculacao`, `Orientar Nao Cadastrado`). Confirmado
`autoAssignedCredentials: []` na aplicação. **Pendente ainda:** os nós **WhatsApp** dormentes
(auto-associados à `ARMCOM - WhatsApp Cloud API`) — só relevantes se/quando o WhatsApp for reativado
(produção futura); trocar para `CRED_META_CLOUD` real antes de qualquer ativação do ramo WhatsApp.

---

## B-02 — "Planilha Mestre" com aba Config e o W7 de sincronização não existem

**Onde ocorre:** o pedido de mudança de 10 Jul 2026 (D-06) previa, na Mudança 5, incluir metas por
usuário numa "aba Config da Planilha Mestre", sincronizada de volta ao banco por um workflow W7
("no formato tabular equivalente ao que o W7 já parseia"), preservando as "chaves protegidas".

**Estado real:** nada disso existe neste projeto.

- Existem 6 workflows (W1–W6). Não há W7, nem nunca houve.
- A única planilha do projeto é o **espelho** Excel do W5 (abas `visitas`, `oportunidades`, `contratos`),
  que é gerado 1x/dia e **não é lido de volta**. Não existe aba `Config` nem "chaves protegidas".
- Escrever config da planilha de volta para o banco **contradiz D-04** ("Supabase é fonte de
  verdade; a planilha é espelho read-only"), que é uma decisão vinculante desta fase.

**Impacto:** a coluna `usuarios.meta_visitas_dia` foi criada e é lida pelo W4 (meta efetiva =
individual, com fallback em `config.meta_visitas_dia`). O que falta é apenas a **superfície de
edição** para o gestor. Até haver decisão, a meta individual se define por SQL:

```sql
update rotaviva.usuarios set meta_visitas_dia = 8 where nome = 'Anderson Lemos';
update rotaviva.usuarios set meta_visitas_dia = null where nome = 'Danton'; -- volta a herdar a config
```

**Decisão pendente do Guilherme:** (a) manter edição por SQL; (b) construir de fato uma planilha
mestre editável + W7 de sincronização, o que exige revogar ou emendar D-04; ou (c) expor a meta
numa superfície própria (painel), fora da planilha.

---

## B-03 — A "aba Ranking do W5" não existe

**Onde ocorre:** Mudança 4 do mesmo pedido — "Ranking e contagens ... e aba Ranking do W5".

**Estado real:** o W5 sincroniza exatamente 3 abas (`visitas`, `oportunidades`, `contratos`) na
pasta de trabalho Excel. Não há aba `Ranking`.

**O que foi feito:** o ranking foi implementado onde ele de fato existe — no **W4**, que passou a
ordenar os usuários por visitas realizadas e a exibir posição, realizadas/planejadas e % da meta
efetiva de cada um, no corpo do e-mail diário. O objeto `ranking` também é exportado no output do
node `Consolidar Metricas`, pronto para ser consumido caso a aba venha a existir.

**Decisão pendente do Guilherme:** criar ou não uma 4ª aba `Ranking` no espelho Excel do W5.

---

## B-04 — Code node do n8n não permite `exceljs` nem `xlsx` (bloqueia o W5 v2)

**Onde ocorre:** o spec v2 (Bloco 5) manda gerar `RotaViva_Master.xlsx` num node Code usando
ExcelJS (preferido) ou SheetJS. A instância `n8n.guizoalmada.com.br` **não** libera essas libs.

**Evidência (gate técnico, 15 Jul 2026):** workflow descartável com Manual Trigger → Code
`require('exceljs')` / `require('xlsx')`, executado em modo manual (execução `2734`), retornou:

```json
{ "exceljs": "ERRO: Module 'exceljs' is disallowed", "xlsx": "ERRO: Module 'xlsx' is disallowed" }
```

Ou seja, `NODE_FUNCTION_ALLOW_EXTERNAL` não inclui nenhuma das duas, e o task runner do n8n
(externo) roda com globais restritos (`process` também indisponível). Gerar o xlsx dentro do Code
node é **impossível** sem mudança de infra no servidor.

**Opções (decisão do Guilherme — ele controla o servidor n8n):**

1. **Liberar a lib no n8n** (mais fiel ao spec): no container do n8n, `NODE_FUNCTION_ALLOW_EXTERNAL=exceljs`
   + garantir `exceljs` instalado. Tudo continua dentro do n8n como o spec desenhou. Exige acesso
   shell ao host do n8n (não disponível nesta sessão).
2. **Supabase Edge Function gera o xlsx** (dentro do stack já usado): o W5 chama uma Edge Function
   por HTTP passando os dados; a função (Deno) monta o `.xlsx` e devolve os bytes; o W5 sobe no
   Drive. Mantém proteção de aba/formatação se usar `npm:exceljs` no Deno. Não exige mexer no host
   do n8n; passa a existir um novo componente (Edge Function) a versionar/deployar.
3. **Serviço externo de render** (HTTP a um endpoint que gera xlsx). Mais dependência externa.

**Impacto:** bloqueia **W5** (Fase 5) e, por consequência, **W7** (Fase 6, depende do arquivo
existir). Todas as demais fases (migrations, W0, W2, W1/W3/W4/W6, docs) seguem sem depender disto.

### RESOLVIDO POR MUDANÇA DE ARQUITETURA (15 Jul 2026)

Não foi necessário liberar `exceljs` no servidor. O Guilherme decidiu **trocar o motor da planilha
para o node nativo Google Sheets** (ver **D-13**): o Google Sheets passa a ser a fonte de verdade
dos dados de negócio, escrito célula a célula pelo W5 (sem gerar arquivo), com Dashboard/Ranking em
fórmulas nativas. Também foram avaliados e descartados o Excel Online/Microsoft Graph (exigiria
consentimento OAuth do tenant Microsoft da DPK — mesmo risco de bloqueio corporativo) e a Edge
Function.

**Consequência:** o gate do `exceljs` deixou de ser relevante — nenhum ponto do projeto usa mais
`exceljs`/`xlsx` nem node Microsoft. A opção de infra (liberar `NODE_FUNCTION_ALLOW_EXTERNAL`) fica
**arquivada como não necessária**. W5/W7 são refeitos sobre Google Sheets (ver plano e D-13).

---

## B-05 — Sessão sem acesso aos MCPs de execução (Supabase, n8n, Google) — 15 Jul 2026

**Onde ocorre:** durante a rodada da nova arquitetura (Google Sheets), os MCPs `claude.ai Supabase`,
`claude.ai n8n` e o segundo servidor n8n (`mcp__n8n__`, `NO_RESPONSE`) e Google Drive/Gmail
**desconectaram** na sessão. Sem eles não é possível aplicar/verificar migrations no Supabase, criar/
editar/validar workflows no n8n, nem criar/testar a planilha no Google.

**Impacto e o que ficou pendente de reconexão:**

- **Migration do outbox** (`20260715160000_rotaviva_outbox_sheets.sql`) foi **escrita no repo mas NÃO
  aplicada** — aplicar via `apply_migration` e conferir no schema vivo quando o Supabase voltar.
- **W2 (rebuild multicanal), W5 (Sync to Sheets), W7 (Sync de Entradas), W8 (export .xlsx)** e a
  migração dos envios de W1/W3/W4/W6 para o W0 ficam **pendentes** de o n8n voltar.
- **Planilha "RotaViva Master"** (7 abas + fórmulas) não pôde ser criada — depende do Google.

**O que foi entregue nesta sessão sem os MCPs:** arquivo de migration do outbox, e a documentação da
nova arquitetura (D-13, este B-04/B-05, CREDENCIAIS com `CRED_GOOGLE_SHEETS`). Retomar o build assim
que os MCPs reconectarem.
