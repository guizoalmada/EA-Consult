-- Self-check da RPC rotaviva.resolver_usuario_por_nome (usada pelo W1 para casar a coluna PROMO).
-- Rodar no SQL Editor do projeto Morgana Ops. Todas as linhas devem sair com ok = true.
-- Depende dos 5 usuários seed; ajustar os casos se o roster mudar.

with casos(entrada, esperado) as (values
  ('DANTON','Danton'), ('danton','Danton'),
  ('GUILHERME','Guilherme'),
  ('LEONARDO','Leonardo Rosa'), ('Leonardo Rosa','Leonardo Rosa'),
  ('ANDERSON','Anderson Lemos'), ('anderson lemos','Anderson Lemos'),
  ('JANSEN','Jansen Araújo'), ('JANSEN ARAUJO','Jansen Araújo'), ('Jansen Araújo','Jansen Araújo'),
  ('  jansen  araujo ','Jansen Araújo'),
  ('MARCOS', null),   -- nome fora do roster: importa sem responsável
  ('', null),         -- coluna PROMO vazia
  ('X', null),        -- curto demais para casar (< 3 chars)
  (null, null)
)
select c.entrada, c.esperado, u.nome as obtido,
       (coalesce(u.nome,'∅') = coalesce(c.esperado,'∅')) as ok
from casos c
cross join lateral rotaviva.resolver_usuario_por_nome(c.entrada) r
left join rotaviva.usuarios u on u.id = r.usuario_id;
