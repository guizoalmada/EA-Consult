# SPEC — Rota Viva (Fase 1)

## 1. Contexto de negócio

Cliente: **DPK**, distribuidora de peças automotivas (MG). Produtos financeiros oferecidos em campo:

- **Autocred** — maquininha de crédito.
- **Top Service** — credenciamento de serviço.

Nada fecha no ato da visita. Fluxo pós-fechamento:

1. Promotor envia documentação do cliente.
2. Setor de cadastro abre chamado no Fluig.
3. Jurídico monta o contrato.
4. Cliente assina eletronicamente.
5. Diretoria assina.
6. Maquininha é enviada e ativada.

Regra específica: para **Top Service**, a vigência começa no **1º dia do mês seguinte** às assinaturas (cliente + diretoria).

A matriz **não reporta** mudanças de etapa de volta ao campo — por isso a esteira comercial usa apenas 3 marcos que o próprio promotor consegue confirmar por WhatsApp (docs enviados / cliente assinou / maquininha ativada), com um bloco intermediário "processamento matriz" que não avança sozinho.

## 2. Equipe

**Os 5 usuários fazem visitas** (D-06), inclusive o coordenador e o gerente. O papel não define quem
visita — isso é `usuarios.faz_visitas`. O papel define quem **recebe alerta**.

| Nome | Papel | Faz visitas | Contato |
|---|---|---|---|
| Danton | Promotor | sim | telefone a cadastrar |
| Guilherme | Promotor | sim | telefone a cadastrar |
| Leonardo Rosa | Consultor | sim | leonardo.rosa@dpk.com.br |
| Anderson Lemos | Coordenador (monta e envia a rota diária, véspera ou até 06:30) | sim | Anderson.lemos@dpk.com.br |
| Jansen Araújo | Gerente MG | sim | jansen.araujo@dpk.com.br / +55 27 99226-1227 |

## 3. Metas e SLA

- Meta diária padrão: 12 visitas/dia (`config.meta_visitas_dia`).
- Meta individual: `usuarios.meta_visitas_dia` sobrepõe a padrão quando preenchida; `NULL` herda a
  padrão. Hoje os 5 estão em `NULL` — a superfície de edição está pendente (ver `BLOQUEIOS.md` B-02).
- Meta do dia da equipe = soma das metas efetivas de quem tinha rota naquele dia.
- 280 visitas/mês.
- Loja fechada **conta como visita realizada** e gera reagendamento automático para o dia útil seguinte.
- SLA padrão: 3 dias em qualquer etapa da esteira comercial (configurável em `config.sla_dias_padrao`).

## 4. Fluxo funcional

### 4.1 Ingestão da rota (W1)

O coordenador envia, pelo WhatsApp, um arquivo XLSX com a rota do dia (colunas: `DATA, PROMO, VEND, CODCL, CNPJ, NOME_CLIENTE, ENDERECO, BAIRRO, CIDADE, FONE, CONTATO, CARACTERISTICA`). O sistema normaliza, faz upsert de lojas, geocodifica endereços novos e popula a agenda de visitas do dia, respondendo com um resumo (visitas, responsáveis, lojas sem geolocalização).

A coluna `PROMO` aceita qualquer um dos 5 usuários que fazem visitas, sem diferenciar maiúsculas/minúsculas e ignorando acentos (`rotaviva.resolver_usuario_por_nome()`). Nome não reconhecido não descarta a linha: a visita entra pendente e **sem responsável**, e os nomes aparecem na confirmação enviada ao coordenador ("3 linhas com responsavel nao reconhecido: ...").

### 4.2 Conversa de campo (W2)

Máquina de estados por telefone (`estado_conversa`):

1. **Ocioso** → o usuário envia localização → sistema busca a visita pendente mais próxima (distância Haversine); se estiver fora do raio de check-in (`config.raio_checkin_m`, padrão 200 m), marca `flag_suspeito` e notifica o coordenador — **exceto se o próprio check-in suspeito for do coordenador, caso em que o alerta escala para o gerente** (D-06); pede foto da fachada.
2. **Aguardando foto** → imagem recebida é salva no Storage, registra check-in, avança para checkout.
3. **Checkout** — sequência de botões nativos do WhatsApp:
   - Falou com o decisor? *Sim / Não / Loja fechada / Contato ausente* — os dois últimos encerram a visita como realizada e criam reagendamento automático (D+1 útil, origem `reagendada`).
   - Interesse em qual produto? *Autocred / Top Service / Ambos / Nenhum*.
   - Se houver interesse e status "Analisar": data de retorno (lista rápida).
   - Se "Fechou": cria oportunidade + contrato (etapa `docs_enviados`) e orienta o promotor a enviar a documentação.
   - Se "Sem interesse": motivo (lista) + houve contraproposta?
   - Observação final (texto ou áudio, ou "não").
