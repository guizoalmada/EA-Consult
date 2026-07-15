-- Rota Viva v2: agenda_visitas passa a aceitar origem 'manual' (visitas inseridas via
-- aba "➕ Agenda Manual" da Planilha Mestre, importadas pelo W7).
alter table rotaviva.agenda_visitas
  drop constraint if exists agenda_visitas_origem_check;

alter table rotaviva.agenda_visitas
  add constraint agenda_visitas_origem_check
  check (origem in ('rota','retorno','reagendada','manual'));
