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

**✅ RESOLVIDO (Anthropic) — 17 Jul 2026:** o Guilherme criou a credencial real `ROTA-VIVA -
Anthropic` (tipo `anthropicApi`) e vai trocar manualmente na UI do n8n o node **Modelo Anthropic
Claude Haiku** do W2 (`n8n/workflows/w2-conversa-campo.json`), hoje apontando para
`KRPStNscv88T1xYa` — ARMCOM - Anthropic. Confirmar depois de trocar que nenhum node do W2 referencia
credencial cujo nome comece por "ARMCOM - ".

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
que os MCPs reconectarem. **Atualização:** MCPs voltaram (n8n via servidor `claude.ai n8n`; Supabase);
migration aplicada; W2 rebuild, W3/W4/W6→W0 e o workflow de setup da planilha construídos.

---

## B-06 — Credenciais criadas mas NÃO autorizadas / ausentes (bloqueia teste do pipeline) — 15 Jul 2026

**Google Sheets/Drive OAuth não conectado:** a credencial `ROTA-VIVA - Google Sheets`
(`V8yK9tJ9nbUTis15`) existe mas não tem access token — o node de criar a planilha falhou com
`NodeApiError: Unable to sign without access token` (execução `2762`). É preciso abrir a credencial
no n8n e concluir o fluxo OAuth do Google ("Connect my account" / "Sign in with Google"). O mesmo
provavelmente vale para `ROTA-VIVA - Google Drive` (`xaChmTzpezR036yv`), usada pelo W8.

**`CRED_SUPABASE_ROTAVIVA` (httpCustomAuth) ainda não existe:** todos os nós HTTP que falam com o
Supabase nos workflows referenciam esse placeholder e estão **sem credencial** (fail closed). Criar
como "HTTP Custom Auth" com headers `apikey: <service_role>` e `Authorization: Bearer <service_role>`
(ver `CREDENCIAIS.md`). Sem ela nenhum workflow lê/grava no Supabase em runtime.

**Impacto:** com as 3 credenciais acima OK (Telegram já está), o piloto fica testável ponta a ponta.
Enquanto não: criar a planilha (Bloco G) e testar W5/W7/W8 fica bloqueado. O workflow
`[RotaViva] Setup - Planilha Master` (`XJPy0wMAW6vB4H8z`) está pronto para re-executar assim que o
OAuth do Google for concluído.

---

## B-07 — `Validar Usuario Ativo` (W2) descartava todo usuário vinculado — 17 Jul 2026

**✅ RESOLVIDO no mesmo dia.** O code node `Validar Usuario Ativo` assumia que a resposta HTTP do
Supabase chegava em `items[0].json` como um **array** de linhas (`rows[0]`). Na prática, o node
`Buscar Usuario Ativo` (HTTP Request) já entrega o array JSON **desagregado em itens** pelo n8n —
`items[0].json` é o objeto do usuário direto, não um array. `Array.isArray(rows)` dava sempre
`false` para qualquer usuário encontrado, e o node retornava `[]`, matando a conversa em silêncio.

**Consequência:** desde a criação do W2, **nenhum usuário com `telegram_chat_id` vinculado recebia
resposta a nenhuma mensagem** (texto, localização, foto, etc.) — só o fluxo de `/start`/vincular
contato funcionava, porque é um code path separado (`Casar Telefone`) que não tem esse bug.
Descoberto ao testar o check-in de localização da Juliana (execução `2991`, `Validar Usuario Ativo`
com `itemsInput: 1` e `itemsOutput: 0`).

**Correção aplicada:** trocado para `const usuario = items[0].json;` direto, sem esperar array.
Workflow salvo via `n8n_update_full_workflow` (a atualização parcial recusou salvar por causa dos
nodes WhatsApp dormentes órfãos — ver nota abaixo). Confirmado em produção com `n8n_get_workflow`.

**Efeito colateral do processo de correção:** a ferramenta de atualização parcial (`n8n_update_partial_workflow`)
bloqueia qualquer salvamento se existir node sem nenhuma conexão de entrada/saída — e o W2 tinha 13
nodes WhatsApp dormentes (D-10) desconectados do grafo (órfãos desde o rebuild multicanal, não
apagados mas também não religados aos pontos onde o Telegram os substituiu). Para conseguir salvar a
correção, esses 13 nodes foram reconectados aos mesmos pontos dos seus equivalentes Telegram
(continuam `disabled: true`, nenhum efeito em runtime) via `n8n_update_full_workflow`. Se precisar
editar o W2 de novo com a ferramenta parcial, esse pré-requisito de "todo node conectado" continua
valendo.

