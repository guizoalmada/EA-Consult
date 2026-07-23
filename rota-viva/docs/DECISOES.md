# Decisões de arquitetura — Rota Viva

Formato ADR curto: contexto, decisão, consequência.

## D-01 — Nodes determinísticos + IA só em áudio/estruturação

**Contexto:** a máquina de estados da conversa de campo (W2) precisa ser previsível e auditável.
**Decisão:** todo o fluxo de botões, validações e transições de estado usa nodes determinísticos do n8n (IF/Switch/Set). IA (Whisper + Claude Haiku 4.5) só entra para transcrever áudio livre e estruturar texto não guiado em JSON.
**Consequência:** comportamento do bot é 100% testável fora dos casos de observação em áudio; custo e latência de IA ficam restritos ao mínimo necessário.

## D-02 — Meta WhatsApp Cloud API oficial (não Z-API)

**Contexto:** existia a opção de usar um provedor não-oficial (Z-API) por custo/simplicidade inicial.
**Decisão:** usar a Meta Cloud API oficial desde o piloto.
**Consequência:** exige criação de app Meta/WABA, verificação de números e submissão de templates (ver `GO-LIVE.md`), mas evita risco de banimento de número e problemas de compliance no médio prazo.

## D-03 — Esteira simplificada em 3 marcos de campo + bloco "processamento matriz"

**Contexto:** a matriz (cadastro/jurídico/diretoria) não expõe eventos de mudança de etapa para o campo.
**Decisão:** a esteira comercial (`contratos.etapa`) usa apenas os marcos que o promotor consegue confirmar (`docs_enviados`, `assinatura_cliente`, `assinatura_diretoria`, `ativo`), com um estado `processamento_matriz` que não avança sozinho — só avança quando o campo informa o próximo marco.
**Consequência:** o relatório gerencial (W4) precisa alertar quando um contrato fica parado além do SLA em `processamento_matriz`, já que ninguém no fluxo automatizado sabe o motivo real do atraso.

## D-04 — Supabase é fonte de verdade; a planilha é espelho read-only

> A ferramenta de planilha mudou de Google Sheets para Excel 365 em 10 Jul 2026 (ver D-07). O
> princípio abaixo continua valendo integralmente.

**Contexto:** a gerência quer visualizar dados em planilha, mas não deve haver duas fontes de verdade.
**Decisão:** toda escrita acontece em Supabase; a planilha do W5 é um espelho incremental, gerado 1x/dia, sem edição prevista de volta ao banco.
**Consequência:** qualquer correção de dado tem que ser feita via conversa (WhatsApp) ou diretamente no Supabase — nunca editando a planilha.

## D-05 — Número de teste Meta no piloto (5 destinatários verificados)

**Contexto:** piloto inicial restrito à equipe DPK listada em `SPEC.md`.
**Decisão:** usar o número de teste da Meta Cloud API, com os 5 telefones da equipe verificados manualmente no piloto, antes de migrar para número de produção.
**Consequência:** limite de destinatários e templates do ambiente de teste da Meta se aplica; migração para produção é um passo futuro fora do escopo desta fase (documentar em `GO-LIVE.md` apenas os passos do piloto).

## D-06 — Todos os usuários fazem visitas; meta individual com fallback na config

> Nota de numeração: o pedido de mudança de 10 Jul 2026 se referia a esta decisão como "D-08".
> Não existem D-06 nem D-07 neste repositório — a última decisão registrada era D-05. Registrada
> aqui como **D-06** para manter a sequência.

**Contexto:** o desenho original tratava visita como atividade exclusiva de `promotor`/`consultor`.
O cliente confirmou que os 5 usuários visitam lojas, incluindo Anderson (coordenador) e Jansen
(gerente). Cada pessoa pode ainda ter uma meta diária diferente das 12 visitas padrão.

**Decisão:**

1. Quem visita passa a ser determinado por `usuarios.faz_visitas` (boolean, default `true`), nunca
   por `usuarios.papel`. O papel continua existindo, mas só decide **quem recebe alerta** (guard de
   ingestão do W1, destinatário do relatório do W4, escalonamento de check-in suspeito do W2).
