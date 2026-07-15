# GO-LIVE — Rota Viva

Runbook com todos os passos manuais restantes para colocar o Rota Viva no ar. A infraestrutura
(schema Supabase, workflows n8n salvos inativos, documentação) já está pronta. Siga a ordem abaixo.

> **⚠ Atualização v2 (D-10 / D-13):** o **piloto roda 100% no Telegram** (canal padrão via roteador
> W0) e a **planilha é Google Sheets** (fonte de verdade — ver seção 7). As **seções 1–4 abaixo
> (app Meta, templates, webhook WhatsApp) são "produção futura" e ficam DORMENTES** — não execute no
> piloto. O onboarding Telegram (criar bot no @BotFather → `CRED_TELEGRAM_BOT`; cada usuário faz
> `/start` e compartilha o contato para vincular `telegram_chat_id`) é finalizado junto com o rebuild
> do W2. Os passos de credenciais/Supabase (seções 5–6), a planilha (seção 7), a ativação (seção 8) e
> o teste (seção 9) já refletem a arquitetura v2. **Pendências de build por queda de MCP nesta
> sessão: ver `BLOQUEIOS.md` B-05.**

## 1. Criar app Meta + WABA, obter token e phone_number_id

1. Acesse https://developers.facebook.com/ e crie um App tipo "Business".
2. Adicione o produto **WhatsApp** ao app.
3. Em WhatsApp → API Setup, crie/associe uma WABA (WhatsApp Business Account) e obtenha:
   - **Phone Number ID** (do número de teste fornecido pela Meta).
   - **Token de acesso temporário** (24h) para testes iniciais.
4. Para um token permanente (necessário antes de ativar de verdade): vá em Business Settings →
   System Users → crie um System User com papel Admin, gere um token de acesso permanente com os
   escopos `whatsapp_business_messaging` e `whatsapp_business_management`, associado ao app criado.
5. Configure a credencial `CRED_META_CLOUD` no n8n com esse token + phone_number_id (ver
   `CREDENCIAIS.md`).

## 2. Verificar os 5 telefones no número de teste da Meta

No número de teste, a Meta só entrega mensagens para destinatários verificados manualmente. Em
WhatsApp → API Setup → "To", adicione e verifique (via código enviado por SMS/WhatsApp) os 5
telefones da equipe piloto:

- Danton (promotor)
- Guilherme (promotor)
- Leonardo Rosa (consultor) — leonardo.rosa@dpk.com.br
- Anderson Lemos (coordenador) — Anderson.lemos@dpk.com.br
- Jansen Araújo (gerente) — +55 27 99226-1227

## 3. Submeter os 5 templates à Meta

Em WhatsApp Manager → Message Templates → Create Template, categoria **Utility**, idioma
**Português (BR)**, submeta os 5 templates abaixo com o texto exato (variáveis `{{1}}`, `{{2}}`...
na ordem indicada). Aguarde aprovação (normalmente minutos a poucas horas) antes de ativar os
workflows que os usam.

### 3.1 `rota_diaria`

```
Bom dia, {{1}}! Sua rota de {{2}} tem {{3}} visita(s):
{{4}}
Retornos agendados para hoje: {{5}}
```

Variáveis: `{{1}}` nome do usuário · `{{2}}` data (dd/mm) · `{{3}}` quantidade de visitas ·
`{{4}}` lista numerada de lojas (nome, bairro, contato, telefone) · `{{5}}` lista de retornos
agendados para o dia (ou "nenhum").

### 3.2 `lembrete_retorno`

```
Olá, {{1}}! Você tem um retorno agendado hoje na loja {{2}} ({{3}}). Contato: {{4}}.
```

Variáveis: `{{1}}` nome do usuário · `{{2}}` nome da loja · `{{3}}` bairro · `{{4}}`
telefone/contato.

### 3.3 `relatorio_diario_gerente`

```
Relatório Rota Viva — {{1}}
Visitas: {{2}}/{{3}} planejadas ({{4}}% da meta)
Acumulado mês: {{5}}/280
Check-ins suspeitos: {{6}}
Oportunidades novas: {{7}}
Contratos parados além do SLA: {{8}}
```

Variáveis: `{{1}}` data · `{{2}}` visitas realizadas · `{{3}}` visitas planejadas · `{{4}}` % da
meta · `{{5}}` acumulado do mês · `{{6}}` qtd. check-ins suspeitos · `{{7}}` qtd. oportunidades
novas · `{{8}}` qtd. contratos parados além do SLA.

### 3.4 `alerta_rota_vazia`

```
Atenção, {{1}}: a rota de {{2}} está vazia para {{3}}. Verifique se a planilha foi enviada corretamente.
```

Variáveis: `{{1}}` nome do coordenador · `{{2}}` data · `{{3}}` nome do usuário sem rota.

### 3.5 `checkin_suspeito`

```
Alerta: check-in de {{1}} na loja {{2}} foi registrado a {{3}}m de distância (acima do limite de {{4}}m). Verifique.
```