4. Áudio de observação → transcrito via Whisper → estruturado em JSON estrito (motivo, contraproposta, data de retorno sugerida, resumo) via Claude Haiku 4.5.
5. Comandos livres de texto (`contrato {codcl} assinado`, `maquininha {codcl} ativada`) atualizam os marcos da esteira.
6. Timeout: estado sem resposta por mais de 2h volta a `ocioso`.

### 4.3 Rotina diária

- **W3 — Rota diária (07:30, seg–sáb):** envia a cada usuário ativo com `faz_visitas=true` e visitas pendentes hoje (incluindo retornos criados pelo W6) a lista de visitas do dia + retornos agendados. Alerta o coordenador quando um promotor ou consultor fica sem rota no dia (coordenador e gerente sem rota não geram alerta — ver D-06).
- **W4 — Relatório diário (18:00, seg–sáb):** agrega visitas realizadas vs. planejadas, ranking do dia (todos os usuários com visitas no período, qualquer papel), % contra a meta efetiva de cada um, acumulado mensal, check-ins suspeitos, oportunidades novas, perdas do dia, contratos parados além do SLA e retornos vencidos. Envia por WhatsApp ao gerente e por e-mail aos 3 destinatários configurados.
- **W5 — Sync to Sheets (push do W2 + cron de resgate 5 min):** replica cada evento (`visitas`, `oportunidades`, `contratos`, `agenda_visitas`) para a planilha **Google Sheets "RotaViva Master"** via node nativo (Append or Update Row, chave = `id` do Supabase). O Google Sheets é a **fonte de verdade** dos dados de negócio; o Supabase atua como outbox durável (`sincronizado`/`sheets_synced_at`). Ver **D-13** (supera D-04/D-07).
- **W6 — Lembrete de retorno (08:00):** avisa o usuário responsável sobre retornos agendados para o dia e os inclui na rota do dia (origem `retorno`). A lógica é toda por `usuario_id`, nunca por papel.
- **W7 — Sync de Entradas (06:00 e 20:30):** lê as abas editáveis **⚙ Config** e **➕ Agenda Manual** da planilha via Google Sheets API e aplica no Supabase (config, `meta_visitas_dia`, visitas manuais). Idempotente por `status_importacao`. Ver D-13.
- **W8 — Export .xlsx de conveniência (21:30):** exporta uma cópia `.xlsx` da planilha via `files.export` do Google Drive para a pasta do projeto (sem parsing/exceljs). Para quem preferir abrir no Excel local.
- **W0 — Enviar Mensagem (roteador):** sub-workflow chamado por todos os demais para enviar por Telegram (padrão) ou WhatsApp (dormente). Ver **D-10**. Dashboard e Ranking vivem na planilha como fórmulas nativas (QUERY/COUNTIFS/SPARKLINE), não são calculados pelo n8n.

## 5. Dados

Ver `supabase/migrations/` para o DDL completo. Resumo das entidades: `usuarios`, `lojas`, `agenda_visitas`, `visitas`, `oportunidades`, `contratos`, `faturamento_pos` (Fase 3, já criada), `config`, `estado_conversa`.

**Arquitetura de dados (D-13):** a partir da v2, a **fonte de verdade dos dados de negócio é a planilha Google Sheets**, não o Supabase. O Supabase (`rotaviva`) mantém `estado_conversa` (latência do bot durante a conversa) e atua como **outbox/auditoria durável**: `visitas`, `oportunidades`, `contratos` e `agenda_visitas` ganham `sincronizado`/`sheets_synced_at`; cada evento é gravado primeiro no Supabase e depois replicado ao Sheets pelo W5. Trade-off consciente (abre mão de ACID no dado de negócio por simplicidade no piloto) — reavaliar se virar produto multi-tenant.

**Canal (D-10):** a comunicação é **multicanal via roteador W0**, com Telegram como padrão do piloto e WhatsApp dormente. `usuarios.canal`, `usuarios.telegram_chat_id`; `estado_conversa` chaveado por `identidade` (`tg:<chat_id>` | `wa:<telefone>`).

## 6. Piloto

Piloto 100% **Telegram** (D-10): cada usuário faz `/start` no bot do Rota Viva e compartilha o contato para vincular o `telegram_chat_id`. Sem burocracia Meta. WhatsApp permanece dormente. Ver `GO-LIVE.md`.
