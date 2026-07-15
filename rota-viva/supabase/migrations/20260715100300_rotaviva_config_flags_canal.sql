-- Rota Viva v2: flags de canal na config (piloto 100% Telegram; WhatsApp dormente).
insert into rotaviva.config (chave, valor) values
  ('telegram_habilitado', 'true'),
  ('whatsapp_habilitado', 'false')
on conflict (chave) do nothing;
