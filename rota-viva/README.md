# Rota Viva

Sistema de gestão de visitas de campo via WhatsApp para a **DPK** (distribuidora de peças automotivas, MG).

## Visão geral

A equipe de campo — os 5 usuários, incluindo coordenador e gerente — recebe, todo dia, a rota de lojas a visitar diretamente no WhatsApp. O check-in/check-out, a coleta de resultado da visita (interesse em produto, motivo de não-fechamento, observações em áudio) e o acompanhamento da esteira comercial pós-venda (Autocred / Top Service) acontecem por conversa — sem app, sem treinamento.

Um coordenador envia a planilha de rota da véspera pelo WhatsApp; o sistema distribui as visitas do dia a cada responsável, registra tudo em banco e envia relatório gerencial diário por WhatsApp e e-mail.

## Arquitetura

```
Meta WhatsApp Cloud API  ─┬─▶  n8n (orquestração / máquina de estados)  ──▶  Supabase (Postgres, schema rotaviva)
                          │                                                        │
                          └── Webhooks (rota XLSX, conversa de campo)              └─▶ Google Sheets (espelho read-only)
```

- **Canal**: WhatsApp via Meta Cloud API oficial (não Z-API) — ver `docs/DECISOES.md` D-02.
- **Orquestração**: n8n — 6 workflows (`n8n/workflows/`), nomeados `[RotaViva] W{n} - {Nome}`.
- **Dados**: Supabase Postgres, schema dedicado `rotaviva` (fonte de verdade). Todo DDL é migration versionada em `supabase/migrations/`.
- **IA**: usada apenas onde nodes determinísticos não bastam — transcrição de áudio (Whisper) e estruturação de observações em JSON (Claude Haiku 4.5). Ver D-01.
- **Espelho**: Google Sheets, sincronizado 1x/dia, somente leitura para a gerência (Supabase continua sendo a fonte de verdade).

## Stack

| Camada | Tecnologia |
|---|---|
| Mensageria | Meta WhatsApp Cloud API |
| Orquestração | n8n |
| Banco | Supabase (Postgres 17, schema `rotaviva`) |
| Storage | Supabase Storage (bucket `rotaviva-fotos`) |
| IA áudio | OpenAI Whisper |
| IA estruturação | Anthropic Claude Haiku 4.5 |
| Relatórios | E-mail (Gmail) + WhatsApp template + Google Sheets |

## Stack de produtos DPK

- **Autocred** — maquininha de crédito.
- **Top Service** — credenciamento de serviço.

Nenhum fechamento acontece no ato da visita: documentação → cadastro (Fluig) → jurídico → assinatura eletrônica do cliente → assinatura da diretoria → envio/ativação da maquininha. A esteira comercial (`contratos`) acompanha isso por marcos de campo, já que a matriz não reporta mudanças de etapa (ver D-03).

## Estrutura do repositório

```
rota-viva/
├── docs/
│   ├── SPEC.md          — especificação funcional da Fase 1
│   ├── CREDENCIAIS.md   — credenciais a configurar (nunca commitadas)
│   ├── GO-LIVE.md       — runbook de go-live (passos manuais restantes)
│   ├── DECISOES.md      — decisões de arquitetura (ADR curto)
│   └── BLOQUEIOS.md     — registrado apenas se houver impedimento não resolvido
├── supabase/
│   └── migrations/      — DDL versionado do schema `rotaviva`
└── n8n/
    └── workflows/       — export JSON de cada workflow (salvos inativos)
```

## Status

Fase 1 (infraestrutura) concluída pelo executor técnico. Falta apenas o trabalho humano descrito em `docs/GO-LIVE.md`: credenciais, cadastro de telefones/contatos e submissão de templates à Meta.
