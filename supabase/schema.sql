-- =====================================================================
--  VICXMOURA PISCINAS – Banco de dados do sistema de gestão  (versão 3.1)
--  Rode este arquivo inteiro no Supabase: SQL Editor → New query → Run
--  Pode rodar de novo sem perder dados. Também atualiza um banco criado
--  com a versão anterior (remove o caixa físico e adiciona as novidades).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. FUNÇÕES DE APOIO (texto, documentos)
-- ---------------------------------------------------------------------
create or replace function public.so_digitos(t text) returns text
language sql immutable as $$ select regexp_replace(coalesce(t,''), '\D', '', 'g') $$;

create or replace function public.sem_acento(t text) returns text
language sql immutable as $$
  select translate(lower(trim(coalesce(t,''))), 'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn')
$$;

-- CPF (11 dígitos) ou CNPJ (14 dígitos) com conferência dos dígitos verificadores
create or replace function public.valida_doc(t text) returns boolean
language plpgsql immutable as $$
declare d text := public.so_digitos(t); s int; r int; i int; pesos int[];
begin
  if length(d) = 11 then
    if d ~ '^(\d)\1{10}$' then return false; end if;
    s := 0; for i in 1..9 loop s := s + substr(d,i,1)::int * (11-i); end loop;
    r := (s*10) % 11; if r = 10 then r := 0; end if;
    if r <> substr(d,10,1)::int then return false; end if;
    s := 0; for i in 1..10 loop s := s + substr(d,i,1)::int * (12-i); end loop;
    r := (s*10) % 11; if r = 10 then r := 0; end if;
    return r = substr(d,11,1)::int;
  elsif length(d) = 14 then
    if d ~ '^(\d)\1{13}$' then return false; end if;
    pesos := array[5,4,3,2,9,8,7,6,5,4,3,2];
    s := 0; for i in 1..12 loop s := s + substr(d,i,1)::int * pesos[i]; end loop;
    r := s % 11; r := case when r < 2 then 0 else 11 - r end;
    if r <> substr(d,13,1)::int then return false; end if;
    pesos := array[6,5,4,3,2,9,8,7,6,5,4,3,2];
    s := 0; for i in 1..13 loop s := s + substr(d,i,1)::int * pesos[i]; end loop;
    r := s % 11; r := case when r < 2 then 0 else 11 - r end;
    return r = substr(d,14,1)::int;
  end if;
  return false;
end $$;

-- ---------------------------------------------------------------------
-- 1. EQUIPE (perfis de quem acessa o painel)
-- ---------------------------------------------------------------------
create table if not exists public.perfis (
    id uuid primary key references auth.users (id) on delete cascade,
    nome text not null default '',
    email text,
    papel text not null default 'funcionario' check (
        papel in ('admin', 'funcionario')
    ),
    ativo boolean not null default false,
    criado_em timestamptz not null default now()
);

create or replace function public.eh_equipe() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.perfis where id = auth.uid() and ativo);
$$;

create or replace function public.eh_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.perfis where id = auth.uid() and ativo and papel = 'admin');
$$;

-- Todo usuário novo ganha um perfil INATIVO. O primeiro usuário vira administrador.
create or replace function public.novo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare primeiro boolean;
begin
  select not exists(select 1 from public.perfis) into primeiro;
  insert into public.perfis(id, nome, email, papel, ativo)
  values (new.id, coalesce(new.raw_user_meta_data->>'nome', split_part(new.email,'@',1)), new.email,
          case when primeiro then 'admin' else 'funcionario' end, primeiro)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists ao_criar_usuario on auth.users;

create trigger ao_criar_usuario after insert on auth.users for each row execute function public.novo_usuario();

-- ---------------------------------------------------------------------
-- 2. CONFIGURAÇÕES DO SITE (editadas no painel, lidas pelo site)
-- ---------------------------------------------------------------------
create table if not exists public.config_site (
  id                  int primary key default 1 check (id = 1),
  whatsapp            text not null default '',
  pix_chave           text not null default '',
  pix_nome            text not null default 'VicxMoura Piscinas',
  frete_valor         numeric(12,2) not null default 20 check (frete_valor >= 0),
  frete_gratis_acima  numeric(12,2) not null default 300 check (frete_gratis_acima >= 0),
  cidades             text[] not null default array['São Paulo','Valinhos','Vinhedo','Paulínia','Hortolândia','Sumaré','Jaguariúna','Indaiatuba'],
  aceita_pedidos      boolean not null default true,
  aviso               text not null default '',
  atualizado_em       timestamptz not null default now()
);

insert into
    public.config_site (id)
values (1) on conflict (id) do nothing;
-- Troca de marca (Meliah → VicxMoura): ajusta o nome do Pix e remove dados reais antigos
alter table public.config_site
alter column pix_nome
set default 'VicxMoura Piscinas';

update public.config_site
set
    pix_nome = 'VicxMoura Piscinas'
where
    pix_nome ilike '%meliah%';

update public.config_site
set
    pix_chave = ''
where
    regexp_replace(pix_chave, '\D', '', 'g') = '06120369000114';

-- ---------------------------------------------------------------------
-- 3. PRODUTOS E ESTOQUE
-- ---------------------------------------------------------------------
create table if not exists public.produtos (
    id text primary key check (id ~ '^[a-z0-9_-]{2,40}$'),
    nome text not null,
    categoria text not null default 'Outros',
    descricao text not null default '',
    unidade text not null default 'un',
    preco_venda numeric(12, 2) not null default 0 check (preco_venda >= 0),
    custo numeric(12, 2) not null default 0 check (custo >= 0),
    estoque numeric(12, 3) not null default 0,
    estoque_minimo numeric(12, 3) not null default 0,
    icone text not null default 'balde',
    ativo boolean not null default true,
    no_site boolean not null default true,
    atualizado_em timestamptz not null default now()
);

