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

| Nome | Papel | Contato |
|---|---|---|
| Danton | Promotor | telefone a cadastrar |
| Guilherme | Promotor | telefone a cadastrar |
| Leonardo Rosa | Consultor (também visita) | leonardo.rosa@dpk.com.br |
| Anderson Lemos | Coordenador (monta e envia a rota diária, véspera ou até 06:30) | Anderson.lemos@dpk.com.br |
| Jansen Araújo | Gerente MG | jansen.araujo@dpk.com.br / +55 27 99226-1227 |

## 3. Metas e SLA

- 12 visitas/dia por pessoa de campo.
- 280 visitas/mês.
- Loja fechada **conta como visita realizada** e gera reagendamento automático para o dia útil seguinte.
- SLA padrão: 3 dias em qualquer etapa da esteira comercial (configurável em `config.sla_dias_padrao`).

## 4. Fluxo funcional

### 4.1 Ingestão da rota (W1)

O coordenador envia, pelo WhatsApp, um arquivo XLSX com a rota do dia (colunas: `DATA, PROMO, VEND, CODCL, CNPJ, NOME_CLIENTE, ENDERECO, BAIRRO, CIDADE, FONE, CONTATO, CARACTERISTICA`). O sistema normaliza, faz upsert de lojas, geocodifica endereços novos e popula a agenda de visitas do dia, respondendo com um resumo (visitas, promotores, lojas sem geolocalização).

### 4.2 Conversa de campo (W2)

Máquina de estados por telefone (`estado_conversa`):

1. **Ocioso** → promotor envia localização → sistema busca a visita pendente mais próxima (distância Haversine); se estiver fora do raio de check-in (`config.raio_checkin_m`, padrão 200 m), marca `flag_suspeito` e notifica o coordenador; pede foto da fachada.
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

- **W3 — Rota diária (07:30, seg–sáb):** envia a cada promotor/consultor a lista de visitas do dia + retornos agendados. Alerta o coordenador se a rota do dia estiver vazia.
- **W4 — Relatório diário (18:00, seg–sáb):** agrega visitas realizadas vs. planejadas, % vs. meta, acumulado mensal, check-ins suspeitos, oportunidades novas, perdas do dia, contratos parados além do SLA e retornos vencidos. Envia por WhatsApp ao gerente e por e-mail aos 3 destinatários configurados.
- **W5 — Espelho Sheets (21:00):** sincroniza incrementalmente `visitas`, `oportunidades`, `contratos` para uma planilha Google (somente leitura).
- **W6 — Lembrete de retorno (08:00):** avisa o promotor responsável sobre retornos agendados para o dia e os inclui na rota do dia (origem `retorno`).

## 5. Dados

Ver `supabase/migrations/` para o DDL completo. Resumo das entidades: `usuarios`, `lojas`, `agenda_visitas`, `visitas`, `oportunidades`, `contratos`, `faturamento_pos` (Fase 3, já criada), `config`, `estado_conversa`.

## 6. Piloto

Número de teste da Meta Cloud API, com os 5 destinatários (equipe listada acima) verificados manualmente — ver D-05 e `GO-LIVE.md`.