---

## B-08 — `estado_conversa` no W2 ainda gravava por `telefone`, coluna que não existe mais — 17 Jul 2026

**✅ RESOLVIDO no mesmo dia.** A migração para D-10 trocou a chave de `estado_conversa` de
`telefone` para `identidade` (`tg:<chat_id>` | `wa:<telefone>`), mas **4 nodes do W2 não foram
atualizados** e continuavam lendo/gravando por `telefone`:

- `Buscar Estado Conversa` — `GET .../estado_conversa?telefone=eq....`
- `Upsert Estado Aguardando Foto`, `Upsert Estado Checkout`, `Upsert Estado Final Checkout` —
  `POST .../estado_conversa?on_conflict=telefone`, corpo com `"telefone": ...`

**Efeito:** erro Postgres `42703 column estado_conversa.telefone does not exist` em qualquer
mensagem de um usuário Telegram que dependesse de estado — ou seja, **todo o fluxo depois do
check-in de localização** (pedir foto, checkout, decisor, produto, fechamento, observação) estava
quebrado. Descoberto no teste da Juliana (execução `3005`).

**Correção aplicada:** os 4 nodes passaram a usar `identidade` (query e `on_conflict`); o node
`Motor de Checkout` passou a propagar `identidade` no objeto de retorno para o upsert final
conseguir referenciar o registro certo.

---

## B-09 — Padrão `Array.isArray(items[0].json)` quebrado em vários code nodes (mesma causa-raiz de B-07) — 17 Jul 2026

**Causa-raiz comum:** o node HTTP Request do n8n, quando a resposta do PostgREST é um array JSON,
**desagrega cada linha em um item próprio** — `items[0].json` já é o objeto da primeira linha, nunca
um array. Um padrão de código copiado em vários code nodes deste workflow assume o contrário
(`const rows = (items.length ? items[0].json : []) || []; if (!Array.isArray(rows) ...)`), o que faz
`Array.isArray()` ser **sempre falso**, mesmo quando a busca encontrou resultado. B-07 já tinha
corrigido essa causa-raiz em `Validar Usuario Ativo`; B-09 é o mesmo bug recorrendo em outros nodes.

**✅ RESOLVIDO (parcial) no mesmo dia — `Calcular Loja Mais Proxima`:** `Buscar Agenda Pendente Hoje`
achava a visita pendente da Juliana corretamente, mas `Calcular Loja Mais Proxima` caía sempre no
fallback "nenhuma visita pendente" por causa desse bug — mesmo com agenda encontrada. Descoberto no
teste da Juliana (execução `3009`: usuário tinha 1 visita pendente, mas
`nenhumaVisitaPendente: 'true'`). Corrigido para ler `$input.all().map(i => i.json)` direto, em vez
de esperar um array dentro de `items[0].json`.

**✅ RESOLVIDO (mais 3 ocorrências) no mesmo dia:**

- `Normalizar Estado` — a mais grave: `Buscar Estado Conversa` achava certinho o estado salvo
  (`aguardando_foto`, contexto com `loja_id`/`agenda_id`/distância), mas `Normalizar Estado` jogava
  tudo fora e resetava para `ocioso`/`{}`, fazendo o roteador (`Rotear Estado`) mandar qualquer
  mensagem seguinte (inclusive a foto da fachada) pro ramo errado. Bloqueava **todo o fluxo depois
  do check-in de localização**. Descoberto na execução `3012` (Juliana mandou a foto, nada
  aconteceu).
- `Avaliar Suspeita` — variante silenciosa (`rows.length` em vez de `Array.isArray`): como
  `items[0].json` de uma config encontrada é um objeto (sem `.length`), a expressão sempre caía no
  fallback `200` **mesmo quando `config.raio_checkin_m` estava configurado**. Não travava porque o
  valor real da config (200) coincidia com o fallback — mas mudar a config não teria efeito nenhum
  em produção sem essa correção.
