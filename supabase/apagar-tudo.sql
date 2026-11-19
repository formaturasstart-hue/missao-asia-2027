-- ============================================================
-- Missão Ásia & Emirados 2027 · APAGAR TUDO DA VIAGEM
-- Rode no SQL Editor do projeto Supabase onde a viagem está.
-- Apaga só o que é da viagem: a área "viagem" e as funções viagem_*.
-- Nada das outras tabelas do projeto é tocado.
--
-- ANTES DE RODAR: baixe a cópia de segurança no roteiro
-- (aba Equipe → "Baixar cópia de tudo (JSON)") se quiser guardar os dados.
-- ============================================================

drop function if exists public.viagem_login(text, text);
drop function if exists public.viagem_eu(text);
drop function if exists public.viagem_sair(text);
drop function if exists public.viagem_trocar_senha(text, text, text);
drop function if exists public.viagem_push(text, jsonb);
drop function if exists public.viagem_pull(text, timestamptz);
drop function if exists public.viagem_usuarios(text);
drop function if exists public.viagem_salvar_usuario(text, text, text, text, boolean, boolean);
drop function if exists public.viagem_live();
drop function if exists public.viagem_token_usuario(text);

drop schema if exists viagem cascade;

-- ============================================================
-- Depois, no painel do Supabase (não dá por SQL):
-- 1. Storage → bucket "viagem-midias" → selecione todos os arquivos → Delete.
--    Com o bucket vazio: menu do bucket → Delete bucket.
-- 2. Edge Functions → "viagem-arquivos" → Delete function.
-- ============================================================
