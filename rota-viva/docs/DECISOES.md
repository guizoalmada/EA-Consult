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

## D-04 — Supabase é fonte de verdade; Sheets é espelho read-only

**Contexto:** a gerência quer visualizar dados em planilha, mas não deve haver duas fontes de verdade.
**Decisão:** todo escrita acontece em Supabase; o Google Sheets (W5) é um espelho incremental, gerado 1x/dia, sem edição prevista de volta ao banco.
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
- O W3 envia rota para qualquer pessoa com `faz_visitas=true` e visitas pendentes. Como o alerta de
  rota vazia é por usuário, Anderson e Jansen passarão a gerar alerta nos dias em que a planilha do
  coordenador não incluir rota para eles — ver pergunta aberta em `BLOQUEIOS.md` B-02.
- A superfície de edição da meta individual ficou pendente (B-02): hoje se define por SQL.
- Nenhum texto de mensagem ao usuário fala mais em "promotor"; usa-se o nome da pessoa ou termo
  neutro ("sua rota", "suas visitas").
