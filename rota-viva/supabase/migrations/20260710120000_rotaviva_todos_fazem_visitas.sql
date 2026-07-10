-- Rota Viva — D-06: todos os usuários fazem visitas.
-- Visitas deixam de ser exclusividade de promotor/consultor. O papel continua existindo
-- (define quem recebe alertas), mas o fluxo de visitas passa a depender de `faz_visitas`.

alter table rotaviva.usuarios add column if not exists meta_visitas_dia integer;
alter table rotaviva.usuarios add column if not exists faz_visitas boolean not null default true;

comment on column rotaviva.usuarios.meta_visitas_dia is
  'Meta diária individual de visitas. NULL = herda config.meta_visitas_dia.';
comment on column rotaviva.usuarios.faz_visitas is
  'Se true, o usuário entra na rota diária, no ranking e nas contagens de meta.';

-- Seeds: os 5 usuários fazem visitas; nenhum tem meta individual ainda
-- (o gestor define depois; até lá todos herdam config.meta_visitas_dia = 12).
update rotaviva.usuarios set faz_visitas = true, meta_visitas_dia = null;

-- Normalização de nomes: minúsculas, sem acentos, espaços colapsados.
-- Usada para casar a coluna PROMO da planilha de rota com rotaviva.usuarios.nome (W1).
create or replace function rotaviva.normalizar_nome(p text)
returns text
language sql
immutable
parallel safe
as $$
  select btrim(regexp_replace(
    lower(translate(
      coalesce(p, ''),
      'ÁÀÂÃÄáàâãäÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÕÖóòôõöÚÙÛÜúùûüÇç',
      'aaaaaaaaaaeeeeeeeeiiiiiiiioooooooooouuuuuuuucc'
    )),
    '\s+', ' ', 'g'
  ));
$$;

-- Resolve o responsável de uma linha da rota a partir do texto da coluna PROMO.
-- Sempre retorna exatamente 1 linha: o uuid do usuário, ou NULL se não reconhecido
-- (o W1 importa a visita como pendente sem responsável e reporta ao coordenador).
create or replace function rotaviva.resolver_usuario_por_nome(p_nome text)
returns table (usuario_id uuid)
language sql
stable
security definer
set search_path = rotaviva, pg_temp
as $$
  select (
    select u.id
    from rotaviva.usuarios u
    where u.ativo
      and u.faz_visitas
      and length(rotaviva.normalizar_nome(p_nome)) >= 3
      and (
        rotaviva.normalizar_nome(u.nome) like '%' || rotaviva.normalizar_nome(p_nome) || '%'
        or rotaviva.normalizar_nome(p_nome) like '%' || split_part(rotaviva.normalizar_nome(u.nome), ' ', 1) || '%'
      )
    order by
      (rotaviva.normalizar_nome(u.nome) = rotaviva.normalizar_nome(p_nome)) desc,
      length(u.nome) asc
    limit 1
  );
$$;

revoke all on function rotaviva.resolver_usuario_por_nome(text) from public;
grant execute on function rotaviva.resolver_usuario_por_nome(text) to service_role;
