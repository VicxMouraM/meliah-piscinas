-- =====================================================================
--  MELIAH PISCINAS – Banco de dados do sistema de gestão
--  Rode este arquivo inteiro no Supabase: SQL Editor → New query → Run
--  Pode rodar de novo sem perder dados (comandos "if not exists").
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. EQUIPE (perfis de quem acessa o painel)
-- ---------------------------------------------------------------------
create table if not exists public.perfis (
  id         uuid primary key references auth.users(id) on delete cascade,
  nome       text not null default '',
  email      text,
  papel      text not null default 'funcionario' check (papel in ('admin','funcionario')),
  ativo      boolean not null default false,
  criado_em  timestamptz not null default now()
);

-- Quem é da equipe (perfil ativo)?
create or replace function public.eh_equipe() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.perfis where id = auth.uid() and ativo);
$$;

-- Quem é administrador?
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
  values (new.id,
          coalesce(new.raw_user_meta_data->>'nome', split_part(new.email,'@',1)),
          new.email,
          case when primeiro then 'admin' else 'funcionario' end,
          primeiro)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario after insert on auth.users
  for each row execute function public.novo_usuario();

-- ---------------------------------------------------------------------
-- 2. PRODUTOS E ESTOQUE
-- ---------------------------------------------------------------------
create table if not exists public.produtos (
  id              text primary key check (id ~ '^[a-z0-9_-]{2,40}$'),  -- código, ex.: clg10
  nome            text not null,
  categoria       text not null default 'Outros',
  descricao       text not null default '',
  unidade         text not null default 'un',
  preco_venda     numeric(12,2) not null default 0 check (preco_venda >= 0),
  custo           numeric(12,2) not null default 0 check (custo >= 0),
  estoque         numeric(12,3) not null default 0,
  estoque_minimo  numeric(12,3) not null default 0,
  icone           text not null default 'balde',
  ativo           boolean not null default true,
  no_site         boolean not null default true,
  atualizado_em   timestamptz not null default now()
);

create table if not exists public.movimentos_estoque (
  id           bigint generated always as identity primary key,
  produto_id   text not null references public.produtos(id) on update cascade,
  tipo         text not null check (tipo in ('entrada','saida','ajuste','venda','cancelamento')),
  quantidade   numeric(12,3) not null check (quantidade <> 0),   -- positivo entra, negativo sai
  custo_unit   numeric(12,2),
  observacao   text not null default '',
  venda_id     bigint,
  usuario_id   uuid default auth.uid(),
  criado_em    timestamptz not null default now()
);
create index if not exists mov_produto_idx on public.movimentos_estoque(produto_id, criado_em desc);

-- Cada movimento atualiza o estoque do produto (e o custo, nas entradas)
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
create trigger ao_movimentar after insert on public.movimentos_estoque
  for each row execute function public.aplicar_movimento();

-- ---------------------------------------------------------------------
-- 3. CLIENTES E MENSALIDADES
-- ---------------------------------------------------------------------
create table if not exists public.clientes (
  id             bigint generated always as identity primary key,
  nome           text not null,
  telefone       text not null default '',
  email          text not null default '',
  cpf_cnpj       text not null default '',
  endereco       text not null default '',
  bairro         text not null default '',
  cidade         text not null default 'Campinas',
  cep            text not null default '',
  volume_litros  integer,
  observacoes    text not null default '',
  criado_em      timestamptz not null default now()
);

