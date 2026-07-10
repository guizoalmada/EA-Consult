# GO-LIVE — Rota Viva

Runbook com todos os passos manuais restantes para colocar o Rota Viva no ar. A infraestrutura
(schema Supabase, workflows n8n salvos inativos, documentação) já está pronta. Siga a ordem abaixo.

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

Variáveis: `{{1}}` nome do promotor · `{{2}}` data (dd/mm) · `{{3}}` quantidade de visitas ·
`{{4}}` lista numerada de lojas (nome, bairro, contato, telefone) · `{{5}}` lista de retornos
agendados para o dia (ou "nenhum").

### 3.2 `lembrete_retorno`

```
Olá, {{1}}! Você tem um retorno agendado hoje na loja {{2}} ({{3}}). Contato: {{4}}.
```

Variáveis: `{{1}}` nome do promotor · `{{2}}` nome da loja · `{{3}}` bairro · `{{4}}`
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

Variáveis: `{{1}}` nome do coordenador · `{{2}}` data · `{{3}}` nome do promotor/consultor sem
rota.

### 3.5 `checkin_suspeito`

```
Alerta: check-in de {{1}} na loja {{2}} foi registrado a {{3}}m de distância (acima do limite de {{4}}m). Verifique.
```

Variáveis: `{{1}}` nome do promotor · `{{2}}` nome da loja · `{{3}}` distância em metros · `{{4}}`
raio configurado em metros.

## 4. Configurar o webhook da Meta

Em WhatsApp → Configuration → Webhook, aponte para as URLs de produção dos workflows W1 e W2
(disponíveis em cada workflow → node WhatsApp Trigger → aba "Webhook URLs", **depois** de ativar o
workflow no passo 8). Assine os campos `messages`.

## 5. Configurar as demais credenciais

Siga a tabela completa em `CREDENCIAIS.md` para: `CRED_SUPABASE_ROTAVIVA`, `CRED_GMAIL_RELATORIO`,
`CRED_GSHEETS`, `CRED_OPENAI_WHISPER`, `CRED_ANTHROPIC`, `CRED_GEOCODING`.

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

## 7. Criar a planilha Google Sheets do espelho

Crie uma planilha nova no Google Drive com 3 abas: `visitas`, `oportunidades`, `contratos`
(cabeçalhos correspondentes às colunas de cada tabela — ver `supabase/migrations/`). Copie o ID da
planilha (da URL) e grave em `config`:

```sql
update rotaviva.config set valor = '<ID_DA_PLANILHA>' where chave = 'gsheets_id';
```

## 8. Ativar os workflows na ordem

No n8n, ative (toggle "Active") os workflows importados de `n8n/workflows/` nesta ordem:

1. `[RotaViva] W2 - Conversa Campo`
2. `[RotaViva] W1 - Ingestão Rota`
3. `[RotaViva] W3 - Rota Diária`
4. `[RotaViva] W6 - Lembrete Retorno`
5. `[RotaViva] W4 - Relatório Diário`
6. `[RotaViva] W5 - Espelho Sheets`

(W2 primeiro porque W1 depende do mesmo número/webhook já estar recebendo mensagens; os workflows
agendados por último para dar tempo de revisar os dois primeiros em produção antes de ligar os
cron jobs.)

## 9. Teste ponta-a-ponta

Checklist de 10 itens antes de considerar o piloto no ar:

- [ ] 1. Coordenador envia planilha de rota (XLSX) pelo WhatsApp → recebe confirmação com
      contagem de visitas/promotores/lojas sem geolocalização (W1).
- [ ] 2. Promotor envia localização dentro do raio configurado → recebe pedido de foto da
      fachada, sem alerta de suspeita (W2).
- [ ] 3. Promotor envia localização fora do raio configurado → coordenador recebe template
      `checkin_suspeito` (W2).
- [ ] 4. Promotor responde "Loja fechada" no checkout → visita é registrada como realizada e uma
      nova visita aparece agendada para o próximo dia útil (W2).
- [ ] 5. Promotor completa um fechamento (produto + "Fechou") → oportunidade e contrato são
      criados com etapa `docs_enviados` (W2).
- [ ] 6. Promotor envia uma observação em ÁUDIO → transcrição e estruturação aparecem corretamente
      na visita (W2, Whisper + Claude Haiku).
- [ ] 7. Um retorno agendado para hoje gera lembrete ao promotor pela manhã e aparece na rota do
      dia (W6 + W3).
- [ ] 8. Relatório diário chega por WhatsApp ao gerente às 18h (W4).
- [ ] 9. Relatório diário chega por e-mail aos 3 destinatários da config às 18h (W4).
- [ ] 10. Espelho no Google Sheets é atualizado às 21h com os dados do dia (W5).