2. A meta diária é `usuarios.meta_visitas_dia` quando preenchida, com fallback em
   `config.meta_visitas_dia`. A meta do dia da equipe é a **soma das metas efetivas de quem tinha
   rota naquele dia** — não `meta × nº de pessoas`.
3. Quem não tem visita planejada no dia não entra no ranking e não conta como abaixo da meta.
4. Escalonamento: se o check-in suspeito for do **próprio coordenador**, o alerta vai ao **gerente**.
   Nos demais casos, continua indo ao coordenador.
5. A coluna PROMO da planilha de rota é casada de forma case-insensitive e sem acentos, via
   `rotaviva.resolver_usuario_por_nome()`. Nome não reconhecido **não descarta a linha**: a visita é
   importada pendente e sem responsável, e os nomes são listados na confirmação ao coordenador.

**Consequência:**

- `agenda_visitas.usuario_id` passa a ser legitimamente nulo para linhas com PROMO não reconhecido.
  O W4 agrupa essas visitas sob "sem responsavel" no ranking, em vez de perdê-las.
- O W3 envia rota para qualquer pessoa com `faz_visitas=true` e visitas pendentes.
- O alerta de rota vazia continua existindo e continua indo ao coordenador, mas **só é disparado
  quando quem ficou sem rota é promotor ou consultor**. Coordenador e gerente também visitam, porém
  nem sempre têm rota no dia — a ausência de rota deles é normal e não vira alerta diário. Este é o
  único ponto do W3 em que o papel é consultado, e ele decide *sobre quem se alerta*, não quem
  visita.
- A superfície de edição da meta individual ficou pendente (B-02): hoje se define por SQL.
- Nenhum texto de mensagem ao usuário fala mais em "promotor"; usa-se o nome da pessoa ou termo
  neutro ("sua rota", "suas visitas").

## D-07 — Espelho em Excel 365 (OneDrive), não Google Sheets; pasta do projeto no OneDrive

**Contexto:** o resto da operação da Morgana Ops vive no OneDrive, e a documentação do grupo é
mantida em `.md` versionado — não em Google Docs. Manter o Rota Viva no Google Workspace criava
uma segunda superfície para o cliente e para nós.

**Decisão:**

1. O espelho read-only do W5 passa a ser uma **pasta de trabalho Excel 365 no OneDrive**, escrita
   via node `Microsoft Excel 365` (`resource: worksheet`, `operation: upsert`, casando por `id`).
   D-04 não muda: continua sendo espelho, nunca fonte de verdade.
2. `config.gsheets_id` foi renomeada para `config.excel_workbook_id` e passa a guardar o
   **driveItem id** do `.xlsx` no Graph. Vazia = W5 não escreve nada (gate de go-live preservado).
