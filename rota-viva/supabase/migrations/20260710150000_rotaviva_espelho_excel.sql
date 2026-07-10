-- Rota Viva — D-07: o espelho read-only passa de Google Sheets para Excel 365 (OneDrive).
-- A chave de config guarda agora o ID do arquivo .xlsx no OneDrive (driveItem id do Graph),
-- não mais o ID da planilha Google.

update rotaviva.config set chave = 'excel_workbook_id' where chave = 'gsheets_id';

insert into rotaviva.config (chave, valor) values ('excel_workbook_id', '')
on conflict (chave) do nothing;