create table if not exists public.contratos (
  id               bigint generated always as identity primary key,
  cliente_id       bigint not null references public.clientes(id),
  descricao        text not null default 'Manutenção mensal',
  valor_mensal     numeric(12,2) not null check (valor_mensal > 0),
  dia_vencimento   int not null default 10 check (dia_vencimento between 1 and 28),
  visitas          text not null default '1x por semana',
  dia_visita       text not null default '',
  inicio           date not null default current_date,
  ativo            boolean not null default true,
  observacoes      text not null default '',
  criado_em        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 4. CAIXA, VENDAS E FINANCEIRO
-- ---------------------------------------------------------------------
create table if not exists public.caixas (
  id              bigint generated always as identity primary key,
  status          text not null default 'aberto' check (status in ('aberto','fechado')),
  aberto_em       timestamptz not null default now(),
  aberto_por      uuid default auth.uid(),
  valor_abertura  numeric(12,2) not null default 0 check (valor_abertura >= 0),
  fechado_em      timestamptz,
  fechado_por     uuid,
  valor_esperado  numeric(12,2),
  valor_contado   numeric(12,2),
  observacao      text not null default ''
);
create unique index if not exists um_caixa_aberto on public.caixas((true)) where status = 'aberto';

create table if not exists public.vendas (
  id               bigint generated always as identity primary key,
  cliente_id       bigint references public.clientes(id),
  cliente_nome     text not null default '',
  caixa_id         bigint references public.caixas(id),
  canal            text not null default 'balcao' check (canal in ('balcao','whatsapp','site','servico','orcamento')),
  subtotal         numeric(12,2) not null default 0,
  desconto         numeric(12,2) not null default 0 check (desconto >= 0),
  frete            numeric(12,2) not null default 0 check (frete >= 0),
  total            numeric(12,2) not null default 0,
  forma_pagamento  text not null check (forma_pagamento in ('pix','credito','debito','dinheiro','boleto','a_prazo')),
  status           text not null default 'paga' check (status in ('paga','pendente','cancelada')),
  observacao       text not null default '',
  usuario_id       uuid default auth.uid(),
  criado_em        timestamptz not null default now()
);
create index if not exists vendas_data_idx on public.vendas(criado_em desc);

create table if not exists public.venda_itens (
  id           bigint generated always as identity primary key,
  venda_id     bigint not null references public.vendas(id) on delete cascade,
  produto_id   text references public.produtos(id) on update cascade,  -- vazio = serviço
  descricao    text not null,
  quantidade   numeric(12,3) not null check (quantidade > 0),
  preco_unit   numeric(12,2) not null check (preco_unit >= 0),
  total        numeric(12,2) not null
);

-- Livro financeiro: tudo que entra (receber) e sai (pagar)
create table if not exists public.lancamentos (
  id               bigint generated always as identity primary key,
  tipo             text not null check (tipo in ('receber','pagar')),
  categoria        text not null default 'Outros',
  descricao        text not null,
  valor            numeric(12,2) not null check (valor > 0),
  vencimento       date not null default current_date,
  competencia      date,                                   -- mês de referência (mensalidades)
  status           text not null default 'aberto' check (status in ('aberto','pago','cancelado')),
  pago_em          timestamptz,
  forma_pagamento  text check (forma_pagamento in ('pix','credito','debito','dinheiro','boleto','transferencia')),
  caixa_id         bigint references public.caixas(id),
  cliente_id       bigint references public.clientes(id),
  venda_id         bigint references public.vendas(id),
  contrato_id      bigint references public.contratos(id),
  usuario_id       uuid default auth.uid(),
  criado_em        timestamptz not null default now()
);
create index if not exists lanc_venc_idx on public.lancamentos(status, vencimento);
create unique index if not exists uma_mensalidade_por_mes on public.lancamentos(contrato_id, competencia)
  where contrato_id is not null and status <> 'cancelado';

-- ---------------------------------------------------------------------
-- 5. ORÇAMENTOS E AGENDA
-- ---------------------------------------------------------------------
create table if not exists public.orcamentos (
  id            bigint generated always as identity primary key,
  cliente_id    bigint references public.clientes(id),
  cliente_nome  text not null default '',
  telefone      text not null default '',
  titulo        text not null,
  status        text not null default 'rascunho' check (status in ('rascunho','enviado','aprovado','recusado','convertido')),
  validade      date not null default (current_date + 15),
  desconto      numeric(12,2) not null default 0 check (desconto >= 0),
  total         numeric(12,2) not null default 0,
  condicoes     text not null default '',
  venda_id      bigint references public.vendas(id),
  usuario_id    uuid default auth.uid(),
  criado_em     timestamptz not null default now()
);

create table if not exists public.orcamento_itens (
  id             bigint generated always as identity primary key,
  orcamento_id   bigint not null references public.orcamentos(id) on delete cascade,
  produto_id     text references public.produtos(id) on update cascade,
  descricao      text not null,
  quantidade     numeric(12,3) not null check (quantidade > 0),
  preco_unit     numeric(12,2) not null check (preco_unit >= 0),
  total          numeric(12,2) not null
);

create table if not exists public.agenda (
  id            bigint generated always as identity primary key,
  cliente_id    bigint references public.clientes(id),
  contrato_id   bigint references public.contratos(id),
  tipo          text not null default 'manutencao' check (tipo in ('manutencao','instalacao','tratamento','visita_tecnica','entrega','outro')),
  data          date not null,
  hora          time,
  responsavel   text not null default '',
  endereco      text not null default '',
  status        text not null default 'agendado' check (status in ('agendado','concluido','cancelado')),
  observacoes   text not null default '',
  criado_em     timestamptz not null default now()
);
create index if not exists agenda_data_idx on public.agenda(data);

-- ---------------------------------------------------------------------
-- 6. PEDIDOS QUE CHEGAM PELO SITE
-- ---------------------------------------------------------------------
create table if not exists public.pedidos_site (
  id               bigint generated always as identity primary key,
  nome             text not null,
  telefone         text not null default '',
  cep              text not null default '',
  forma_pagamento  text not null default 'pix',
  itens            jsonb not null,           -- [{produto_id, descricao, quantidade, preco_unit, total}]
  subtotal         numeric(12,2) not null,
  frete            numeric(12,2) not null,
  total            numeric(12,2) not null,
  status           text not null default 'novo' check (status in ('novo','convertido','descartado')),
  venda_id         bigint references public.vendas(id),
  criado_em        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 7. FUNÇÕES DO SISTEMA
-- ---------------------------------------------------------------------

-- Caixa aberto agora (ou nulo)
create or replace function public.caixa_aberto_id() returns bigint
language sql stable set search_path = public as $$
  select id from public.caixas where status = 'aberto' limit 1;
$$;

-- Registrar uma venda completa.
-- p = {cliente_id?, cliente_nome?, canal, desconto, frete, forma_pagamento, vencimento?, observacao?,
--      itens:[{produto_id?, descricao, quantidade, preco_unit}]}
-- Venda paga exige caixa aberto. "a_prazo" gera conta a receber em aberto.
create or replace function public.registrar_venda(p jsonb) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_id bigint; v_caixa bigint; v_sub numeric(12,2) := 0; v_total numeric(12,2);
  v_forma text := p->>'forma_pagamento'; it jsonb; v_q numeric; v_pu numeric; v_desc text; v_prod text;
  v_nome text;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  if jsonb_typeof(p->'itens') <> 'array' or jsonb_array_length(p->'itens') = 0 then
    raise exception 'A venda precisa de pelo menos um item';
  end if;
  v_caixa := public.caixa_aberto_id();
  if v_forma <> 'a_prazo' and v_caixa is null then
    raise exception 'Abra o caixa antes de registrar uma venda paga';
  end if;

  v_nome := coalesce(nullif(p->>'cliente_nome',''),
             (select nome from public.clientes where id = (p->>'cliente_id')::bigint), '');

  insert into public.vendas(cliente_id, cliente_nome, caixa_id, canal, desconto, frete, forma_pagamento, status, observacao)
  values ((p->>'cliente_id')::bigint, v_nome,
          case when v_forma = 'a_prazo' then null else v_caixa end,
          coalesce(p->>'canal','balcao'),
          coalesce((p->>'desconto')::numeric,0), coalesce((p->>'frete')::numeric,0),
          v_forma, case when v_forma = 'a_prazo' then 'pendente' else 'paga' end,
          coalesce(p->>'observacao',''))
  returning id into v_id;

  for it in select * from jsonb_array_elements(p->'itens') loop
    v_q := (it->>'quantidade')::numeric; v_pu := (it->>'preco_unit')::numeric;
    v_prod := nullif(it->>'produto_id','');
    v_desc := coalesce(nullif(it->>'descricao',''), (select nome from public.produtos where id = v_prod), 'Item');
    if v_q is null or v_q <= 0 then raise exception 'Quantidade inválida em %', v_desc; end if;
    insert into public.venda_itens(venda_id, produto_id, descricao, quantidade, preco_unit, total)
    values (v_id, v_prod, v_desc, v_q, v_pu, round(v_q*v_pu,2));
    v_sub := v_sub + round(v_q*v_pu,2);
    if v_prod is not null then
      insert into public.movimentos_estoque(produto_id, tipo, quantidade, observacao, venda_id)
      values (v_prod, 'venda', -v_q, 'Venda #'||v_id, v_id);
    end if;
  end loop;

  v_total := v_sub - coalesce((p->>'desconto')::numeric,0) + coalesce((p->>'frete')::numeric,0);
  if v_total < 0 then raise exception 'Desconto maior que o valor da venda'; end if;
  update public.vendas set subtotal = v_sub, total = v_total where id = v_id;

  if v_total > 0 then
    insert into public.lancamentos(tipo, categoria, descricao, valor, vencimento, status, pago_em,
                                   forma_pagamento, caixa_id, cliente_id, venda_id)
    values ('receber', 'Vendas', 'Venda #'||v_id||coalesce(' – '||nullif(v_nome,''),''), v_total,
            coalesce((p->>'vencimento')::date, current_date),
            case when v_forma = 'a_prazo' then 'aberto' else 'pago' end,
            case when v_forma = 'a_prazo' then null else now() end,
            case when v_forma = 'a_prazo' then null else v_forma end,
            case when v_forma = 'a_prazo' then null else v_caixa end,
            (p->>'cliente_id')::bigint, v_id);
  end if;
  return v_id;
end $$;

-- Cancelar venda: devolve estoque e cancela o lançamento (só administrador)
create or replace function public.cancelar_venda(p_id bigint, p_motivo text default '') returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if not public.eh_admin() then raise exception 'Só o administrador pode cancelar vendas'; end if;
  if not exists(select 1 from public.vendas where id = p_id and status <> 'cancelada') then
    raise exception 'Venda não encontrada ou já cancelada';
  end if;
  if exists(select 1 from public.lancamentos l join public.caixas c on c.id = l.caixa_id
             where l.venda_id = p_id and l.status = 'pago' and c.status = 'fechado') then
    raise exception 'O caixa desta venda já foi fechado. Registre a devolução do dinheiro como conta a pagar e faça uma entrada de estoque.';
  end if;
  for r in select produto_id, quantidade from public.venda_itens where venda_id = p_id and produto_id is not null loop
    insert into public.movimentos_estoque(produto_id, tipo, quantidade, observacao, venda_id)
    values (r.produto_id, 'cancelamento', r.quantidade, 'Cancelamento da venda #'||p_id, p_id);
  end loop;
  update public.vendas set status = 'cancelada',
         observacao = trim(observacao||' [Cancelada: '||coalesce(p_motivo,'')||']') where id = p_id;
  update public.lancamentos set status = 'cancelado' where venda_id = p_id;
end $$;

-- Dar baixa (marcar como pago) num lançamento
create or replace function public.baixar_lancamento(p_id bigint, p_forma text) returns void
language plpgsql security definer set search_path = public as $$
declare v_venda bigint;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  if p_forma = 'dinheiro' and public.caixa_aberto_id() is null then
    raise exception 'Para receber ou pagar em dinheiro, abra o caixa';
  end if;
  update public.lancamentos
     set status = 'pago', pago_em = now(), forma_pagamento = p_forma, caixa_id = public.caixa_aberto_id()
   where id = p_id and status = 'aberto'
  returning venda_id into v_venda;
  if not found then raise exception 'Lançamento não encontrado ou já baixado'; end if;
  if v_venda is not null then
    update public.vendas set status = 'paga' where id = v_venda and status = 'pendente';
  end if;
end $$;

-- Resumo do caixa (aberto ou de um id): valores por forma de pagamento
create or replace function public.resumo_caixa(p_id bigint default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_id bigint := coalesce(p_id, public.caixa_aberto_id()); c record; r jsonb; v_din numeric;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  if v_id is null then return null; end if;
  select * into c from public.caixas where id = v_id;
  select coalesce(jsonb_object_agg(forma, jsonb_build_object('entradas', ent, 'saidas', sai)), '{}'::jsonb) into r
  from (select forma_pagamento as forma,
               sum(case when tipo='receber' then valor else 0 end) ent,
               sum(case when tipo='pagar' then valor else 0 end) sai
        from public.lancamentos where caixa_id = v_id and status = 'pago' group by forma_pagamento) t;
  select coalesce(sum(case when tipo='receber' then valor else -valor end),0) into v_din
    from public.lancamentos where caixa_id = v_id and status='pago' and forma_pagamento='dinheiro';
  return jsonb_build_object('id', c.id, 'status', c.status, 'aberto_em', c.aberto_em,
    'valor_abertura', c.valor_abertura, 'por_forma', r,
    'dinheiro_esperado', c.valor_abertura + v_din,
    'qtd_vendas', (select count(*) from public.vendas where caixa_id = v_id and status='paga'),
    'total_vendas', (select coalesce(sum(total),0) from public.vendas where caixa_id = v_id and status='paga'),
    'valor_contado', c.valor_contado, 'fechado_em', c.fechado_em);
end $$;

create or replace function public.abrir_caixa(p_valor numeric) returns bigint
language plpgsql security definer set search_path = public as $$
declare v bigint;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  if public.caixa_aberto_id() is not null then raise exception 'Já existe um caixa aberto'; end if;
  insert into public.caixas(valor_abertura) values (coalesce(p_valor,0)) returning id into v;
  return v;
end $$;

-- Sangria (retirada) ou suprimento (reforço) de dinheiro no caixa
create or replace function public.movimentar_caixa(p_tipo text, p_valor numeric, p_motivo text) returns void
language plpgsql security definer set search_path = public as $$
declare v_caixa bigint := public.caixa_aberto_id();
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  if v_caixa is null then raise exception 'Nenhum caixa aberto'; end if;
  if p_tipo not in ('sangria','suprimento') then raise exception 'Tipo inválido'; end if;
  insert into public.lancamentos(tipo, categoria, descricao, valor, status, pago_em, forma_pagamento, caixa_id)
  values (case when p_tipo='sangria' then 'pagar' else 'receber' end,
          initcap(p_tipo), initcap(p_tipo)||coalesce(': '||nullif(p_motivo,''),''), p_valor,
          'pago', now(), 'dinheiro', v_caixa);
end $$;

create or replace function public.fechar_caixa(p_contado numeric, p_obs text default '') returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_caixa bigint := public.caixa_aberto_id(); res jsonb;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  if v_caixa is null then raise exception 'Nenhum caixa aberto'; end if;
  res := public.resumo_caixa(v_caixa);
  update public.caixas set status='fechado', fechado_em=now(), fechado_por=auth.uid(),
         valor_esperado=(res->>'dinheiro_esperado')::numeric, valor_contado=p_contado, observacao=coalesce(p_obs,'')
   where id = v_caixa;
  return public.resumo_caixa(v_caixa);
end $$;

-- Gerar as mensalidades de um mês para todos os contratos ativos (não duplica)
create or replace function public.gerar_mensalidades(p_mes date) returns int
language plpgsql security definer set search_path = public as $$
declare v_comp date := date_trunc('month', p_mes)::date; n int;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  insert into public.lancamentos(tipo, categoria, descricao, valor, vencimento, competencia, cliente_id, contrato_id)
  select 'receber', 'Mensalidades',
         c.descricao||' – '||cl.nome||' ('||to_char(v_comp,'MM/YYYY')||')',
         c.valor_mensal, v_comp + (c.dia_vencimento - 1), v_comp, c.cliente_id, c.id
    from public.contratos c join public.clientes cl on cl.id = c.cliente_id
   where c.ativo and c.inicio <= (v_comp + interval '1 month' - interval '1 day')::date
     and not exists (select 1 from public.lancamentos l
                      where l.contrato_id = c.id and l.competencia = v_comp and l.status <> 'cancelado');
  get diagnostics n = row_count;
  return n;
end $$;

-- Converter orçamento aprovado em venda
create or replace function public.converter_orcamento(p_id bigint, p_forma text, p_vencimento date default null) returns bigint
language plpgsql security definer set search_path = public as $$
declare o record; v bigint;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  select * into o from public.orcamentos where id = p_id;
  if o.id is null or o.status = 'convertido' then raise exception 'Orçamento não encontrado ou já convertido'; end if;
  v := public.registrar_venda(jsonb_build_object(
        'cliente_id', o.cliente_id, 'cliente_nome', o.cliente_nome, 'canal', 'orcamento',
        'desconto', o.desconto, 'frete', 0, 'forma_pagamento', p_forma, 'vencimento', p_vencimento,
        'observacao', 'Orçamento #'||o.id||' – '||o.titulo,
        'itens', (select jsonb_agg(jsonb_build_object('produto_id', produto_id, 'descricao', descricao,
                    'quantidade', quantidade, 'preco_unit', preco_unit)) from public.orcamento_itens where orcamento_id = p_id)));
  update public.orcamentos set status = 'convertido', venda_id = v where id = p_id;
  return v;
end $$;

-- Recalcular o total do orçamento quando os itens mudam
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

-- ---------- Funções públicas usadas pelo SITE (sem login) ----------

-- Catálogo do site: só o que é público (sem custo, sem quantidade exata)
create or replace function public.produtos_site()
returns table(id text, nome text, categoria text, descricao text, preco numeric, disponivel boolean, icone text)
language sql stable security definer set search_path = public as $$
  select id, nome, categoria, descricao, preco_venda, estoque > 0, icone
    from public.produtos where ativo and no_site order by categoria, nome;
$$;

-- Registrar pedido feito no site. Preços e frete são recalculados aqui, nunca confiamos no navegador.
create or replace function public.registrar_pedido_site(p jsonb) returns bigint
language plpgsql security definer set search_path = public as $$
declare it jsonb; v_itens jsonb := '[]'::jsonb; v_sub numeric(12,2) := 0; v_q int; pr record; v_frete numeric(12,2); v_id bigint;
begin
  if length(coalesce(p->>'nome','')) not between 2 and 120 then raise exception 'Informe seu nome'; end if;
  if jsonb_typeof(p->'itens') <> 'array' or jsonb_array_length(p->'itens') not between 1 and 40 then
    raise exception 'Pedido sem itens';
  end if;
  -- trava simples contra abuso: no máximo 30 pedidos novos por hora no total
  if (select count(*) from public.pedidos_site where criado_em > now() - interval '1 hour') >= 30 then
    raise exception 'Muitos pedidos agora. Tente pelo WhatsApp.';
  end if;
  for it in select * from jsonb_array_elements(p->'itens') loop
    v_q := (it->>'quantidade')::int;
    if v_q is null or v_q < 1 or v_q > 100 then raise exception 'Quantidade inválida'; end if;
    select * into pr from public.produtos where id = it->>'produto_id' and ativo and no_site;
    if pr.id is null then raise exception 'Produto indisponível: %', it->>'produto_id'; end if;
    v_itens := v_itens || jsonb_build_object('produto_id', pr.id, 'descricao', pr.nome, 'quantidade', v_q,
                                             'preco_unit', pr.preco_venda, 'total', round(v_q*pr.preco_venda,2));
    v_sub := v_sub + round(v_q*pr.preco_venda,2);
  end loop;
  v_frete := case when v_sub >= 300 then 0 else 20 end;   -- mesma regra do site
  insert into public.pedidos_site(nome, telefone, cep, forma_pagamento, itens, subtotal, frete, total)
  values (left(p->>'nome',120), left(coalesce(p->>'telefone',''),30), left(coalesce(p->>'cep',''),12),
          left(coalesce(p->>'forma_pagamento','pix'),30), v_itens, v_sub, v_frete, v_sub + v_frete)
  returning id into v_id;
  return v_id;
end $$;

-- Converter pedido do site em venda (baixa o estoque)
create or replace function public.converter_pedido_site(p_id bigint, p_forma text, p_cliente_id bigint default null) returns bigint
language plpgsql security definer set search_path = public as $$
declare ps record; v bigint;
begin
  if not public.eh_equipe() then raise exception 'Acesso negado'; end if;
  select * into ps from public.pedidos_site where id = p_id and status = 'novo';
  if ps.id is null then raise exception 'Pedido não encontrado ou já tratado'; end if;
  v := public.registrar_venda(jsonb_build_object('cliente_id', p_cliente_id, 'cliente_nome', ps.nome,
        'canal','site','desconto',0,'frete',ps.frete,'forma_pagamento',p_forma,
        'observacao','Pedido do site #'||ps.id||' – CEP '||ps.cep||' – '||ps.telefone,
        'itens', ps.itens));
  update public.pedidos_site set status='convertido', venda_id=v where id=p_id;
  return v;
end $$;

-- ---------------------------------------------------------------------
-- 8. SEGURANÇA (RLS): só a equipe ativa acessa os dados
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['produtos','movimentos_estoque','clientes','contratos','caixas','vendas','venda_itens',
                           'lancamentos','orcamentos','orcamento_itens','agenda','pedidos_site','perfis'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end $$;

-- Equipe lê e escreve no dia a dia; apagar é só para o administrador
do $$
declare t text;
begin
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
  -- Tabelas que só mudam pelas funções do sistema: equipe apenas lê
  foreach t in array array['vendas','venda_itens','caixas','pedidos_site'] loop
    execute format('drop policy if exists equipe_le on public.%I', t);
    execute format('create policy equipe_le on public.%I for select to authenticated using (public.eh_equipe())', t);
  end loop;
end $$;

-- Pedidos do site: equipe pode descartar (converter é só pela função)
drop policy if exists equipe_descarta on public.pedidos_site;
create policy equipe_descarta on public.pedidos_site for update to authenticated
  using (public.eh_equipe() and status = 'novo') with check (public.eh_equipe() and status = 'descartado');
revoke insert, update, delete on public.pedidos_site from authenticated;
grant update (status) on public.pedidos_site to authenticated;
revoke insert, update, delete on public.vendas, public.venda_itens, public.caixas from authenticated;

-- Movimentos de estoque: equipe lê e lança entrada/saída/ajuste (vendas só pela função)
drop policy if exists equipe_le on public.movimentos_estoque;
drop policy if exists equipe_lanca on public.movimentos_estoque;
create policy equipe_le on public.movimentos_estoque for select to authenticated using (public.eh_equipe());
create policy equipe_lanca on public.movimentos_estoque for insert to authenticated
  with check (public.eh_equipe() and tipo in ('entrada','saida','ajuste') and venda_id is null);

-- Lançamentos: equipe lê e cria contas a pagar/receber em aberto; administrador corrige ou cancela
drop policy if exists equipe_le on public.lancamentos;
drop policy if exists equipe_cria on public.lancamentos;
drop policy if exists admin_altera on public.lancamentos;
create policy equipe_le on public.lancamentos for select to authenticated using (public.eh_equipe());
create policy equipe_cria on public.lancamentos for insert to authenticated
  with check (public.eh_equipe() and status = 'aberto' and venda_id is null and caixa_id is null);
create policy admin_altera on public.lancamentos for update to authenticated using (public.eh_admin()) with check (public.eh_admin());

-- Perfis: cada um vê o seu; administrador vê e gerencia todos
drop policy if exists ve_proprio on public.perfis;
drop policy if exists admin_gerencia on public.perfis;
create policy ve_proprio on public.perfis for select to authenticated using (id = auth.uid() or public.eh_admin());
create policy admin_gerencia on public.perfis for update to authenticated using (public.eh_admin()) with check (public.eh_admin());

-- Ninguém altera o estoque "na mão": só por movimentos
revoke insert, update on public.produtos from authenticated;
grant insert (id, nome, categoria, descricao, unidade, preco_venda, custo, estoque_minimo, icone, ativo, no_site)
  on public.produtos to authenticated;
grant update (nome, categoria, descricao, unidade, preco_venda, custo, estoque_minimo, icone, ativo, no_site, atualizado_em)
  on public.produtos to authenticated;

-- Quem pode chamar cada função
revoke execute on all functions in schema public from public, anon;
grant execute on function public.produtos_site() to anon, authenticated;
grant execute on function public.registrar_pedido_site(jsonb) to anon, authenticated;
grant execute on function public.eh_equipe(), public.eh_admin(), public.caixa_aberto_id(),
  public.registrar_venda(jsonb), public.cancelar_venda(bigint, text), public.baixar_lancamento(bigint, text),
  public.resumo_caixa(bigint), public.abrir_caixa(numeric), public.movimentar_caixa(text, numeric, text),
  public.fechar_caixa(numeric, text), public.gerar_mensalidades(date),
  public.converter_orcamento(bigint, text, date), public.converter_pedido_site(bigint, text, bigint)
  to authenticated;