- `Extrair Loja Contrato Assinado`, `Extrair Contrato Atual Assinatura` — mesmo padrão, caminho de
  comando de texto (`contrato <codcl> assinado`), corrigido por tabela mesmo sem teste direto ainda.

**⚠️ MESMO BUG AINDA PRESENTE (não corrigido, escopo maior — problema arquitetural, não só o
padrão):** `Extrair Contrato Maquininha` (lê de `Extrair Loja Maquininha`, que está pendurado direto
do switch `Rotear Comando` **sem nenhuma busca HTTP de loja por `codcl` antes dele** — não é só
trocar o padrão de leitura, falta o node de busca inteiro). Comando `maquininha <codcl> ativada`
provavelmente não funciona hoje. Corrigir antes de incluir esse comando no checklist de teste
ponta-a-ponta.

---

## B-01 — Adendo (auditoria de 22 Jul 2026, PROMPT 1)

Auditoria node-a-node dos 12 workflows via `mcp__n8n__n8n_get_workflow` (retorna o objeto `credentials`
real por node):

- **Telegram:** todos os nodes Telegram (W0, W1, W2) usam `ROTA-VITA - Telegram - Morgana`
  (`9B3nW4btlkMwlbYj`) — correto. O W0 `Enviar Telegram` **já estava correto** (a premissa do Bloco B,
  de que apontava para a ARMCOM, já havia sido resolvida em 15/07); só a nota do node foi atualizada.
- **Supabase (httpCustomAuth):** todos apontam para `CRED_SUPABASE_ROTAVIVA` (`ueScB1frQvcIityq`).
- **Anthropic (W2):** `ROTA-VIVA - Anthropic`. **Gmail (W4):** `ROTA-VIVIA - Gmail` (`AtQCjRk5DlQ7mcmL`).
  **Google Sheets/Drive:** credenciais Rota Viva. Nenhuma credencial DreamMaker/Copilot/JobTread.
- **WhatsApp ARMCOM ainda presente (dormente, PENDENTE go-live):** `ARMCOM - WhatsApp Cloud API`
  (`qxbrAen7zi4DhywY`) em 6 nodes — W0 (Enviar WhatsApp), W1 (Obter URL do Media, Responder
  Coordenador), W3 (Enviar Rota Diária, Enviar Alerta Rota Vazia), W4 (Enviar WhatsApp Gerente),
  W6 (Enviar Lembrete Retorno); e `ARMCOM - WhatsApp Trigger` (`oWOgKLFpUr5DdRWd`) no W1. **Todos
  `disabled`** e gated por `whatsapp_habilitado=false`. Trocar para `CRED_META_CLOUD` real (junto com
  `phoneNumberId`, também placeholder) antes de qualquer ativação do ramo WhatsApp. Não bloqueia o
  piloto (Telegram é o canal vivo).

Efeito colateral recorrente da ferramenta de edição parcial: ela recusa salvar se qualquer node ficar
sem conexão. Os nodes WhatsApp dormentes órfãos de W3/W4/W6 foram **reconectados** (permanecem
`disabled`) para permitir salvar as mudanças de cron — mesmo padrão do B-07.

---

## B-10 — OAuth do Google Sheets/Drive expirado de novo (bloqueia W5/W7/planilha) — 22 Jul 2026

**Onde ocorre:** a credencial `ROTA-VIVA - Google Sheets` (`V8yK9tJ9nbUTis15`) perdeu o token. Ao
executar o `[RotaViva] Motor Sheets API` para criar a aba **Agenda** (execução `4827`), o node
`Aplicar (Sheets API)` falhou com:

```
NodeApiError: The credential "ROTA-VIVA - Google Sheets" needs to be reconnected.
Access could not be refreshed because the connected account has revoked access, the refresh token
expired, or the account password or permissions changed.
```

É o mesmo B-06 recorrendo (refresh token OAuth expirado). Provavelmente vale também para
`ROTA-VIVA - Google Drive` (`xaChmTzpezR036yv`, W8).

**Impacto (o que ficou pronto mas NÃO testado / pendente de reconexão):**

