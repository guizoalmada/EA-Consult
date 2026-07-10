-- Rota Viva: esteira comercial (oportunidades, contratos, faturamento_pos)
create table rotaviva.oportunidades (
  id uuid primary key default gen_random_uuid(),
  visita_id uuid references rotaviva.visitas(id),
  loja_id uuid references rotaviva.lojas(id),
  produto text not null,
  status text not null default 'aberta',
  criado_em timestamptz not null default now()
);

create table rotaviva.contratos (
  id uuid primary key default gen_random_uuid(),
  oportunidade_id uuid references rotaviva.oportunidades(id),
  loja_id uuid references rotaviva.lojas(id),
  produto text not null,
  numero_fluig text,
  etapa text not null check (etapa in (
    'docs_enviados','processamento_matriz','assinatura_cliente',
    'assinatura_diretoria','aguardando_ativacao','ativo','cancelado'
  )),
  etapa_desde date not null default current_date,
  data_ativacao date,
  vigencia_inicio date,
  atualizado_por uuid references rotaviva.usuarios(id),
  atualizado_em timestamptz not null default now()
);

comment on column rotaviva.contratos.vigencia_inicio is
  'Regra de negócio: para produto = top_service, vigencia_inicio = primeiro dia do mês seguinte à data de assinatura da diretoria (etapa assinatura_diretoria).';

-- Fase 3 (criada já, sem uso ativo na Fase 1)
create table rotaviva.faturamento_pos (
  id uuid primary key default gen_random_uuid(),
  contrato_id uuid references rotaviva.contratos(id),
  mes_ref date not null,
  valor numeric not null,
  inserido_em timestamptz not null default now()
);

create index on rotaviva.contratos (etapa, etapa_desde);
create index on rotaviva.oportunidades (loja_id);
