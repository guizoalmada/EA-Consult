-- Rota Viva: GRANTs para o PostgREST acessar o schema rotaviva como service_role.
-- Sem isto, o n8n (via CRED_SUPABASE_ROTAVIVA / service_role) recebe:
--   403 { "code": "42501", "message": "permission denied for schema rotaviva" }
-- O service_role IGNORA RLS, mas ainda precisa de USAGE no schema + privilegios de tabela.
-- Restrito a service_role de proposito: anon/authenticated NAO recebem nada aqui
-- (a superficie publica/anon do PostgREST permanece inalterada; RLS segue valendo).
grant usage on schema rotaviva to service_role;

grant select, insert, update, delete on all tables in schema rotaviva to service_role;
grant usage, select on all sequences in schema rotaviva to service_role;
grant execute on all routines in schema rotaviva to service_role;

alter default privileges in schema rotaviva grant select, insert, update, delete on tables to service_role;
alter default privileges in schema rotaviva grant usage, select on sequences to service_role;
alter default privileges in schema rotaviva grant execute on routines to service_role;