- **Bloco E (W5):** o ramo de sync da Agenda (`Buscar Agenda nao sync` → `Transformar Agenda` →
  `Upsert Aba Agenda` → `Marcar Agenda sync`) foi **construído e validado estruturalmente** (W5 segue
  inativo). Falta: (a) criar a aba **Agenda** (cabeçalho `id,data,usuario,loja,codcl,origem,status`) —
  o Code node `Montar Requests` do Motor Sheets API já está pronto com o `batchUpdate` (addSheet
  `sheetId:771122` + updateCells do cabeçalho), só re-executar; (b) teste de sync com uma
  `agenda_visitas` de teste (verificação 5).
- **Bloco F (W7):** `Aplicar Config` passou a **emitir aviso** para chave protegida (não ignora mais em
  silêncio) e um node `Escrever Aviso Config` grava o motivo na aba **⚙ Config** (colunas
  `status_sync`/`observacao_sync`, casando por `row_number`). **Não-testado** (Sheets fora). Falta:
  criar as colunas `status_sync`/`observacao_sync` na aba ⚙ Config (via Motor Sheets API) e testar.
- **Bloco G2 (limpeza da planilha):** remover a linha de visita de teste na aba Visitas e a célula
  órfã de e-mails abaixo da tabela da ⚙ Config — **bloqueado** (precisa de escrita no Sheets).

**Ação humana necessária:** abrir a credencial `ROTA-VIVA - Google Sheets` (e `- Google Drive`) no
n8n e concluir o fluxo OAuth ("Connect my account"). Depois: re-executar o Motor Sheets API (aba
Agenda + colunas da Config), testar W5/W7 e fazer o G2.

### ⚠️ Adendo (23 Jul 2026) — B-10 CONTINUA ABERTO após tentativa de reconexão

O PROMPT 1.1 partiu da premissa "B-10 RESOLVIDO: OAuth reconectado". **Não se confirmou no servidor.**
Três tentativas independentes, todas com o mesmo erro
`The credential "ROTA-VIVA - Google Sheets" needs to be reconnected`:

| Tentativa | Como | Execução | Resultado |
|---|---|---|---|
| 1 | HTTP `predefinedCredentialType` (Motor Sheets API) | `4827` (22/07) | falhou |
| 2 | idem, após "reconexão" | `4866` | falhou |
| 3 | **node nativo Google Sheets** (`Ler Aba Config`, W7) | `4867` | falhou |

A tentativa 3 é decisiva: o erro **não** é do node HTTP — o node nativo falha igual, logo o token da
credencial é que está inválido. Também foi descartada a hipótese de credencial nova: `list_credentials`
mostra apenas `ROTA-VIVA - Google Sheets` (`V8yK9tJ9nbUTis15`) e `ROTA-VIVA - Google Drive`
(`xaChmTzpezR036yv`) — nenhuma credencial Google criada depois.

**Continuam bloqueados (inalterados):** aba **Agenda** (o Motor já está com o `batchUpdate` pronto —
addSheet `sheetId:771122` + cabeçalho — basta re-executar), colunas `status_sync`/`observacao_sync` na
aba ⚙ Config, teste do W5 (sync de agenda), teste do W7 e o **G2** (linha de teste da aba Visitas +
célula órfã de e-mails da Config).

**Ao reconectar, confirmar de fato:** executar o `[RotaViva] Motor Sheets API (manual)` e verificar que
a execução termina `success` (não basta a UI dizer "connected"). O Motor foi tornado genérico nesta
sessão: o Code node monta `{ body: {...} }` e o HTTP envia `={{ $json.body }}`, então ele aceita
qualquer payload do `spreadsheets:batchUpdate` (inclusive `includeSpreadsheetInResponse` /
`responseIncludeGridData` para ler metadata e grid).

---

## B-11 — Convergência dupla por node desabilitado (mesma classe do 3040) — 23 Jul 2026

**✅ RESOLVIDO.** Node desabilitado no n8n é **pass-through**: repassa o item adiante. Quando um node
dormente e seu equivalente Telegram ativo apontam para o **mesmo destino**, o destino executa **duas
vezes**. Foi a causa-raiz do 3040 (`Criar Visita`) e reapareceu no ramo de alerta:

`Mapear Destinatarios Alerta` → `Enviar Alerta Checkin (TG)` (ativo) **e** `Enviar Template Checkin
Suspeito` (DESABILITADO) → ambos → `Consolidar Alerta Destinatarios`.