create table if not exists public.movimentos_estoque (
    id bigint generated always as identity primary key,
    produto_id text not null references public.produtos (id) on update cascade,
    tipo text not null check (
        tipo in (
            'entrada',
            'saida',
            'ajuste',
            'venda',
            'cancelamento'
        )
    ),
    quantidade numeric(12, 3) not null check (quantidade <> 0),
    custo_unit numeric(12, 2),
    observacao text not null default '',
    venda_id bigint,
    usuario_id uuid default auth.uid (),
    criado_em timestamptz not null default now()
);

create index if not exists mov_produto_idx on public.movimentos_estoque (produto_id, criado_em desc);

create or replace function public.aplicar_movimento() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.produtos
     set estoque = estoque + new.quantidade,
         custo = case when new.tipo = 'entrada' and new.custo_unit is not null then new.custo_unit else custo end,
         atualizado_em = now()
   where id = new.produto_id;
  return new;
end $$;

drop trigger if exists ao_movimentar on public.movimentos_estoque;

create trigger ao_movimentar after insert on public.movimentos_estoque for each row execute function public.aplicar_movimento();

-- ---------------------------------------------------------------------
-- 4. CLIENTES E MENSALIDADES
-- ---------------------------------------------------------------------
create table if not exists public.clientes (
    id bigint generated always as identity primary key,
    nome text not null,
    telefone text not null default '',
    email text not null default '',
    cpf_cnpj text not null default '',
    endereco text not null default '',
    bairro text not null default '',
    cidade text not null default 'São Paulo',
    cep text not null default '',
    volume_litros integer,
    observacoes text not null default '',
    criado_em timestamptz not null default now()
);

alter table public.clientes
add column if not exists numero text not null default '';

alter table public.clientes
add column if not exists complemento text not null default '';

alter table public.clientes
add column if not exists uf text not null default 'SP';

-- Telefone, CEP e CPF/CNPJ ficam guardados só com números
create or replace function public.normalizar_cliente() returns trigger
language plpgsql as $$
begin
  new.telefone := public.so_digitos(new.telefone);
  new.cep := public.so_digitos(new.cep);
  new.cpf_cnpj := public.so_digitos(new.cpf_cnpj);
  new.nome := trim(new.nome);
  new.email := lower(trim(new.email));
  new.uf := upper(trim(new.uf));
  return new;
end $$;

drop trigger if exists ao_salvar_cliente on public.clientes;

create trigger ao_salvar_cliente before insert or update on public.clientes for each row execute function public.normalizar_cliente();

do $$ begin
  alter table public.clientes add constraint clientes_doc_valido check (cpf_cnpj = '' or public.valida_doc(cpf_cnpj)) not valid;
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.clientes add constraint clientes_tel_valido check (telefone = '' or length(telefone) between 10 and 11) not valid;
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.clientes add constraint clientes_cep_valido check (cep = '' or length(cep) = 8) not valid;
exception when duplicate_object then null; end $$;

create index if not exists clientes_tel_idx on public.clientes (telefone);
-- Ajusta clientes antigos para o formato só com números (o que não for válido vai para as observações)
update public.clientes
set
    observacoes = trim(
        observacoes || case
            when (
                length(so_digitos (telefone)) not between 10 and 11
                and so_digitos (telefone) <> ''
            )
            or (
                so_digitos (cpf_cnpj) <> ''
                and not valida_doc (cpf_cnpj)
            )
            or (
                length(so_digitos (cep)) not in(0, 8)
            ) then ' [dados antigos: tel ' || telefone || ' doc ' || cpf_cnpj || ' cep ' || cep || ']'
            else ''
        end
    ),
    telefone = case
        when length(so_digitos (telefone)) between 10 and 11  then so_digitos (telefone)
        else ''
    end,
    cpf_cnpj = case
        when valida_doc (cpf_cnpj) then so_digitos (cpf_cnpj)
        else ''
    end,
    cep = case
        when length(so_digitos (cep)) = 8 then so_digitos (cep)
        else ''
    end
where
    telefone ~ '\D'
    or cpf_cnpj ~ '\D'
    or cep ~ '\D'
    or (
        telefone <> ''
        and length(telefone) not between 10 and 11
    )
    or (
        cpf_cnpj <> ''
        and not valida_doc (cpf_cnpj)
    )
    or (
        cep <> ''
        and length(cep) <> 8
    );

