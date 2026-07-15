-- Rota Viva v2 (multicanal): canal de comunicação e vínculo Telegram por usuário
alter table rotaviva.usuarios
  add column if not exists canal text not null default 'telegram'
    check (canal in ('telegram','whatsapp'));

alter table rotaviva.usuarios
  add column if not exists telegram_chat_id text unique;

comment on column rotaviva.usuarios.canal is
  'Canal padrão de envio ao usuário (D-10). Piloto: telegram. whatsapp fica dormente.';
comment on column rotaviva.usuarios.telegram_chat_id is
  'chat_id do Telegram, gravado no /start após vinculação por contato (W2).';
