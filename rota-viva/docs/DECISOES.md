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
