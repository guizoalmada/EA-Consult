-- Rota Viva: config (chave/valor) e máquina de estados do W2
create table rotaviva.config (
  chave text primary key,
  valor text
);

create table rotaviva.estado_conversa (
  telefone text primary key,
  estado text not null default 'ocioso',
  contexto jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now()
);
