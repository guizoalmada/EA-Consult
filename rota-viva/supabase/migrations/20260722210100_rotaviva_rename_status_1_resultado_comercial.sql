-- PROMPT 1 / Bloco C4 — D-25: modelo de dois eixos.
-- resultado = disposicao operacional; resultado_comercial (ex-status_1) = desfecho comercial.
-- Ortogonalidade confirmada na auditoria do Motor de Checkout (W2): colunas/etapas/semanticas distintas.
-- Aplicada via apply_migration em 22 Jul 2026 (nome no Supabase: renomear_status_1_para_resultado_comercial_d25).

alter table rotaviva.visitas rename column status_1 to resultado_comercial;
alter table rotaviva.visitas rename constraint visitas_status_1_check to visitas_resultado_comercial_check;

comment on column rotaviva.visitas.resultado is 'D-25 eixo OPERACIONAL: como a visita transcorreu (normal/loja_fechada/contato_ausente). Setado na etapa decisor do checkout.';
comment on column rotaviva.visitas.resultado_comercial is 'D-25 eixo COMERCIAL (ex-status_1): desfecho de venda (fechou/analisar/sem_interesse). Setado nas etapas fechou_ou_analisar/data_retorno/contraproposta. Ortogonal a resultado.';