3. A credencial `CRED_GSHEETS` deixa de existir; entra `CRED_MS_EXCEL`.
4. A pasta canônica do projeto passa a ser
   `Morgana Ops\Produtos Próprios\Rota Viva\`, com o repositório clonado em `repo\`.
5. Toda a documentação vive em `.md` dentro do repositório. Não há mais espelhos em Google Docs.

**Consequência:**

- Os Google Docs antigos em `I:\Meu Drive\Rota-Viva\` (SPEC, GO-LIVE, CREDENCIAIS) ficam órfãos e
  desatualizados. Devem ser apagados por quem tem acesso — nenhum processo aponta mais para eles.
- O W5 depende de um app registrado no Azure com `Files.ReadWrite`; ver `CREDENCIAIS.md`.
- O arquivo `.xlsx` precisa ter as 3 abas com cabeçalho, incluindo a coluna `id` (chave do upsert),
  antes da primeira execução. O node não cria a aba nem o cabeçalho.

## D-10 — Arquitetura multicanal com roteador W0; piloto 100% Telegram; WhatsApp dormente

**Contexto:** o piloto precisava ir ao ar sem a burocracia/custo da Meta (app, WABA, verificação de
número, submissão de templates — D-02/D-05). O Telegram é gratuito e imediato.

**Decisão:**

1. Todo envio de mensagem passa por um sub-workflow roteador **W0 "Enviar Mensagem"** (chamado por
   Execute Workflow), com contrato `{ usuario_id|identidade, tipo, variaveis, botoes? }`. O W0 resolve
   o `canal` do usuário e envia por Telegram (padrão) ou WhatsApp (dormente).
2. `usuarios.canal` (default `telegram`) decide o caminho; `usuarios.telegram_chat_id` é gravado no
   `/start` (vinculação por contato no W2). `estado_conversa` é re-chaveado por `identidade`
   (`tg:<chat_id>` | `wa:<telefone>`).
3. Os nodes WhatsApp existentes **não são apagados** — ficam no canvas, dormentes, gated por
   `config.whatsapp_habilitado=false`. Nada é criado ou alterado na Meta.

**Consequência:** supera D-02 e D-05 (Meta oficial no piloto). O cliente pode permanecer no Telegram
em produção. Risco operacional registrado: só existe uma credencial `telegramApi` na conta n8n (de
outro cliente), e ela é auto-associada aos nodes Telegram — ver B-01. Trocar antes do go-live.

## D-13 — Google Sheets é a fonte de verdade dos dados de negócio; Supabase vira outbox/auditoria

**Contexto:** as tentativas anteriores de "planilha" esbarraram em fricção de ferramenta: o node
Microsoft Excel 365/OneDrive (D-07) reintroduzia dependência do tenant Microsoft da DPK; gerar
`.xlsx` via ExcelJS dentro do Code node é impossível no n8n atual (B-04 — `exceljs`/`xlsx` bloqueados);
e o Excel Online via Microsoft Graph exigiria consentimento OAuth do tenant (mesmo risco de bloqueio
corporativo, não testado). O cliente quer um dashboard interativo e uma superfície editável simples.

**Decisão:**

1. A planilha **"RotaViva Master" no Google Sheets** passa a ser a **fonte de verdade dos dados de
   negócio** (visitas, oportunidades, contratos, ranking, dashboard, config, agenda manual) — não
   mais um espelho read-only do Supabase. Isso **supera D-04** (Supabase como fonte única / planilha
   read-only) e **D-07** (Excel 365), e substitui o desenho intermediário de `.xlsx` no Drive (planejado
   como D-11/D-12, nunca implementado).
2. O **Supabase (`rotaviva`)** muda de papel: continua guardando `estado_conversa` (necessário por
   latência durante a conversa do bot) e passa a servir como **outbox/log de auditoria durável** —
   todo evento é gravado lá primeiro (`sincronizado=false`) e depois replicado ao Sheets pelo W5
   (push imediato do W2 + cron de resgate a cada 5 min). Garante contra falha de rede na escrita do Sheets.
3. **Dashboard e Ranking não são calculados pelo n8n** — são abas de **fórmulas nativas do Google
   Sheets** (QUERY, COUNTIFS, SPARKLINE/REPT) sobre as abas de dados. Atualizam sozinhas a cada escrita.
4. O W5 escreve célula a célula via node nativo **Google Sheets** ("Append or Update Row", chave de
   upsert = `id` do Supabase numa coluna auxiliar), nunca regenera o arquivo. O W7 lê Config/Agenda
   Manual via Google Sheets API. Um W8 opcional exporta um `.xlsx` de conveniência via `files.export`
   do Drive (sem parsing, sem exceljs) para quem preferir Excel local.

**Consequência:** abre-se mão de ACID/constraints no dado de negócio em troca de simplicidade e menor
custo — **decisão consciente do cliente, aceitável no piloto**. Reavaliação registrada como decisão
adiada caso o projeto vire produto multi-tenant. B-04 fica **resolvido por mudança de arquitetura**
(não foi preciso liberar `exceljs` no servidor). Proibido, daqui em diante, node Microsoft Excel/OneDrive
e Code node com libs externas de planilha em qualquer ponto do projeto.

## D-14 — Foto do check-in não é mais armazenada; é encaminhada ao coordenador em tempo real

**Contexto:** o desenho original (W2) baixava a foto da fachada enviada no check-in e subia pro
Supabase Storage (`rotaviva-fotos/{agenda_id}.jpg`), gravando o caminho em `visitas.foto_url` —
pensado como evidência auditável depois. No teste piloto (17 Jul 2026), o Guilherme pediu pra trocar
isso por um encaminhamento direto da foto pro coordenador via Telegram, sem salvar em lugar nenhum.

**Decisão:**

1. O node `Buscar Coordenador Notificacao` busca o primeiro usuário `papel=coordenador`, `ativo=true`
   e com `telegram_chat_id` preenchido; `Montar Legenda Foto` monta a legenda ("Chegada registrada:
   `<nome>` · Loja: `<nome da loja>` · localização conferida/não conferida", sem coordenadas); `Enviar
   Foto Coordenador` reenvia a foto **por `file_id` do Telegram** (não baixa nem re-hospeda o binário
   — o Telegram permite reenviar um arquivo já recebido por outro chat direto pelo id).
2. `visitas.foto_url` deixa de ser preenchido (fica `null`). O registro de `visitas` continua sendo
   criado normalmente (check-in, distância, `flag_suspeito`, etc.) — só a foto em si não é mais
   persistida em nenhum storage do projeto.
3. Os nodes antigos (`Baixar Foto (Telegram)`, `Upload Foto Storage`, `Preparar Contexto Apos Upload`)
   foram **desativados, não apagados** — ficam no canvas como registro de como funcionava antes,
   mesmo padrão usado para os nodes WhatsApp dormentes (D-10).
4. Destinatário no piloto: só o(s) usuário(s) com `papel=coordenador` — sem escalonamento pro gerente
   (diferente da regra do check-in suspeito, D-06). Hoje isso aponta pro registro de teste `Guilherme
   Almada (teste)`, já que nem Anderson (coordenador real) nem Jansen (gerente) têm `telegram_chat_id`
   vinculado ainda.

**Consequência — risco aceito conscientemente:** a foto deixa de ser uma evidência **consultável
depois**. Sem storage, não existe mais como abrir a visita de uma data passada e ver a foto de novo —
ela só existe no histórico do chat do Telegram de quem recebeu, sujeita a limpeza de conversa, saída
do bot do grupo, ou simplesmente ninguém rolar pra trás. Se no futuro precisar de auditoria
retroativa (disputa com loja, conferência de visita antiga), essa decisão precisa ser revisitada —
reintroduzir o storage é reversível (os nodes desativados continuam no canvas, só reconectar e
reativar).

## D-15 — Mapa de promotores da rota via planilha, com validação

**Contexto:** o W1 importa a rota a partir da planilha enviada pelo coordenador; a coluna PROMO traz nomes livres.
**Decisão:** o casamento nome→usuário é feito por `rotaviva.resolver_usuario_por_nome()` (case-insensitive, sem acento). Nome não reconhecido **não descarta a linha** — a visita é importada pendente e sem responsável, e os nomes não reconhecidos são listados na confirmação ao coordenador.
**Consequência:** `agenda_visitas.usuario_id` pode ser legitimamente nulo. Implementação detalhada no Prompt 2 (reforma do W1).

## D-17 — Calendário operacional é segunda a sexta

**Contexto:** a operação de campo não roda aos sábados no piloto.
**Decisão:** todos os crons de W3 (rota diária), W4 (relatório) e W6 (lembrete de retorno) usam `1-5` (seg–sex).
**Consequência (aplicado neste prompt):** W3 `0 30 7 * * 1-6`→`0 30 7 * * 1-5`; W4 `0 0 18 * * 1-6`→`0 0 18 * * 1-5`; W6 `0 0 8 * * *`→`0 0 8 * * 1-5`.

## D-18 — Importar apenas datas ≥ hoje; reimportação substitui a janela por promotor+período

**Contexto:** o coordenador reenvia a planilha de rota; não se deve duplicar nem sobrescrever histórico passado.
**Decisão:** o W1 importa somente linhas com data ≥ hoje; uma reimportação substitui a janela (promotor + período) em vez de acumular.
**Consequência:** implementação no Prompt 2 (reforma do W1). Registrado agora como enunciado vinculante.

## D-19 — Estado de conversa expira em 4 horas

**Contexto:** um estado de conversa preso (ex.: `aguardando_foto` de horas atrás) roteava mensagens novas para o ramo errado.
**Decisão:** estado com `atualizado_em` anterior a agora−4h é descartado (tratado como `ocioso`) e a linha em `estado_conversa` é apagada; o fluxo recomeça limpo.
**Consequência (aplicado neste prompt):** no W2, entre `Buscar Estado Conversa` e `Normalizar Estado`, um IF `Estado Expirado?` roteia estados expirados para um DELETE (`Expirar Estado Conversa`) antes de normalizar como ocioso. Validado na execução de teste 4826.

## D-20 — Interatividade por botões nos campos fechados

**Decisão:** onde a resposta do campo é de domínio fechado (produto, fechou/analisar, motivo, contraproposta, data de retorno), o bot usa botões/listas do Telegram em vez de texto livre.
**Consequência:** já refletido no Motor de Checkout do W2. Registrado como enunciado.

## D-21 — W5 permanece manual durante a homologação

**Decisão:** o W5 (Sync to Sheets) não é ativado na homologação; roda por execução manual. O push imediato a partir do W2 fica desabilitado (ver A6 abaixo), com o cron de resgate cobrindo o sync via outbox quando o W5 for ativado.
**Consequência:** o `Chamar W5 (push sync)` do W2 foi **desabilitado** neste prompt; `config.sync_push_habilitado=true` fica registrado para reativação no go-live. Isso também resolveu a dependência de publish (n8n exige sub-workflow referenciado publicado — ver BLOQUEIOS).

## D-22 — Foto do check-in não vai para storage; prova por encaminhamento + código

**Contexto:** evolução de D-14. A foto não é persistida em storage.
**Decisão:** a prova da visita é o **encaminhamento da foto ao coordenador** somado a `visitas.foto_file_id` (file_id do Telegram) e `visitas.foto_codigo` (código curto `V-####` sequencial, único, gerado por default de sequência no banco). Auditoria futura localiza a foto no chat do coordenador pelo código.
**Consequência (aplicado):** colunas `foto_file_id`, `foto_codigo`, `motivo_suspeita` criadas em `visitas`; W2 grava `foto_file_id` e deixa o banco gerar `foto_codigo`; a legenda ao coordenador traz nome da loja, codcl e código.

