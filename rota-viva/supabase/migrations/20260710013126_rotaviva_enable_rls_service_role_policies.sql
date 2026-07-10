-- RLS: habilitar em todas as tabelas do schema rotaviva.
-- Sem policies de usuário final na Fase 1 (não há frontend) — apenas service_role
-- (usado pelo n8n) tem acesso explícito; demais roles (anon/authenticated) ficam
-- sem nenhuma policy, ou seja, sem acesso via PostgREST.
alter table rotaviva.usuarios enable row level security;
alter table rotaviva.lojas enable row level security;
alter table rotaviva.agenda_visitas enable row level security;
alter table rotaviva.visitas enable row level security;
alter table rotaviva.oportunidades enable row level security;
alter table rotaviva.contratos enable row level security;
alter table rotaviva.faturamento_pos enable row level security;
alter table rotaviva.config enable row level security;
alter table rotaviva.estado_conversa enable row level security;

create policy service_role_all on rotaviva.usuarios for all to service_role using (true) with check (true);
create policy service_role_all on rotaviva.lojas for all to service_role using (true) with check (true);
create policy service_role_all on rotaviva.agenda_visitas for all to service_role using (true) with check (true);
create policy service_role_all on rotaviva.visitas for all to service_role using (true) with check (true);
create policy service_role_all on rotaviva.oportunidades for all to service_role using (true) with check (true);
create policy service_role_all on rotaviva.contratos for all to service_role using (true) with check (true);
create policy service_role_all on rotaviva.faturamento_pos for all to service_role using (true) with check (true);
create policy service_role_all on rotaviva.config for all to service_role using (true) with check (true);
create policy service_role_all on rotaviva.estado_conversa for all to service_role using (true) with check (true);
