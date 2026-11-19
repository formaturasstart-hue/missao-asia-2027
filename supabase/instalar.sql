-- ============================================================
-- Missão Ásia & Emirados 2027 · INSTALAR (ou mudar de projeto)
-- Rode inteiro no SQL Editor de um projeto Supabase.
-- Cria só a área "viagem", as funções viagem_* e o bucket viagem-midias.
-- Não mexe em nenhuma outra tabela do projeto.
-- Requer a extensão pgcrypto (já vem ativa no Supabase, no schema "extensions").
-- ============================================================

create schema if not exists viagem;
revoke all on schema viagem from public, anon, authenticated;

create table if not exists viagem.usuarios (
  id uuid primary key default gen_random_uuid(),
  usuario text not null unique check (usuario ~ '^[a-z0-9._-]{3,30}$'),
  nome text not null,
  senha_hash text not null,
  admin boolean not null default false,
  ativo boolean not null default true,
  trocar_senha boolean not null default true,
  criado_em timestamptz not null default now()
);
create table if not exists viagem.sessoes (
  token_hash text primary key,
  usuario_id uuid not null references viagem.usuarios(id) on delete cascade,
  expira timestamptz not null,
  criado_em timestamptz not null default now()
);
create table if not exists viagem.tentativas (usuario text not null, em timestamptz not null default now());
create index if not exists tentativas_usuario_em on viagem.tentativas (usuario, em);
create table if not exists viagem.itens (
  kind text not null check (kind in ('idea','sup','exp','media','note','ck','cust','must','hotel','nota','stamp','plan')),
  key text not null check (length(key) <= 200),
  data jsonb,
  deleted boolean not null default false,
  autor uuid references viagem.usuarios(id) on delete set null,
  atualizado_em timestamptz not null default clock_timestamp(),
  primary key (kind, key)
);
create index if not exists itens_atualizado_em on viagem.itens (atualizado_em);
create table if not exists viagem.live (id int primary key default 1 check (id = 1), data jsonb not null, atualizado_em timestamptz not null default now());

alter table viagem.usuarios enable row level security;
alter table viagem.sessoes enable row level security;
alter table viagem.tentativas enable row level security;
alter table viagem.itens enable row level security;
alter table viagem.live enable row level security;

CREATE OR REPLACE FUNCTION viagem._uid(p_token text)
 RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  select s.usuario_id from viagem.sessoes s join viagem.usuarios u on u.id = s.usuario_id
  where s.token_hash = encode(extensions.digest(coalesce(p_token,''), 'sha256'), 'hex') and s.expira > now() and u.ativo;
$function$;

CREATE OR REPLACE FUNCTION viagem._exige(p_token text)
 RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
declare v uuid; begin v := viagem._uid(p_token); if v is null then raise exception 'sessao_invalida'; end if; return v; end $function$;

CREATE OR REPLACE FUNCTION viagem._admin(p_token text)
 RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
declare v uuid; begin v := viagem._exige(p_token);
  if not exists (select 1 from viagem.usuarios where id = v and admin) then raise exception 'so_admin'; end if; return v; end $function$;

