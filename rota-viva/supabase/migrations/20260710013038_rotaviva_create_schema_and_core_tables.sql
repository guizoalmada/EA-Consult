-- Rota Viva: schema dedicado + tabelas core (usuarios, lojas, agenda_visitas, visitas)
create schema if not exists rotaviva;

create table rotaviva.usuarios (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  telefone text unique,
  papel text not null check (papel in ('promotor','consultor','coordenador','gerente')),
  email text,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table rotaviva.lojas (
  id uuid primary key default gen_random_uuid(),
  codcl text not null unique,
  cnpj text,
  nome text not null,
  endereco text,
  bairro text,
  cidade text,
  lat numeric,
  long numeric,
  telefones text[],
  contato text,
  caracteristica text,
  vendedor_dpk text,
  representante text,
  criado_em timestamptz not null default now()
);

create table rotaviva.agenda_visitas (
  id uuid primary key default gen_random_uuid(),
  data date not null,
  usuario_id uuid references rotaviva.usuarios(id),
  loja_id uuid references rotaviva.lojas(id),
  origem text not null check (origem in ('rota','retorno','reagendada')),
  status text not null default 'pendente' check (status in ('pendente','realizada','nao_realizada')),
  criado_em timestamptz not null default now()
);

create table rotaviva.visitas (
  id uuid primary key default gen_random_uuid(),
  agenda_id uuid references rotaviva.agenda_visitas(id),
  usuario_id uuid references rotaviva.usuarios(id),
  loja_id uuid references rotaviva.lojas(id),
  checkin_at timestamptz,
  checkin_lat numeric,
  checkin_long numeric,
  distancia_m numeric,
  foto_url text,
  flag_suspeito boolean not null default false,
  checkout_at timestamptz,
  falou_decisor boolean,
  resultado text check (resultado in ('normal','loja_fechada','contato_ausente')),
  produto_interesse text check (produto_interesse in ('autocred','top_service','ambos','nenhum')),
  status_1 text check (status_1 in ('sem_interesse','analisar','fechou')),
  data_retorno date,
  motivo_nao_fechamento text,
  contraproposta text,
  obs_texto text,
  obs_audio_transcrito text,
  criado_em timestamptz not null default now()
);

create index on rotaviva.agenda_visitas (data, usuario_id);
create index on rotaviva.visitas (loja_id);
create index on rotaviva.visitas (usuario_id);
