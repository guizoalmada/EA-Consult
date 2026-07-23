-- PROMPT 1 / Bloco A1 — D-22 (foto por file_id, sem storage) e D-23/suspeita.
-- Aplicada via apply_migration em 22 Jul 2026 (nome no Supabase: adicionar_colunas_foto_e_motivo_visitas).

alter table rotaviva.visitas
  add column if not exists foto_file_id text,
  add column if not exists foto_codigo text,
  add column if not exists motivo_suspeita text;

comment on column rotaviva.visitas.foto_file_id is 'file_id do Telegram da foto de check-in (melhor resolucao). D-22: foto nao vai para storage, so encaminhada ao coordenador.';
comment on column rotaviva.visitas.foto_codigo is 'Codigo curto legivel da foto (formato V-XXXX). Permite localizar a foto no chat do coordenador em auditoria futura.';
comment on column rotaviva.visitas.motivo_suspeita is 'Motivo da suspeita quando flag_suspeito=true: fora_do_raio (D-06) ou foto_encaminhada (D-23). NULL quando flag_suspeito=false.';

-- foto_codigo unico quando preenchido (indice parcial, permite multiplos NULL)
create unique index if not exists visitas_foto_codigo_uidx on rotaviva.visitas (foto_codigo) where foto_codigo is not null;