Variáveis: `{{1}}` nome do usuário · `{{2}}` nome da loja · `{{3}}` distância em metros · `{{4}}`
raio configurado em metros.

## 4. Configurar o webhook da Meta

Em WhatsApp → Configuration → Webhook, aponte para as URLs de produção dos workflows W1 e W2
(disponíveis em cada workflow → node WhatsApp Trigger → aba "Webhook URLs", **depois** de ativar o
workflow no passo 8). Assine os campos `messages`.

## 5. Configurar as demais credenciais

Siga a tabela completa em `CREDENCIAIS.md` para: `CRED_SUPABASE_ROTAVIVA`, `CRED_GMAIL_RELATORIO`,
`CRED_MS_EXCEL`, `CRED_OPENAI_WHISPER`, `CRED_ANTHROPIC`, `CRED_GEOCODING`.

**🛑 BLOQUEANTE (ver `BLOQUEIOS.md` B-01):** os nodes WhatsApp e Anthropic dos workflows do Rota Viva
estão hoje, **na instância n8n**, vinculados por `id` funcional às credenciais reais da ARMCOM
("ARMCOM - WhatsApp Cloud API" `qxbrAen7zi4DhywY`, "ARMCOM - WhatsApp Trigger" `oWOgKLFpUr5DdRWd`,
"ARMCOM - Anthropic" `KRPStNscv88T1xYa`). Ativar qualquer workflow nesse estado dispara mensagens
reais pela WABA de outro cliente.

Antes de ativar qualquer coisa, abra **cada** node abaixo na UI do n8n e troque explicitamente a
credencial para a do Rota Viva:

- W1 — WhatsApp Trigger · Obter URL do Media · Baixar Arquivo da Rota · Responder Coordenador
- W2 — WhatsApp Trigger · Pedir Foto Fachada · Buscar URL Midia Foto · Buscar URL Midia Audio ·
  Enviar Texto Checkout · Enviar Template Checkin Suspeito · Avisar Sem Visita Pendente ·
  Confirmar Contrato Assinado · Confirmar Maquininha Ativada · Transcrever Audio ·
  **Modelo Anthropic Claude Haiku**
- W3 — Enviar Rota Diária · Enviar Alerta Rota Vazia
- W4 — Enviar WhatsApp Gerente
- W6 — Enviar Lembrete Retorno

Confirme com `list_credentials` (ou na UI) que nenhum node do Rota Viva referencia um id de
credencial cujo nome comece por "ARMCOM - ". Os nodes Supabase (`httpCustomAuth`) não têm credencial
vinculada e falham fechado — precisam receber `CRED_SUPABASE_ROTAVIVA`.

Antes de testar qualquer chamada ao Supabase, confirme que o schema `rotaviva` está na lista de
"Exposed schemas" do PostgREST: Supabase Dashboard → projeto Morgana Ops → Project Settings → API →
Data API Settings → Exposed schemas → adicionar `rotaviva` → Save.

## 6. Cadastrar os telefones dos usuários no Supabase

Rode no SQL Editor do projeto Morgana Ops (schema `rotaviva`), substituindo pelos números reais em
formato E.164:

```sql
update rotaviva.usuarios set telefone = '+55XXXXXXXXXXX' where nome = 'Danton';
update rotaviva.usuarios set telefone = '+55XXXXXXXXXXX' where nome = 'Guilherme';
update rotaviva.usuarios set telefone = '+55XXXXXXXXXXX' where nome = 'Leonardo Rosa';
update rotaviva.usuarios set telefone = '+55XXXXXXXXXXX' where nome = 'Anderson Lemos';
-- Jansen Araújo já está cadastrado com +5527992261227; confirme se está correto:
select nome, telefone, papel from rotaviva.usuarios order by nome;
```

## 7. Criar a planilha Google Sheets "RotaViva Master" (D-13)

O espelho Excel/OneDrive foi substituído: a planilha **Google Sheets é a fonte de verdade** dos
dados de negócio. Crie (uma vez) a planilha **"RotaViva Master"** na pasta do Drive
`1f30JmulRQ0deksfTYtMregOop8zKVWQk`, com **7 abas nesta ordem**:

1. **📊 Dashboard** — só fórmulas (QUERY/COUNTIFS/SPARKLINE) sobre Visitas/Oportunidades/Contratos.
2. **Visitas** — dados (escrita pelo W5). Linha 1 banner "⚠ Gerada automaticamente"; cabeçalho congelado; aba protegida. Inclua a coluna auxiliar `id` (chave de upsert do Supabase).
3. **Oportunidades** — dados (W5), mesma proteção e coluna `id`.
4. **Contratos** — dados (W5), mesma proteção e coluna `id`.
5. **Ranking** — só fórmulas (QUERY/COUNTIFS sobre Visitas).
6. **⚙ Config** — editável (lida pelo W7). Colunas: `chave`, `valor`, `descricao`. Inclua linhas `meta_visitas_dia:<nome>` por usuário.
7. **➕ Agenda Manual** — editável (lida pelo W7). Colunas: `data`, `cod_loja`, `responsavel`, `status_importacao`, `observacao_erro`.

