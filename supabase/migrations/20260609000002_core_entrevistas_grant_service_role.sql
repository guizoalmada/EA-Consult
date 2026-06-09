-- Tabela criada em schema custom (core) nao herda grants das roles da API.
-- service_role (usado SOMENTE pela Edge Function) precisa de acesso explicito.
-- anon/authenticated permanecem SEM grant => zero acesso publico direto.
grant usage on schema core to service_role;
grant select, insert, update on core.entrevistas to service_role;
