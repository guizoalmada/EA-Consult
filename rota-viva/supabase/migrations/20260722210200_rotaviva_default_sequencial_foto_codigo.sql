-- PROMPT 1 / Bloco A — foto_codigo gerado no insert como V-0001, V-0002, ... (sequencial, unico).
-- Robusto: o check-in nunca falha por colisao de codigo (o banco gera o valor).
-- Aplicada via apply_migration em 22 Jul 2026 (nome no Supabase: default_sequencial_foto_codigo_visitas).

create sequence if not exists rotaviva.seq_foto_codigo;

alter table rotaviva.visitas
  alter column foto_codigo set default 'V-' || lpad(nextval('rotaviva.seq_foto_codigo')::text, 4, '0');