CREATE OR REPLACE FUNCTION public.viagem_login(p_usuario text, p_senha text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare u viagem.usuarios; t text; n int;
begin
  p_usuario := lower(trim(coalesce(p_usuario,'')));
  select count(*) into n from viagem.tentativas where usuario = p_usuario and em > now() - interval '15 minutes';
  if n >= 8 then return jsonb_build_object('erro','muitas_tentativas'); end if;
  select * into u from viagem.usuarios where usuario = p_usuario and ativo;
  if u.id is null or u.senha_hash <> extensions.crypt(coalesce(p_senha,''), u.senha_hash) then
    insert into viagem.tentativas(usuario) values (p_usuario);
    return jsonb_build_object('erro','login_invalido');
  end if;
  delete from viagem.tentativas where usuario = p_usuario or em < now() - interval '1 day';
  t := encode(extensions.gen_random_bytes(32), 'hex');
  insert into viagem.sessoes(token_hash, usuario_id, expira) values (encode(extensions.digest(t,'sha256'),'hex'), u.id, now() + interval '120 days');
  return jsonb_build_object('token', t, 'usuario', u.usuario, 'nome', u.nome, 'admin', u.admin, 'trocar', u.trocar_senha);
end $function$;

CREATE OR REPLACE FUNCTION public.viagem_eu(p_token text)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  select jsonb_build_object('usuario', u.usuario, 'nome', u.nome, 'admin', u.admin, 'trocar', u.trocar_senha)
  from viagem.usuarios u where u.id = viagem._exige(p_token);
$function$;

CREATE OR REPLACE FUNCTION public.viagem_sair(p_token text)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$
  delete from viagem.sessoes where token_hash = encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex');
$function$;

CREATE OR REPLACE FUNCTION public.viagem_trocar_senha(p_token text, p_atual text, p_nova text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare v uuid := viagem._exige(p_token); h text;
begin
  if length(coalesce(p_nova,'')) < 6 then raise exception 'senha_curta'; end if;
  select senha_hash into h from viagem.usuarios where id = v;
  if h <> extensions.crypt(p_atual, h) then raise exception 'senha_atual_errada'; end if;
  update viagem.usuarios set senha_hash = extensions.crypt(p_nova, extensions.gen_salt('bf', 10)), trocar_senha = false where id = v;
end $function$;

CREATE OR REPLACE FUNCTION public.viagem_push(p_token text, p_rows jsonb)
 RETURNS timestamp with time zone LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare v uuid := viagem._exige(p_token); r jsonb;
begin
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 500 then raise exception 'lote_invalido'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    if pg_column_size(r->'data') > 200000 then raise exception 'item_grande_demais'; end if;
    insert into viagem.itens(kind, key, data, deleted, autor, atualizado_em)
    values (r->>'kind', r->>'key', r->'data', coalesce((r->>'deleted')::boolean, false), v, clock_timestamp())
    on conflict (kind, key) do update set data = excluded.data, deleted = excluded.deleted, autor = excluded.autor, atualizado_em = clock_timestamp();
  end loop;
  return clock_timestamp();
end $function$;

CREATE OR REPLACE FUNCTION public.viagem_pull(p_token text, p_since timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
declare v uuid := viagem._exige(p_token);
begin
  return jsonb_build_object('now', clock_timestamp(), 'rows', coalesce((
    select jsonb_agg(jsonb_build_object('kind', i.kind, 'key', i.key, 'data', i.data, 'deleted', i.deleted, 'autor', u.nome, 'at', i.atualizado_em) order by i.atualizado_em)
    from viagem.itens i left join viagem.usuarios u on u.id = i.autor
    where p_since is null or i.atualizado_em > p_since - interval '10 seconds'), '[]'::jsonb));
end $function$;

CREATE OR REPLACE FUNCTION public.viagem_usuarios(p_token text)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object('usuario', usuario, 'nome', nome, 'admin', admin, 'ativo', ativo, 'trocar', trocar_senha) order by criado_em), '[]'::jsonb)
  from viagem.usuarios where viagem._admin(p_token) is not null;
$function$;

CREATE OR REPLACE FUNCTION public.viagem_salvar_usuario(p_token text, p_usuario text, p_nome text, p_senha text, p_admin boolean DEFAULT false, p_ativo boolean DEFAULT true)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare v uuid := viagem._admin(p_token);
begin
  p_usuario := lower(trim(p_usuario));
  if p_senha is not null and length(p_senha) < 6 then raise exception 'senha_curta'; end if;
  if exists (select 1 from viagem.usuarios where usuario = p_usuario) then
    update viagem.usuarios set nome = coalesce(nullif(trim(p_nome),''), nome), admin = coalesce(p_admin, admin), ativo = coalesce(p_ativo, ativo),
      senha_hash = case when p_senha is null then senha_hash else extensions.crypt(p_senha, extensions.gen_salt('bf', 10)) end,
      trocar_senha = case when p_senha is null then trocar_senha else true end
    where usuario = p_usuario;
    if p_ativo = false or p_senha is not null then delete from viagem.sessoes s using viagem.usuarios u where s.usuario_id = u.id and u.usuario = p_usuario and u.id <> v; end if;
  else
    if p_senha is null then raise exception 'senha_obrigatoria'; end if;
    insert into viagem.usuarios(usuario, nome, senha_hash, admin) values (p_usuario, trim(p_nome), extensions.crypt(p_senha, extensions.gen_salt('bf', 10)), coalesce(p_admin,false));
  end if;
end $function$;

CREATE OR REPLACE FUNCTION public.viagem_live()
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$ select data from viagem.live where id = 1 $function$;

CREATE OR REPLACE FUNCTION public.viagem_token_usuario(p_token text)
 RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$ select viagem._uid(p_token) $function$;

revoke all on all functions in schema viagem from public, anon, authenticated;
revoke all on function public.viagem_login, public.viagem_eu, public.viagem_sair, public.viagem_trocar_senha, public.viagem_push, public.viagem_pull, public.viagem_usuarios, public.viagem_salvar_usuario, public.viagem_live, public.viagem_token_usuario from public;
grant execute on function public.viagem_login, public.viagem_eu, public.viagem_sair, public.viagem_trocar_senha, public.viagem_push, public.viagem_pull, public.viagem_usuarios, public.viagem_salvar_usuario, public.viagem_live to anon, authenticated;
revoke execute on function public.viagem_token_usuario from anon, authenticated;
grant execute on function public.viagem_token_usuario to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('viagem-midias', 'viagem-midias', false, 15728640, array['image/*','audio/*','video/mp4'])
on conflict (id) do nothing;

-- Primeiro administrador (troque a senha aqui antes de rodar; no primeiro acesso o roteiro pede outra):
-- insert into viagem.usuarios (usuario, nome, senha_hash, admin, trocar_senha)
-- values ('mateus', 'Mateus Vieira', extensions.crypt('TROQUE-ESTA-SENHA', extensions.gen_salt('bf', 10)), true, true);