Pegue o **spreadsheetId** (o id na URL da planilha) e grave em `config`:

```sql
update rotaviva.config set valor = '<SPREADSHEET_ID>' where chave = 'google_sheets_id';
```

Enquanto essa chave estiver vazia, o W5/W7 encerram sem escrever/ler nada. **Não há mais node
Microsoft/Excel nem geração de `.xlsx` via código** — o W8 apenas exporta uma cópia `.xlsx` da
própria planilha via Google Drive (`files.export`), para quem preferir Excel local.

## 8. Ativar os workflows na ordem

Garanta que o sub-workflow **`[RotaViva] W0 - Enviar Mensagem`** exista (é chamado por todos; não tem
trigger para ativar). Depois ative (toggle "Active") nesta ordem:

1. `[RotaViva] W2 - Conversa Campo`
2. `[RotaViva] W1 - Ingestão Rota`
3. `[RotaViva] W3 - Rota Diária`
4. `[RotaViva] W6 - Lembrete Retorno`
5. `[RotaViva] W4 - Relatório Diário`
6. `[RotaViva] W5 - Sync to Sheets`
7. `[RotaViva] W7 - Sync de Entradas`
8. `[RotaViva] W8 - Export XLSX`

(W2 primeiro porque recebe as mensagens do bot; os agendados por último para revisar os interativos
em produção antes de ligar os cron jobs.)

## 9. Teste ponta-a-ponta

Checklist de 13 itens antes de considerar o piloto no ar:

- [ ] 1. Coordenador envia planilha de rota (XLSX) pelo WhatsApp → recebe confirmação com
      contagem de visitas/responsáveis/lojas sem geolocalização (W1).
- [ ] 2. Usuário envia localização dentro do raio configurado → recebe pedido de foto da
      fachada, sem alerta de suspeita (W2).
- [ ] 3. Usuário envia localização fora do raio configurado → coordenador (Anderson) recebe
      template `checkin_suspeito` (W2).
- [ ] 4. Usuário responde "Loja fechada" no checkout → visita é registrada como realizada e uma
      nova visita aparece agendada para o próximo dia útil (W2).
- [ ] 5. Usuário completa um fechamento (produto + "Fechou") → oportunidade e contrato são
      criados com etapa `docs_enviados` (W2).
- [ ] 6. Usuário envia uma observação em ÁUDIO → transcrição e estruturação aparecem corretamente
      na visita (W2, Whisper + Claude Haiku).
- [ ] 7. Um retorno agendado para hoje gera lembrete ao responsável pela manhã e aparece na rota do
      dia (W6 + W3).
- [ ] 8. Relatório diário chega por WhatsApp ao gerente às 18h (W4).
- [ ] 9. Relatório diário chega por e-mail aos 3 destinatários da config às 18h (W4).
- [ ] 10. Uma visita finalizada aparece na aba **Visitas** do Google Sheets em poucos minutos (W5, push do W2); o **Dashboard** recalcula sozinho (fórmulas).

Itens de D-13 (Google Sheets fonte de verdade + outbox):

- [ ] 14. Editar uma linha na aba **⚙ Config** (ex.: `meta_visitas_dia:<nome>`) → o W7 aplica no Supabase na próxima execução (06:00/20:30); valor inválido não é aplicado e vira aviso no relatório 18h.
- [ ] 15. Preencher uma linha na aba **➕ Agenda Manual** (data ≥ hoje, cod_loja válido, responsável ativo) → vira visita agendada (`origem='manual'`) e a célula `status_importacao` recebe "✔ importada …"; linha inválida recebe "✖ erro" + motivo.
- [ ] 16. Forçar `sincronizado=false` num registro já sincronizado → o **cron de resgate do W5 (5 min)** o replica de novo ao Sheets e volta a marcar `sincronizado=true`.
- [ ] 17. Vinculação Telegram: cada usuário faz `/start` no bot e compartilha o contato → `telegram_chat_id` gravado; telefone não cadastrado é orientado a procurar o coordenador (não cria usuário). (D-10)

Itens de D-06 (todos os usuários fazem visitas):

- [ ] 11. Check-in feito pelo **Jansen (gerente)** aparece no ranking do relatório diário (W4), e
      ele recebe rota às 07:30 se tiver visitas pendentes (W3).
- [ ] 12. Check-in suspeito simulado do **Anderson (coordenador)** notifica o **Jansen (gerente)**,
      e não o próprio Anderson (W2, escalonamento).
- [ ] 13. Planilha de rota com um nome desconhecido na coluna PROMO (ex.: "MARCOS") → a linha é
      importada como visita pendente **sem responsável**, e a confirmação ao coordenador lista
      "1 linha com responsavel nao reconhecido: MARCOS" (W1).

Meta individual (opcional, enquanto B-02 não é resolvido): defina uma meta diferente por SQL e
confirme que o % no relatório usa a meta efetiva.

```sql
update rotaviva.usuarios set meta_visitas_dia = 4 where nome = 'Jansen Araújo';
```