**Efeito:** em todo check-in fora do raio, `Consolidar Alerta Destinatarios` rodava 2x e o promotor
recebia **duas** mensagens "envie a foto da fachada".

**Correção:** removida a conexão de saída do node dormente (`Enviar Template Checkin Suspeito` →
`Consolidar`). O node permanece no canvas, desabilitado, com a conexão de **entrada** preservada (não
vira órfão, então a ferramenta de update parcial continua salvando).

**Auditoria completa do W2 (23/07):** mapeados **todos os 8 pontos de convergência** (nodes que recebem
`main` de 2+ origens). Após a correção, **todos verdes** — nenhum ponto mistura origem desabilitada com
origem ativa. Verificado também que nenhum outro node desabilitado tem aresta de saída (todos os pares
"(TG) ativo + WhatsApp dormente" terminam em nodes-folha).

**Verificação:** execução `4864` — check-in a 990 m (raio 200 m) → `flagSuspeito=true`,
`Consolidar Alerta Destinatarios` com **1 execução**, `Pedir Foto Fachada (TG)` com **1 execução /
1 item**.

**Regra que fica:** ao desabilitar um node, conferir se ele tem aresta de **saída** que reconverge com
um caminho ativo. Se tiver, remover a aresta de saída (não basta desabilitar).

---

## B-09 — Adendo (23 Jul 2026): mais duas ocorrências corrigidas; comando maquininha resolvido

**`Mapear Destinatarios Alerta`** tinha o mesmo padrão quebrado
(`const rows = items[0].json; ... rows.filter(...)`), o que fazia `rows.filter is not a function` e
**matava todo o ramo de alerta de check-in suspeito**. Corrigido para `$input.all().map(i => i.json)`.
Descoberto ao testar a correção B-11 (execução `4863` falhou com esse erro).

**Comando `maquininha <codcl> ativada` — ✅ RESOLVIDO** (era o item explicitamente pendente do B-09).
O caminho não tinha **nenhuma busca HTTP** antes dos code nodes — eles liam um array que nunca chegava.
Construída a cadeia espelhando o caminho irmão "contrato assinado":

```
Rotear Comando (saída 1) → Buscar Loja por Codcl (Maquininha) → Extrair Loja Maquininha
  → Buscar Contrato Atual (Maquininha) → Extrair Contrato Maquininha → Atualizar Contrato Ativo
```

Os dois code nodes também tiveram o padrão `Array.isArray` corrigido.

**Verificação (execução `4865`, end-to-end real contra o Supabase):** `maquininha TESTE001 ativada` →
contrato de teste passou de `assinatura_diretoria` para `etapa='ativo'`, com
`data_ativacao=2026-07-23` e `vigencia_inicio=2026-08-01` (regra de `top_service` = 1º dia do mês
seguinte, D-03). Dado de teste purgado depois.

**Bug latente encontrado no caminho irmão:** `Buscar Contrato Atual (Assinatura)` ordenava por
`order=criado_em.desc`, mas `rotaviva.contratos` **não tem** a coluna `criado_em` (só `atualizado_em`
e `etapa_desde`) — o PostgREST devolveria **400** e o comando `contrato <codcl> assinado` estaria
quebrado. Corrigido para `order=atualizado_em.desc`.

---

## B-12 — `Transcrever Audio` desabilitado entre dois nodes ativos (observação por áudio degradada)

**ABERTO — precisa de decisão.** No W2: `Baixar Audio (Telegram)` (ativo) → `Transcrever Audio`
(**desabilitado**) → `Estruturar Observacao` (ativo). Como node desabilitado é pass-through, o **binário
do áudio chega ao LLM sem transcrição** — a observação por áudio não é transcrita de verdade.

Não é convergência (por isso não entrou no B-11), mas é a mesma família: comportamento silenciosamente
errado por causa de um node desabilitado no meio de um caminho ativo.

**Decisão pendente:** (a) reativar `Transcrever Audio` (node OpenAI — exige credencial OpenAI, que não
existe hoje na conta); (b) trocar por transcrição via outro provedor; ou (c) assumir que a observação
por áudio fica sem transcrição no piloto e ajustar o texto ao usuário. Não alterado nesta sessão por
depender dessa escolha.
