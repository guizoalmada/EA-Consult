insert into rotaviva.config (chave, valor) values
  ('raio_checkin_m', '200'),
  ('sla_dias_padrao', '3'),
  ('meta_visitas_dia', '12'),
  ('meta_visitas_mes', '280'),
  ('hora_envio_rota', '07:30'),
  ('hora_relatorio', '18:00'),
  ('emails_relatorio', 'jansen.araujo@dpk.com.br,Anderson.lemos@dpk.com.br,leonardo.rosa@dpk.com.br'),
  ('gsheets_id', '')
on conflict (chave) do nothing;
