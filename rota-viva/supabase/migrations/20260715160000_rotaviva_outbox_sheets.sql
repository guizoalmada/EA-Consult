-- Rota Viva (D-13): Google Sheets vira a fonte de verdade dos dados de negócio;
-- o Supabase (schema rotaviva) passa a atuar como OUTBOX / auditoria durável.
-- Cada evento é gravado aqui primeiro (sincronizado=false) e replicado ao Google Sheets
-- pelo W5 "Sync to Sheets" (push imediato do W2 + cron de resgate a cada 5 min).
--
-- ATENCAO: este arquivo ainda NAO foi aplicado no banco — o MCP do Supabase estava offline
-- na sessao em que foi escrito. Aplicar via apply_migration quando o acesso voltar e verificar
-- no schema vivo (ver docs/BLOQUEIOS.md B-05).

-- Colunas de outbox nas tabelas de dados de negócio
alter table rotaviva.visitas        add column if not exists sincronizado boolean not null default false;
alter table rotaviva.visitas        add column if not exists sheets_synced_at timestamptz;
alter table rotaviva.oportunidades  add column if not exists sincronizado boolean not null default false;
alter table rotaviva.oportunidades  add column if not exists sheets_synced_at timestamptz;
alter table rotaviva.contratos      add column if not exists sincronizado boolean not null default false;
alter table rotaviva.contratos      add column if not exists sheets_synced_at timestamptz;
alter table rotaviva.agenda_visitas add column if not exists sincronizado boolean not null default false;
alter table rotaviva.agenda_visitas add column if not exists sheets_synced_at timestamptz;

comment on column rotaviva.visitas.sincronizado is
  'Outbox (D-13): false = evento ainda nao replicado ao Google Sheets. Cron de resgate do W5 reprocessa.';
comment on column rotaviva.oportunidades.sincronizado is
  'Outbox (D-13): false = evento ainda nao replicado ao Google Sheets.';
comment on column rotaviva.contratos.sincronizado is
  'Outbox (D-13): false = evento ainda nao replicado ao Google Sheets.';
comment on column rotaviva.agenda_visitas.sincronizado is
  'Outbox (D-13): false = evento ainda nao replicado ao Google Sheets.';

-- Indices parciais para o cron de resgate (busca so o backlog nao sincronizado)
create index if not exists idx_visitas_nao_sincronizadas        on rotaviva.visitas (criado_em)        where sincronizado = false;
create index if not exists idx_oportunidades_nao_sincronizadas  on rotaviva.oportunidades (criado_em)  where sincronizado = false;
create index if not exists idx_contratos_nao_sincronizados      on rotaviva.contratos (atualizado_em)  where sincronizado = false;
create index if not exists idx_agenda_nao_sincronizadas         on rotaviva.agenda_visitas (criado_em) where sincronizado = false;

-- Referencia da planilha mestre (substitui o antigo excel_workbook_id, mantido como legado vazio)
insert into rotaviva.config (chave, valor) values ('google_sheets_id', '')
on conflict (chave) do nothing;