create table if not exists public.contratos (
    id bigint generated always as identity primary key,
    cliente_id bigint not null references public.clientes (id),
    descricao text not null default 'Manutenção mensal',
    valor_mensal numeric(12, 2) not null check (valor_mensal > 0),
    dia_vencimento int not null default 10 check (
        dia_vencimento between 1 and 28
    ),
    visitas text not null default '1x por semana',
    dia_visita text not null default '',
    inicio date not null default current_date,
    ativo boolean not null default true,
    observacoes text not null default '',
    criado_em timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5. VENDAS E FINANCEIRO (sem caixa físico: tudo é venda online)
-- ---------------------------------------------------------------------
create table if not exists public.vendas (
    id bigint generated always as identity primary key,
    cliente_id bigint references public.clientes (id),
    cliente_nome text not null default '',
    canal text not null default 'whatsapp',
    subtotal numeric(12, 2) not null default 0,
    desconto numeric(12, 2) not null default 0 check (desconto >= 0),
    frete numeric(12, 2) not null default 0 check (frete >= 0),
    total numeric(12, 2) not null default 0,
    forma_pagamento text not null,
    status text not null default 'paga',
    observacao text not null default '',
    usuario_id uuid default auth.uid (),
    criado_em timestamptz not null default now()
);

alter table public.vendas
add column if not exists entrega_status text not null default 'nao_se_aplica';

alter table public.vendas
add column if not exists entrega_cep text not null default '';

alter table public.vendas
add column if not exists entrega_endereco text not null default '';

alter table public.vendas
add column if not exists entrega_atualizada_em timestamptz;

alter table public.vendas alter column canal set default 'whatsapp';

alter table public.vendas
drop constraint if exists vendas_canal_check;

alter table public.vendas
add constraint vendas_canal_check check (
    canal in (
        'whatsapp',
        'telefone',
        'instagram',
        'site',
        'orcamento',
        'servico',
        'balcao',
        'outro'
    )
);

alter table public.vendas
drop constraint if exists vendas_forma_pagamento_check;

alter table public.vendas
add constraint vendas_forma_pagamento_check check (
    forma_pagamento in (
        'pix',
        'credito',
        'debito',
        'boleto',
        'transferencia',
        'dinheiro',
        'a_prazo'
    )
);

alter table public.vendas
drop constraint if exists vendas_status_check;

alter table public.vendas
add constraint vendas_status_check check (
    status in (
        'paga',
        'pendente',
        'cancelada'
    )
);

alter table public.vendas
drop constraint if exists vendas_entrega_status_check;

alter table public.vendas
add constraint vendas_entrega_status_check check (
    entrega_status in (
        'nao_se_aplica',
        'pendente',
        'separando',
        'em_rota',
        'entregue',
        'cancelada'
    )
);

create index if not exists vendas_data_idx on public.vendas (criado_em desc);

create table if not exists public.venda_itens (
    id bigint generated always as identity primary key,
    venda_id bigint not null references public.vendas (id) on delete cascade,
    produto_id text references public.produtos (id) on update cascade,
    descricao text not null,
    quantidade numeric(12, 3) not null check (quantidade > 0),
    preco_unit numeric(12, 2) not null check (preco_unit >= 0),
    total numeric(12, 2) not null
);

create table if not exists public.lancamentos (
    id bigint generated always as identity primary key,
    tipo text not null check (tipo in ('receber', 'pagar')),
    categoria text not null default 'Outros',
    descricao text not null,
    valor numeric(12, 2) not null check (valor > 0),
    vencimento date not null default current_date,
    competencia date,
    status text not null default 'aberto' check (
        status in ('aberto', 'pago', 'cancelado')
    ),
    pago_em timestamptz,
    forma_pagamento text check (
        forma_pagamento in (
            'pix',
            'credito',
            'debito',
            'dinheiro',
            'boleto',
            'transferencia'
        )
    ),
    cliente_id bigint references public.clientes (id),
    venda_id bigint references public.vendas (id),
    contrato_id bigint references public.contratos (id),
    usuario_id uuid default auth.uid (),
    criado_em timestamptz not null default now()
);

create index if not exists lanc_venc_idx on public.lancamentos (status, vencimento);

create index if not exists lanc_pago_idx on public.lancamentos (pago_em);

create unique index if not exists uma_mensalidade_por_mes on public.lancamentos (contrato_id, competencia)
where
    contrato_id is not null
    and status <> 'cancelado';

-- Remoção do caixa físico (versão anterior)
drop policy if exists equipe_cria on public.lancamentos;
-- dependia de caixa_id; é recriada mais abaixo
drop function if exists public.abrir_caixa(numeric);

drop function if exists public.fechar_caixa (numeric, text);

drop function if exists public.movimentar_caixa (text, numeric, text);

drop function if exists public.resumo_caixa (bigint);

drop function if exists public.caixa_aberto_id ();

alter table public.vendas drop column if exists caixa_id;

alter table public.lancamentos drop column if exists caixa_id;

drop table if exists public.caixas;

-- ---------------------------------------------------------------------
-- 6. ORÇAMENTOS E AGENDA
-- ---------------------------------------------------------------------
create table if not exists public.orcamentos (
    id bigint generated always as identity primary key,
    cliente_id bigint references public.clientes (id),
    cliente_nome text not null default '',
    telefone text not null default '',
    titulo text not null,
    status text not null default 'rascunho' check (
        status in (
            'rascunho',
            'enviado',
            'aprovado',
            'recusado',
            'convertido'
        )
    ),
    validade date not null default(current_date + 15),
    desconto numeric(12, 2) not null default 0 check (desconto >= 0),
    total numeric(12, 2) not null default 0,
    condicoes text not null default '',
    venda_id bigint references public.vendas (id),
    usuario_id uuid default auth.uid (),
    criado_em timestamptz not null default now()
);

create table if not exists public.orcamento_itens (
    id bigint generated always as identity primary key,
    orcamento_id bigint not null references public.orcamentos (id) on delete cascade,
    produto_id text references public.produtos (id) on update cascade,
    descricao text not null,
    quantidade numeric(12, 3) not null check (quantidade > 0),
    preco_unit numeric(12, 2) not null check (preco_unit >= 0),
    total numeric(12, 2) not null
);

create table if not exists public.agenda (
    id bigint generated always as identity primary key,
    cliente_id bigint references public.clientes (id),
    contrato_id bigint references public.contratos (id),
    tipo text not null default 'manutencao' check (
        tipo in (
            'manutencao',
            'instalacao',
            'tratamento',
            'visita_tecnica',
            'entrega',
            'outro'
        )
    ),
    data date not null,
    hora time,
    responsavel text not null default '',
    endereco text not null default '',
    status text not null default 'agendado' check (
        status in (
            'agendado',
            'concluido',
            'cancelado'
        )
    ),
    observacoes text not null default '',
    criado_em timestamptz not null default now()
);

create index if not exists agenda_data_idx on public.agenda (data);

-- ---------------------------------------------------------------------
-- 7. O QUE CHEGA PELO SITE: pedidos e solicitações (orçamento / contato)
-- ---------------------------------------------------------------------
create table if not exists public.pedidos_site (
    id bigint generated always as identity primary key,
    nome text not null,
    telefone text not null default '',
    cep text not null default '',
    forma_pagamento text not null default 'pix',
    itens jsonb not null,
    subtotal numeric(12, 2) not null,
    frete numeric(12, 2) not null,
    total numeric(12, 2) not null,
    status text not null default 'novo' check (
        status in (
            'novo',
            'convertido',
            'descartado'
        )
    ),
    venda_id bigint references public.vendas (id),
    criado_em timestamptz not null default now()
);

alter table public.pedidos_site
add column if not exists cpf_cnpj text not null default '';

alter table public.pedidos_site
add column if not exists logradouro text not null default '';

alter table public.pedidos_site
add column if not exists numero text not null default '';

alter table public.pedidos_site
add column if not exists complemento text not null default '';

alter table public.pedidos_site
add column if not exists bairro text not null default '';

alter table public.pedidos_site
add column if not exists cidade text not null default '';

alter table public.pedidos_site
add column if not exists uf text not null default '';

alter table public.pedidos_site
add column if not exists observacao text not null default '';

create table if not exists public.solicitacoes_site (
    id bigint generated always as identity primary key,
    tipo text not null check (
        tipo in ('orcamento', 'contato')
    ),
    nome text not null,
    telefone text not null,
    cep text not null default '',
    cidade text not null default '',
    referencia text not null default '', -- ex.: modelo de piscina
    mensagem text not null default '',
    status text not null default 'nova' check (
        status in (
            'nova',
            'respondida',
            'convertida',
            'descartada'
        )
    ),
    orcamento_id bigint references public.orcamentos (id),
    criado_em timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 8. FUNÇÕES DO SISTEMA (equipe)
-- ---------------------------------------------------------------------

-- Registrar venda.
-- p = {cliente_id?, cliente_nome?, canal, desconto, frete, forma_pagamento, pago (true/false), vencimento?,
--      observacao?, entrega?: {cep, endereco}, itens:[{produto_id?, descricao, quantidade, preco_unit}]}
drop function if exists public.registrar_venda (jsonb);

create function public.registrar_venda(p jsonb) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_id bigint; v_sub numeric(12,2) := 0; v_total numeric(12,2); it jsonb; v_q numeric; v_pu numeric;
  v_desc text; v_prod text; v_nome text; v_forma text := coalesce(p->>'forma_pagamento','pix');
  v_pago boolean; v_cli bigint := nullif(p->>'cliente_id','')::bigint; v_ent jsonb := p->'entrega';
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  if v_forma not in ('pix','credito','debito','boleto','transferencia','dinheiro','a_prazo') then
    raise exception 'Forma de pagamento inválida'; end if;
  v_pago := coalesce((p->>'pago')::boolean, v_forma <> 'a_prazo') and v_forma <> 'a_prazo';
  if jsonb_typeof(p->'itens') is distinct from 'array' or jsonb_array_length(p->'itens') = 0 then
    raise exception 'A venda precisa de pelo menos um item'; end if;

  v_nome := coalesce(nullif(trim(p->>'cliente_nome'),''), (select nome from public.clientes where id = v_cli), '');
  if not v_pago and v_cli is null and v_nome = '' then
    raise exception 'Venda aguardando pagamento precisa do nome do cliente'; end if;
  if jsonb_typeof(v_ent) = 'object' and coalesce(trim(v_ent->>'endereco'),'') = '' then
    raise exception 'Informe o endereço de entrega'; end if;

  insert into public.vendas(cliente_id, cliente_nome, canal, desconto, frete, forma_pagamento, status, observacao,
                            entrega_status, entrega_cep, entrega_endereco, entrega_atualizada_em)
  values (v_cli, v_nome, coalesce(nullif(p->>'canal',''),'whatsapp'),
          coalesce((p->>'desconto')::numeric,0), coalesce((p->>'frete')::numeric,0),
          v_forma, case when v_pago then 'paga' else 'pendente' end, coalesce(p->>'observacao',''),
          case when jsonb_typeof(v_ent) = 'object' then 'pendente' else 'nao_se_aplica' end,
          case when jsonb_typeof(v_ent) = 'object' then public.so_digitos(v_ent->>'cep') else '' end,
          case when jsonb_typeof(v_ent) = 'object' then trim(v_ent->>'endereco') else '' end,
          case when jsonb_typeof(v_ent) = 'object' then now() end)
  returning id into v_id;

  for it in select * from jsonb_array_elements(p->'itens') loop
    v_q := (it->>'quantidade')::numeric; v_pu := coalesce((it->>'preco_unit')::numeric, 0);
    v_prod := nullif(it->>'produto_id','');
    v_desc := coalesce(nullif(trim(it->>'descricao'),''), (select nome from public.produtos where id = v_prod), 'Item');
    if v_q is null or v_q <= 0 then raise exception 'Quantidade inválida em %', v_desc; end if;
    if v_pu < 0 then raise exception 'Preço inválido em %', v_desc; end if;
    if v_prod is not null and not exists(select 1 from public.produtos where id = v_prod) then
      raise exception 'Produto não encontrado: %', v_prod; end if;
    insert into public.venda_itens(venda_id, produto_id, descricao, quantidade, preco_unit, total)
    values (v_id, v_prod, v_desc, v_q, v_pu, round(v_q*v_pu,2));
    v_sub := v_sub + round(v_q*v_pu,2);
    if v_prod is not null then
      insert into public.movimentos_estoque(produto_id, tipo, quantidade, observacao, venda_id)
      values (v_prod, 'venda', -v_q, 'Venda #'||v_id, v_id);
    end if;
  end loop;

  v_total := v_sub - coalesce((p->>'desconto')::numeric,0) + coalesce((p->>'frete')::numeric,0);
  if v_total < 0 then raise exception 'O desconto é maior que o valor da venda'; end if;
  update public.vendas set subtotal = v_sub, total = v_total where id = v_id;

  if v_total > 0 then
    insert into public.lancamentos(tipo, categoria, descricao, valor, vencimento, status, pago_em, forma_pagamento, cliente_id, venda_id)
    values ('receber', 'Vendas', 'Venda #'||v_id||coalesce(' – '||nullif(v_nome,''),''), v_total,
            coalesce(nullif(p->>'vencimento','')::date, current_date),
            case when v_pago then 'pago' else 'aberto' end,
            case when v_pago then now() end,
            case when v_pago and v_forma <> 'a_prazo' then v_forma end,
            v_cli, v_id);
  end if;
  return v_id;
end $$;

-- Cancelar venda (administrador): devolve o estoque; se já estava paga, cria a devolução a pagar
create or replace function public.cancelar_venda(p_id bigint, p_motivo text default '') returns void
language plpgsql security definer set search_path = public as $$
declare r record; v record;
begin
  if not public.eh_admin() then raise exception 'Só o administrador pode cancelar vendas'; end if;
  select * into v from public.vendas where id = p_id;
  if v.id is null or v.status = 'cancelada' then raise exception 'Venda não encontrada ou já cancelada'; end if;
  for r in select produto_id, quantidade from public.venda_itens where venda_id = p_id and produto_id is not null loop
    insert into public.movimentos_estoque(produto_id, tipo, quantidade, observacao, venda_id)
    values (r.produto_id, 'cancelamento', r.quantidade, 'Cancelamento da venda #'||p_id, p_id);
  end loop;
  update public.vendas set status = 'cancelada',
         entrega_status = case when entrega_status = 'nao_se_aplica' then entrega_status else 'cancelada' end,
         observacao = trim(observacao||' [Cancelada: '||coalesce(nullif(p_motivo,''),'sem motivo')||']') where id = p_id;
  update public.lancamentos set status = 'cancelado' where venda_id = p_id and status = 'aberto';
  insert into public.lancamentos(tipo, categoria, descricao, valor, vencimento, cliente_id, venda_id)
  select 'pagar', 'Devoluções', 'Devolver ao cliente – venda #'||p_id||coalesce(' – '||nullif(v.cliente_nome,''),''),
         sum(valor), current_date, v.cliente_id, p_id
    from public.lancamentos where venda_id = p_id and tipo = 'receber' and status = 'pago'
  having coalesce(sum(valor),0) > 0;
end $$;

-- Dar baixa (pago/recebido)
create or replace function public.baixar_lancamento(p_id bigint, p_forma text) returns void
language plpgsql security definer set search_path = public as $$
declare v_venda bigint;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  if p_forma not in ('pix','credito','debito','dinheiro','boleto','transferencia') then raise exception 'Forma de pagamento inválida'; end if;
  update public.lancamentos set status = 'pago', pago_em = now(), forma_pagamento = p_forma
   where id = p_id and status = 'aberto' returning venda_id into v_venda;
  if not found then raise exception 'Conta não encontrada ou já baixada'; end if;
  if v_venda is not null then
    update public.vendas set status = 'paga', forma_pagamento = p_forma where id = v_venda and status = 'pendente';
  end if;
end $$;

-- Atualizar a situação da entrega
create or replace function public.atualizar_entrega(p_id bigint, p_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  if p_status not in ('pendente','separando','em_rota','entregue') then raise exception 'Situação de entrega inválida'; end if;
  update public.vendas set entrega_status = p_status, entrega_atualizada_em = now()
   where id = p_id and status <> 'cancelada' and entrega_status not in ('nao_se_aplica','cancelada');
  if not found then raise exception 'Esta venda não tem entrega ativa'; end if;
end $$;

-- Gerar mensalidades do mês (não duplica)
create or replace function public.gerar_mensalidades(p_mes date) returns int
language plpgsql security definer set search_path = public as $$
declare v_comp date := date_trunc('month', p_mes)::date; n int;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  insert into public.lancamentos(tipo, categoria, descricao, valor, vencimento, competencia, cliente_id, contrato_id)
  select 'receber', 'Mensalidades', c.descricao||' – '||cl.nome||' ('||to_char(v_comp,'MM/YYYY')||')',
         c.valor_mensal, v_comp + (c.dia_vencimento - 1), v_comp, c.cliente_id, c.id
    from public.contratos c join public.clientes cl on cl.id = c.cliente_id
   where c.ativo and c.inicio <= (v_comp + interval '1 month' - interval '1 day')::date
     and not exists (select 1 from public.lancamentos l where l.contrato_id = c.id and l.competencia = v_comp and l.status <> 'cancelado');
  get diagnostics n = row_count;
  return n;
end $$;

-- Orçamento aprovado → venda
drop function if exists public.converter_orcamento (bigint, text, date);

create or replace function public.converter_orcamento(p_id bigint, p_forma text, p_pago boolean, p_vencimento date default null) returns bigint
language plpgsql security definer set search_path = public as $$
declare o record; v bigint;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  select * into o from public.orcamentos where id = p_id;
  if o.id is null or o.status = 'convertido' then raise exception 'Orçamento não encontrado ou já convertido'; end if;
  if not exists(select 1 from public.orcamento_itens where orcamento_id = p_id) then raise exception 'O orçamento não tem itens'; end if;
  v := public.registrar_venda(jsonb_build_object(
        'cliente_id', o.cliente_id, 'cliente_nome', o.cliente_nome, 'canal', 'orcamento',
        'desconto', o.desconto, 'frete', 0, 'forma_pagamento', p_forma, 'pago', p_pago, 'vencimento', p_vencimento,
        'observacao', 'Orçamento #'||o.id||' – '||o.titulo,
        'itens', (select jsonb_agg(jsonb_build_object('produto_id', produto_id, 'descricao', descricao,
                    'quantidade', quantidade, 'preco_unit', preco_unit)) from public.orcamento_itens where orcamento_id = p_id)));
  update public.orcamentos set status = 'convertido', venda_id = v where id = p_id;
  update public.solicitacoes_site set status = 'convertida' where orcamento_id = p_id;
  return v;
end $$;

create or replace function public.recalcular_orcamento() returns trigger
language plpgsql security definer set search_path = public as $$
declare oid bigint := coalesce(new.orcamento_id, old.orcamento_id);
begin
  update public.orcamentos o
     set total = greatest(0, coalesce((select sum(total) from public.orcamento_itens where orcamento_id = oid),0) - o.desconto)
   where o.id = oid;
  return null;
end $$;

drop trigger if exists ao_mudar_item_orc on public.orcamento_itens;

create trigger ao_mudar_item_orc after insert or update or delete on public.orcamento_itens
  for each row execute function public.recalcular_orcamento();

-- Pedido do site → venda (cria ou reaproveita o cliente pelo telefone)
drop function if exists public.converter_pedido_site (bigint, text, bigint);

create or replace function public.converter_pedido_site(p_id bigint, p_forma text, p_pago boolean, p_cliente_id bigint default null) returns bigint
language plpgsql security definer set search_path = public as $$
declare ps record; v bigint; v_cli bigint := p_cliente_id; v_end text;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  select * into ps from public.pedidos_site where id = p_id and status = 'novo';
  if ps.id is null then raise exception 'Pedido não encontrado ou já tratado'; end if;
  if v_cli is null and ps.telefone <> '' then
    select id into v_cli from public.clientes where telefone = ps.telefone order by id limit 1;
  end if;
  if v_cli is null then
    insert into public.clientes(nome, telefone, cpf_cnpj, cep, endereco, numero, complemento, bairro, cidade, uf)
    values (ps.nome, ps.telefone, case when public.valida_doc(ps.cpf_cnpj) then ps.cpf_cnpj else '' end,
            ps.cep, ps.logradouro, ps.numero, ps.complemento, ps.bairro, coalesce(nullif(ps.cidade,''),'São Paulo'), coalesce(nullif(ps.uf,''),'SP'))
    returning id into v_cli;
  end if;
  v_end := concat_ws(', ', nullif(ps.logradouro,''), nullif(ps.numero,''), nullif(ps.complemento,''), nullif(ps.bairro,''),
                     nullif(ps.cidade,'')||coalesce('/'||nullif(ps.uf,''),''));
  v := public.registrar_venda(jsonb_build_object('cliente_id', v_cli, 'cliente_nome', ps.nome, 'canal','site',
        'desconto',0,'frete',ps.frete,'forma_pagamento',p_forma,'pago',p_pago,
        'observacao','Pedido do site #'||ps.id||case when ps.observacao<>'' then ' – '||ps.observacao else '' end,
        'entrega', case when v_end <> '' then jsonb_build_object('cep', ps.cep, 'endereco', v_end) end,
        'itens', ps.itens));
  update public.pedidos_site set status='convertido', venda_id=v where id=p_id;
  return v;
end $$;

-- ---------------------------------------------------------------------
-- 9. FUNÇÕES PÚBLICAS usadas pelo SITE (sem login)
-- ---------------------------------------------------------------------
create or replace function public.produtos_site()
returns table(id text, nome text, categoria text, descricao text, preco numeric, disponivel boolean, icone text)
language sql stable security definer set search_path = public as $$
  select id, nome, categoria, descricao, preco_venda, estoque > 0, icone
    from public.produtos where ativo and no_site order by categoria, nome;
$$;

create or replace function public.config_publica() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('whatsapp', whatsapp, 'pix_chave', pix_chave, 'pix_nome', pix_nome,
    'frete_valor', frete_valor, 'frete_gratis_acima', frete_gratis_acima, 'cidades', to_jsonb(cidades),
    'aceita_pedidos', aceita_pedidos, 'aviso', aviso)
  from public.config_site where id = 1;
$$;

-- Registrar pedido do site. Tudo é validado e recalculado aqui; o navegador não decide preço nem frete.
drop function if exists public.registrar_pedido_site (jsonb);

create function public.registrar_pedido_site(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  cfg record; it jsonb; v_itens jsonb := '[]'::jsonb; v_sub numeric(12,2) := 0; v_q int; pr record;
  v_frete numeric(12,2); v_id bigint; v_tel text := public.so_digitos(p->>'telefone'); v_cep text := public.so_digitos(p->>'cep');
  v_doc text := public.so_digitos(p->>'cpf_cnpj'); v_cid text := trim(coalesce(p->>'cidade',''));
  v_forma text := coalesce(p->>'forma_pagamento','pix');
begin
  select * into cfg from public.config_site where id = 1;
  if not coalesce(cfg.aceita_pedidos, true) then raise exception 'No momento não estamos recebendo pedidos pelo site. Fale com a gente pelo WhatsApp.'; end if;
  if length(trim(coalesce(p->>'nome',''))) not between 2 and 120 then raise exception 'Informe seu nome completo.'; end if;
  if length(v_tel) not between 10 and 11 then raise exception 'Informe um WhatsApp válido com DDD.'; end if;
  if length(v_cep) <> 8 then raise exception 'Informe um CEP válido.'; end if;
  if trim(coalesce(p->>'logradouro','')) = '' or trim(coalesce(p->>'numero','')) = '' or v_cid = '' then
    raise exception 'Preencha o endereço de entrega (rua, número e cidade).'; end if;
  if v_doc <> '' and not public.valida_doc(v_doc) then raise exception 'CPF ou CNPJ inválido.'; end if;
  if v_forma not in ('pix','credito','debito','dinheiro') then raise exception 'Forma de pagamento inválida.'; end if;
  if coalesce(array_length(cfg.cidades,1),0) > 0
     and not exists(select 1 from unnest(cfg.cidades) c where public.sem_acento(c) = public.sem_acento(v_cid)) then
    raise exception 'Ainda não entregamos em %. Fale com a gente pelo WhatsApp.', v_cid;
  end if;
  -- usa o nome da cidade como está cadastrado (ex.: "campinas" → "Campinas")
  select c into v_cid from unnest(cfg.cidades) c where public.sem_acento(c) = public.sem_acento(v_cid) limit 1;
  v_cid := coalesce(v_cid, trim(coalesce(p->>'cidade','')));
  if jsonb_typeof(p->'itens') is distinct from 'array' or jsonb_array_length(p->'itens') not between 1 and 40 then
    raise exception 'Seu carrinho está vazio.'; end if;
  if (select count(*) from public.pedidos_site where criado_em > now() - interval '1 hour') >= 30 then
    raise exception 'Recebemos muitos pedidos agora. Tente em alguns minutos ou fale pelo WhatsApp.'; end if;

  for it in select * from jsonb_array_elements(p->'itens') loop
    begin v_q := (it->>'quantidade')::int; exception when others then v_q := null; end;
    if v_q is null or v_q < 1 or v_q > 100 then raise exception 'Quantidade inválida no carrinho.'; end if;
    select * into pr from public.produtos where id = it->>'produto_id' and ativo and no_site;
    if pr.id is null then raise exception 'Um produto do carrinho não está mais disponível. Atualize a página.'; end if;
    if pr.estoque <= 0 then raise exception 'O produto "%" esgotou. Remova do carrinho para continuar.', pr.nome; end if;
    v_itens := v_itens || jsonb_build_object('produto_id', pr.id, 'descricao', pr.nome, 'quantidade', v_q,
                                             'preco_unit', pr.preco_venda, 'total', round(v_q*pr.preco_venda,2));
    v_sub := v_sub + round(v_q*pr.preco_venda,2);
  end loop;
  v_frete := case when v_sub >= cfg.frete_gratis_acima then 0 else cfg.frete_valor end;

  insert into public.pedidos_site(nome, telefone, cep, forma_pagamento, itens, subtotal, frete, total,
                                  cpf_cnpj, logradouro, numero, complemento, bairro, cidade, uf, observacao)
  values (left(trim(p->>'nome'),120), v_tel, v_cep, v_forma, v_itens, v_sub, v_frete, v_sub + v_frete, v_doc,
          left(trim(p->>'logradouro'),150), left(trim(p->>'numero'),20), left(trim(coalesce(p->>'complemento','')),80),
          left(trim(coalesce(p->>'bairro','')),80), left(v_cid,80), upper(left(trim(coalesce(p->>'uf','')),2)),
          left(trim(coalesce(p->>'observacao','')),500))
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'subtotal', v_sub, 'frete', v_frete, 'total', v_sub + v_frete, 'itens', v_itens,
                            'pix_chave', cfg.pix_chave, 'pix_nome', cfg.pix_nome);
end $$;

-- Cliente acompanha o pedido no site (precisa do número do pedido + o mesmo WhatsApp)
create or replace function public.consultar_pedido(p_id bigint, p_telefone text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare ps record; v record; etapa text;
begin
  if length(public.so_digitos(p_telefone)) < 10 then raise exception 'Informe o WhatsApp usado no pedido.'; end if;
  select * into ps from public.pedidos_site where id = p_id and telefone = public.so_digitos(p_telefone);
  if ps.id is null then raise exception 'Pedido não encontrado. Confira o número e o WhatsApp.'; end if;
  select status, entrega_status, entrega_atualizada_em into v from public.vendas where id = ps.venda_id;  -- vazio se ainda não virou venda
  etapa := case
    when ps.status = 'descartado' or v.status = 'cancelada' then 'cancelado'
    when ps.status = 'novo' then 'recebido'
    when v.entrega_status = 'entregue' then 'entregue'
    when v.entrega_status = 'em_rota' then 'em_rota'
    when v.entrega_status = 'separando' then 'separando'
    else 'confirmado' end;
  return jsonb_build_object('id', ps.id, 'criado_em', ps.criado_em, 'etapa', etapa,
    'pagamento', case when v.status = 'paga' then 'pago' when v.status = 'pendente' then 'aguardando' else null end,
    'itens', ps.itens, 'frete', ps.frete, 'total', ps.total, 'atualizado_em', coalesce(v.entrega_atualizada_em, ps.criado_em));
end $$;

-- Pedido de orçamento ou mensagem de contato
create or replace function public.registrar_solicitacao(p jsonb) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_id bigint; v_tel text := public.so_digitos(p->>'telefone'); v_tipo text := coalesce(p->>'tipo','contato');
begin
  if v_tipo not in ('orcamento','contato') then raise exception 'Tipo inválido.'; end if;
  if length(trim(coalesce(p->>'nome',''))) not between 2 and 120 then raise exception 'Informe seu nome.'; end if;
  if length(v_tel) not between 10 and 11 then raise exception 'Informe um WhatsApp válido com DDD.'; end if;
  if length(coalesce(p->>'mensagem','')) > 2000 then raise exception 'Mensagem muito longa.'; end if;
  if (select count(*) from public.solicitacoes_site where criado_em > now() - interval '1 hour') >= 60 then
    raise exception 'Recebemos muitas mensagens agora. Tente em alguns minutos ou fale pelo WhatsApp.'; end if;
  insert into public.solicitacoes_site(tipo, nome, telefone, cep, cidade, referencia, mensagem)
  values (v_tipo, left(trim(p->>'nome'),120), v_tel, public.so_digitos(p->>'cep'), left(trim(coalesce(p->>'cidade','')),80),
          left(trim(coalesce(p->>'referencia','')),200), left(trim(coalesce(p->>'mensagem','')),2000))
  returning id into v_id;
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- 10. SEGURANÇA
-- ---------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

grant
select,
insert
,
update,
delete on all tables in schema public to authenticated;

do $$
declare t text;
begin
  foreach t in array array['produtos','movimentos_estoque','clientes','contratos','vendas','venda_itens','lancamentos',
                           'orcamentos','orcamento_itens','agenda','pedidos_site','solicitacoes_site','perfis','config_site'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
  -- dia a dia da equipe; apagar só o administrador
  foreach t in array array['produtos','clientes','contratos','agenda','orcamentos','orcamento_itens'] loop
    execute format('drop policy if exists equipe_le on public.%I', t);
    execute format('drop policy if exists equipe_insere on public.%I', t);
    execute format('drop policy if exists equipe_altera on public.%I', t);
    execute format('drop policy if exists admin_apaga on public.%I', t);
    execute format('create policy equipe_le on public.%I for select to authenticated using (public.eh_equipe())', t);
    execute format('create policy equipe_insere on public.%I for insert to authenticated with check (public.eh_equipe())', t);
    execute format('create policy equipe_altera on public.%I for update to authenticated using (public.eh_equipe()) with check (public.eh_equipe())', t);
    execute format('create policy admin_apaga on public.%I for delete to authenticated using (public.eh_admin())', t);
  end loop;
  -- só leitura: mudam apenas pelas funções do sistema
  foreach t in array array['vendas','venda_itens','pedidos_site','solicitacoes_site','config_site'] loop
    execute format('drop policy if exists equipe_le on public.%I', t);
    execute format('create policy equipe_le on public.%I for select to authenticated using (public.eh_equipe())', t);
  end loop;
end $$;

-- Pedidos do site: equipe só pode descartar
drop policy if exists equipe_descarta on public.pedidos_site;

create policy equipe_descarta on public.pedidos_site for
update to authenticated using (
    public.eh_equipe ()
    and status = 'novo'
)
with
    check (
        public.eh_equipe ()
        and status = 'descartado'
    );

revoke
insert
,
update,
delete on public.pedidos_site
from authenticated;

grant update (status) on public.pedidos_site to authenticated;

-- Solicitações: equipe marca como respondida/descartada e liga ao orçamento
drop policy if exists equipe_trata on public.solicitacoes_site;

create policy equipe_trata on public.solicitacoes_site for
update to authenticated using (public.eh_equipe ())
with
    check (
        public.eh_equipe ()
        and status in (
            'nova',
            'respondida',
            'convertida',
            'descartada'
        )
    );

revoke
insert
,
update,
delete on public.solicitacoes_site
from authenticated;

grant
update (status, orcamento_id) on public.solicitacoes_site to authenticated;

-- Configurações do site: só o administrador altera
drop policy if exists admin_altera on public.config_site;

create policy admin_altera on public.config_site for
update to authenticated using (public.eh_admin ())
with
    check (public.eh_admin ());

revoke
insert
,
update,
delete on public.config_site
from authenticated;

grant
update (
    whatsapp,
    pix_chave,
    pix_nome,
    frete_valor,
    frete_gratis_acima,
    cidades,
    aceita_pedidos,
    aviso,
    atualizado_em
) on public.config_site to authenticated;

revoke
insert
,
update,
delete on public.vendas,
public.venda_itens
from authenticated;

drop policy if exists equipe_le on public.movimentos_estoque;

drop policy if exists equipe_lanca on public.movimentos_estoque;

create policy equipe_le on public.movimentos_estoque for
select to authenticated using (public.eh_equipe ());

create policy equipe_lanca on public.movimentos_estoque for
insert
    to authenticated
with
    check (
        public.eh_equipe ()
        and tipo in ('entrada', 'saida', 'ajuste')
        and venda_id is null
    );

revoke
update,
delete on public.movimentos_estoque
from authenticated;

drop policy if exists equipe_le on public.lancamentos;

drop policy if exists equipe_cria on public.lancamentos;

drop policy if exists admin_altera on public.lancamentos;

create policy equipe_le on public.lancamentos for
select to authenticated using (public.eh_equipe ());

create policy equipe_cria on public.lancamentos for
insert
    to authenticated
with
    check (
        public.eh_equipe ()
        and status = 'aberto'
        and venda_id is null
    );

create policy admin_altera on public.lancamentos for
update to authenticated using (public.eh_admin ())
with
    check (public.eh_admin ());

revoke delete on public.lancamentos from authenticated;

drop policy if exists ve_proprio on public.perfis;

drop policy if exists admin_gerencia on public.perfis;

create policy ve_proprio on public.perfis for
select to authenticated using (
        id = auth.uid ()
        or public.eh_admin ()
    );

create policy admin_gerencia on public.perfis for
update to authenticated using (public.eh_admin ())
with
    check (public.eh_admin ());

revoke insert , delete on public.perfis from authenticated;

revoke insert , update on public.produtos from authenticated;

grant
insert (
        id,
        nome,
        categoria,
        descricao,
        unidade,
        preco_venda,
        custo,
        estoque_minimo,
        icone,
        ativo,
        no_site
    ) on public.produtos to authenticated;

grant
update (
    nome,
    categoria,
    descricao,
    unidade,
    preco_venda,
    custo,
    estoque_minimo,
    icone,
    ativo,
    no_site,
    atualizado_em
) on public.produtos to authenticated;

-- Quem pode chamar cada função
revoke execute on all functions in schema public from public, anon;

grant execute on function public.produtos_site(), public.config_publica(), public.registrar_pedido_site(jsonb),
  public.consultar_pedido(bigint, text), public.registrar_solicitacao(jsonb) to anon, authenticated;

grant
execute on function public.so_digitos (text),
public.sem_acento (text),
public.valida_doc (text),
public.eh_equipe (),
public.eh_admin (),
public.registrar_venda (jsonb),
public.cancelar_venda (bigint, text),
public.baixar_lancamento (bigint, text),
public.atualizar_entrega (bigint, text),
public.gerar_mensalidades (date),
public.converter_orcamento (bigint, text, boolean, date),
public.converter_pedido_site (bigint, text, boolean, bigint) to authenticated;