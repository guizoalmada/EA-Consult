-- Bucket privado para fotos de check-in (fachada da loja)
insert into storage.buckets (id, name, public)
values ('rotaviva-fotos', 'rotaviva-fotos', false)
on conflict (id) do nothing;

create policy "rotaviva_fotos_service_role_all"
on storage.objects for all
to service_role
using (bucket_id = 'rotaviva-fotos')
with check (bucket_id = 'rotaviva-fotos');
