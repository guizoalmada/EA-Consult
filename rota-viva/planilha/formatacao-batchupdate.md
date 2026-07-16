# Formatação da planilha "RotaViva Master" (identidade visual)

Aplicada em 16 Jul 2026 via Google Sheets API `batchUpdate` (workflow descartável
`TMP — Formatar Planilha`, arquivado no n8n — restaurável para reaplicar).
Planilha: `1yv3EYq4lxg-CPsulD80HlLAy5Mh_kIOcyAdUoqXBooc`.

## Paleta (tema claro, marca "Rota Viva")

| Papel | Hex |
|---|---|
| Petróleo (título/tinta forte) | `#0E3A34` |
| Papel (texto sobre petróleo) | `#F2F8F6` |
| Névoa (fundo de seção) | `#E2EFEA` |
| Teal vivo (dados/barras/acento) | `#0C7C66` |
| Texto secundário | `#5C6F6B` |
| Banding | `#FAFDFC` / `#F1F7F5` |
| Status OK | `#1E8E3E` (texto) |
| Status atenção | `#B26A00` sobre `#FEF3E0` |
| Status crítico | `#C5221F` sobre `#FCE8E6` |
| Entrada editável (âmbar) | header `#FBF0DA`, tinta `#7A5200`, aba `#E8A93D` |
| Espelho (aba) | `#6B8783`, header `#3D5A55` |

**Semântica das abas:** petróleo = painel · teal = ranking · cinza-azulado = gerado
automaticamente · âmbar = o gestor pode editar.

## O que foi aplicado

- **📊 Dashboard** (sheetId `698832368`): grade oculta; linha 1 congelada e mesclada A1:F1
  (banda petróleo, 15pt, altura 46px); seções (linhas 4, 9, 17, 23, 34) mescladas A:F com fundo
  névoa; hero number B5 16pt; barra de progresso B6:F6 mesclada em Roboto Mono teal; tabela da
  equipe com banding e coluna Ritmo em mono teal; funil com valores em negrito; esteira de
  contratos com banding; **formatação condicional** nas células de situação (F7, D32, F35):
  `✖`→vermelho c/ fundo, `⚠`→âmbar c/ fundo, `✔`→verde; Qtd>0 em negrito (B25:B31) e SLA>0 em
  vermelho (B32); larguras A–F: 215/140/195/125/105/140; proteção warning-only.
- **Visitas / Oportunidades / Contratos**: header escuro `#3D5A55` em negrito, linha 1 congelada,
  coluna id 90px, aba cinza-azulada, proteção warning-only ("edições serão sobrescritas").
- **Ranking**: header névoa, congelado, aba teal, proteção warning-only.
- **⚙ Config / ➕ Agenda Manual**: header âmbar em negrito, linha 1 congelada, abas âmbar,
  larguras calibradas (sem proteção — são as abas de entrada).

## Como reaplicar

Restaurar o workflow arquivado `TMP — Formatar Planilha (descartável)` no n8n (o Code node
"Montar Requests" contém o gerador completo das ~55 requests), vincular a credencial
`ROTA-VIVA - Google Sheets` no nó HTTP e executar 1x. Idempotente, exceto: merges e bandings já
existentes fazem a request falhar — se reaplicar sobre planilha já formatada, remover antes os
bandings/merges ou recriar a planilha do zero (setup + seeds + rebuild + formatação).

Nota (aprendizado): caracteres fora do BMP (emojis 4-byte) corrompem na cadeia de escrita de
células; usar símbolos BMP (⚑ ● ★ ▼ ■ ⏰ ✔ ✖ ⚠) — nas requests da API, escapar como `\uXXXX`.