## D-23 — Foto encaminhada no Telegram marca a visita como suspeita

**Decisão:** se a foto de check-in tiver `forward_origin`/`forward_date` (encaminhada), a visita recebe `flag_suspeito=true` e `motivo_suspeita='foto_encaminhada'`, e a legenda ao coordenador sinaliza `⚠ foto_encaminhada`.
**Consequência (aplicado):** `Normalizar Telegram` extrai `forwardOrigin`; `Gerar Codigo da Foto` decide o motivo. A suspeita por distância grava `motivo_suspeita='fora_do_raio'`. Validado na execução de teste 4825.

## D-24 — Geocodificação via Nominatim/OSM

**Decisão:** geocodificação de endereços de loja usa Nominatim/OpenStreetMap (gratuito, ~1 req/s), sem provedores pagos por ora.
**Consequência:** implementação no Prompt 2 (reforma do W1). Registrado agora como enunciado.

## D-25 — Modelo de dois eixos: `resultado` (operacional) × `resultado_comercial` (comercial)

**Contexto:** o enunciado do prompt supunha que `visitas.resultado` e `visitas.status_1` tivessem semânticas sobrepostas e pedia unificação. A auditoria do Motor de Checkout (W2) mostrou o contrário.
**Decisão:** os dois campos são **ortogonais** e ambos permanecem:
- `resultado` — **eixo operacional**: como a visita transcorreu (`normal`/`loja_fechada`/`contato_ausente`), gravado na etapa `decisor`.
- `resultado_comercial` (ex-`status_1`) — **eixo comercial**: desfecho de venda (`fechou`/`analisar`/`sem_interesse`), gravado nas etapas `fechou_ou_analisar`/`data_retorno`/`contraproposta`.

Como o banco estava vazio (custo de rename = zero), a coluna `status_1` foi **renomeada** para `resultado_comercial` para eliminar a ambiguidade de nome. Os três pontos de uso foram atualizados: Motor de Checkout (W2), query de perdas do W4 (`resultado_comercial=eq.sem_interesse`) e o transform da aba Visitas do W5.
**Consequência:** dropar `status_1` teria quebrado a query de perdas do W4; manter os dois eixos preserva a semântica. Migration `renomear_status_1_para_resultado_comercial_d25`.
