create table if not exists core.entrevistas (
  id              uuid primary key default gen_random_uuid(),
  formulario_slug text        not null,
  codigo_acesso   text        not null,
  cliente_nome    text,
  respostas       jsonb       not null default '{}'::jsonb,
  fase_atual      integer     not null default 0,
  concluido       boolean     not null default false,
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),
  unique (formulario_slug, codigo_acesso)
);

alter table core.entrevistas enable row level security;
-- Sem policies de propósito: PostgREST bloqueia anon/authenticated.
-- Acesso somente via service_role (Edge Function).

comment on table core.entrevistas is
  'Capturas de formularios web publicos (entrevistas de diagnostico de clientes). Leitura/escrita apenas via Edge Function com service_role.';
