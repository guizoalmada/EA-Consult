-- PROMPT 1 / Bloco A6 — flag de controle do push imediato do W2 para o W5 (D-21).
-- Na homologacao o node "Chamar W5 (push sync)" do W2 fica desabilitado; o sync roda pelo cron de
-- resgate do W5 (outbox sincronizado=false). Esta flag registra a intencao de reativar no go-live.
-- Aplicada via execute_sql em 22 Jul 2026.

insert into rotaviva.config (chave, valor) values ('sync_push_habilitado', 'true')
on conflict (chave) do update set valor = excluded.valor;
