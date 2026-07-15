-- Rota Viva v2 (multicanal): re-chavear a máquina de estados por identidade de canal.
-- Formato da identidade: 'tg:<chat_id>' (Telegram) ou 'wa:<telefone>' (WhatsApp dormente).
-- Tabela está vazia no piloto; RENAME preserva PK, RLS e policies de service_role.
alter table rotaviva.estado_conversa rename column telefone to identidade;

comment on column rotaviva.estado_conversa.identidade is
  'Identidade de canal: tg:<chat_id> ou wa:<telefone>. Substitui a antiga PK telefone (D-10).';
