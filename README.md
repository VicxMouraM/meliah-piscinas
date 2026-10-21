# Meliah Piscinas – Site e Sistema de Gestão

**MELIAH PISCINAS COMÉRCIO E SERVIÇOS LTDA – ME** · CNPJ 06.120.369/0001-14
Sede: Av. Orosimbo Maia, 1806 – Cambuí, Campinas/SP · CEP 13024-045

O pacote tem duas partes:

1. **O site** (`index.html`): o que o cliente vê. Catálogo de piscinas, loja com carrinho, calculadora, galeria, dúvidas e políticas.
2. **O sistema de gestão** (`admin/`): área com login para a equipe. Estoque, vendas (PDV), caixa, financeiro, clientes, mensalidades, orçamentos, agenda e os pedidos que chegam pelo site.

O site funciona sozinho desde já. O sistema precisa de uma conta gratuita no **Supabase** (banco de dados com login), configurada uma única vez (seção 7).

## Arquivos do pacote

```
meliah-piscinas/
├── index.html                 ← o site
├── config.js                  ← ligação com o Supabase e número do WhatsApp (seção 7)
├── admin/
│   └── index.html             ← o sistema de gestão (endereço: seusite/admin/)
├── supabase/
│   ├── schema.sql             ← cria o banco de dados (roda 1 vez no Supabase)
│   └── produtos-iniciais.sql  ← cadastra os 15 produtos do site no sistema
├── vendor/
│   └── supabase.js            ← biblioteca de conexão com o Supabase (não mexer)
├── fotos/                     ← fotos reais da galeria
└── README.md                  ← este guia
```

Tudo é estático: GitHub Pages, Netlify ou qualquer hospedagem simples serve. Não há servidor para manter.

---

## 1. O que o site tem

| Seção | Endereço | O que faz |
|---|---|---|
| Início + calculadora | `#inicio` | Calcula os litros da piscina, sugere o kit de 1 mês e a bomba certa, com botão para adicionar ao carrinho |
| Piscinas | `#piscinas` | 3 modelos com medidas e botão "Pedir orçamento" pelo WhatsApp |
| Galeria de obras | `#galeria` | 6 obras (hoje com ilustrações de exemplo) |
| Loja | `#loja` | Produtos com filtro por categoria, busca e carrinho |
| Serviços | `#servicos` | Instalação, manutenção mensal e tratamento de água verde |
| Dúvidas | `#duvidas` | Perguntas frequentes |
| Contato | `#contato` | WhatsApp, área atendida, sede, horário e e-mail |
| Política de Privacidade | `#privacidade` | Página própria (LGPD) |
| Trocas e Devoluções | `#trocas` | Página própria (Código de Defesa do Consumidor) |

**Como funciona uma compra:** o cliente monta o carrinho, informa nome, WhatsApp, CEP e forma de pagamento e clica em "Enviar pedido pelo WhatsApp". O WhatsApp abre com a lista de produtos e o total já escritos.

**Com o sistema ligado (seção 7)**, o site também:
- mostra os **preços e produtos cadastrados no sistema**, com a etiqueta **Esgotado** para o que está com estoque zero;
- **registra cada pedido** na tela "Pedidos do site" do sistema. A mensagem do WhatsApp sai com o número do pedido ("pedido nº 12").

Sem o sistema ligado, o site usa a lista de produtos escrita no próprio `index.html` (seção 3.3).

---

## 2. Checklist antes de colocar no ar

Itens marcados com a etiqueta laranja **EXEMPLO** no site precisam ser trocados.

- [ ] Número do WhatsApp no `config.js` (3.1)
- [ ] Telefone e e-mail da seção Contato (3.2)
- [ ] E-mail do encarregado de dados na Política de Privacidade (3.8)
- [ ] Preços e produtos reais: no sistema (7.5) ou no `index.html` (3.3)
- [ ] Quantidades do kit conforme o rótulo dos produtos vendidos (3.4)
- [ ] Capacidade real das bombas vendidas (3.4)
- [ ] Modelos, medidas e preços das piscinas (3.5)
- [ ] Fotos reais na galeria (3.6)
- [ ] Respostas das Dúvidas frequentes: prazos, cidades atendidas, garantia (3.7)
- [ ] Regra de frete (3.3)
- [ ] Revisão das políticas por um advogado ou contador (3.8)
- [ ] Telefone e domínio no bloco de dados para o Google (5)
- [ ] Estoque inicial lançado no sistema. Sem isso, o site mostra tudo como **Esgotado** (7.5)

---

## 3. Como alterar o site

Abra o arquivo em um editor de texto. O **VS Code** é gratuito e recomendado. No GitHub, dá para editar direto pelo navegador, clicando no lápis. Use **Ctrl+F** para achar os trechos abaixo.

### 3.1 Número do WhatsApp

No arquivo `config.js`:

```js
whatsapp: "5519900000000"
```

Use o formato **55 + DDD + número**, só dígitos. Exemplo: `"5519987654321"`. Isso atualiza todos os botões de WhatsApp do site de uma vez.

### 3.2 Dados de contato

No `index.html`, troque `(19) 90000-0000` e `contato@meliahpiscinas.com.br` pelos dados reais e apague o `<span class="example">exemplo</span>` ao lado de cada um. A lista de cidades atendidas está na pergunta "Vocês entregam em quais cidades?" (3.7).

### 3.3 Produtos da loja (quando o sistema NÃO está ligado)

Com o sistema ligado, os produtos vêm dele (seção 7.5) e esta lista é ignorada. Sem o sistema, procure `let products=[` no `index.html`. Cada linha é um produto:

```js
{id:"clg10", n:"Cloro granulado estabilizado 10 kg", cat:"Tratamento", m:"Uso diário e choque", p:289.9, i:"balde"},
```

| Campo | Significado |
|---|---|
| `id` | Código único, sem espaços. É o mesmo código usado no sistema. |
| `n` | Nome que aparece no site |
| `cat` | Categoria. O filtro do site é montado a partir dela. |
| `m` | Linha curta abaixo do nome |
| `p` | Preço, com **ponto** para os centavos: `289.9` = R$ 289,90 |
| `i` | Ícone: `balde`, `frasco`, `pastilha`, `kit`, `equip` ou `rede` |

**Frete:** a regra é grátis acima de R$ 300, senão R$ 20. Ela aparece em **dois lugares**, e os dois precisam ser iguais:
- no `index.html`, procure `sub>=300?0:20` e o texto "Frete grátis acima de R$ 300";
- no `supabase/schema.sql`, procure `v_sub >= 300 then 0 else 20` (depois de mudar, rode o schema de novo no Supabase).

### 3.4 Kit da calculadora e bombas

Procure `const KIT_RULES=[`:

```js
{ate:15000, itens:{clg25:1, alg:1, clar:1, phm:1, kit:1}},
{ate:35000, itens:{clg10:1, alg:2, clar:1, phm:1, kit:1}},
```

- `ate` = volume máximo da faixa, em litros.
- `itens` = `código do produto: quantidade`.

As quantidades atuais são **estimativas**. Calcule o consumo de 1 mês de cada faixa pela dose do rótulo dos produtos que vocês vendem. Produtos esgotados saem do kit automaticamente.

Procure `const PUMP_RULES=[` para ajustar qual bomba atende até quantos litros.

### 3.5 Piscinas

Procure `const pools=[`. Cada piscina tem nome (`n`), formato do desenho (`shape`: `rect`, `beach` ou `free`), características (`d`) e o texto de preço (`from`).

### 3.6 Fotos da galeria

Procure `const GALERIA=[`:

```js
{titulo:"Fibra 8 × 4 m com prainha", local:"Barão Geraldo – Campinas/SP", foto:"", forma:"beach", deck:"#D6CBB5", grama:"#7FA65A"},
```

Enquanto `foto` estiver vazio (`""`), aparece uma ilustração com a etiqueta "foto de exemplo". Para usar uma foto real:

1. Coloque a foto na pasta `fotos`, por exemplo `fotos/obra-barao-geraldo.jpg` (sem espaço, sem acento, em minúsculas).
2. Preencha `foto:"fotos/obra-barao-geraldo.jpg"`.

A etiqueta de exemplo some sozinha.

**Dicas para as fotos:**
- Formato horizontal. A primeira foto da lista aparece maior.
- Até 1600 px de largura e 300 KB por foto. O site squoosh.app reduz o tamanho.
- Peça autorização do cliente antes de publicar a foto da casa dele. Não mostre número da casa nem pessoas sem autorização.
- Use apenas obras feitas pela Meliah.

### 3.7 Dúvidas frequentes

Procure `<section id="duvidas"`. Cada pergunta é um bloco `<details><summary>Pergunta</summary><p>Resposta</p></details>`. As respostas atuais são **modelos**: confirme prazos, cidades, garantia e parcelamento.

### 3.8 Políticas (Privacidade e Trocas)

Procure `<section id="privacidade"` e `<section id="trocas"`. Ao alterar, atualize a data de "Última atualização".

- **Privacidade (LGPD):** troque o e-mail do encarregado (`privacidade@meliahpiscinas.com.br`). Com o sistema ligado, os pedidos do site (nome, WhatsApp e CEP) ficam guardados no Supabase. A política já cobre isso, mas se a loja passar a usar newsletter, Google Analytics ou Meta Pixel, ela precisa citar.
- **Trocas (CDC):** segue os prazos legais: 7 dias de arrependimento (art. 49) e 30 ou 90 dias para defeitos (art. 26). O reembolso (10 dias úteis) e as regras de obras precisam bater com o contrato de vocês.

> Os textos são um ponto de partida bem fundamentado, mas não substituem a revisão de um advogado.

### 3.9 Cores

No topo do `index.html`, em `:root{`, ficam as cores: `--tile` (azul escuro), `--water` (azul água) e `--buoy` (laranja dos botões principais). O bloco seguinte define o modo escuro.

---

## 4. Como colocar o site no ar

1. **Registrar o domínio** em **registro.br** (por exemplo, `meliahpiscinas.com.br`), com o CNPJ.
2. **Hospedar** no GitHub Pages, Netlify ou Vercel (planos gratuitos atendem). Envie **todo o conteúdo** da pasta, mantendo as pastas `admin`, `supabase`, `vendor` e `fotos`.
   - **GitHub Pages:** suba os arquivos na raiz do repositório e vá em **Settings → Pages → Branch: main / (root) → Save**. No plano gratuito, o repositório precisa ser público. Isso é seguro: o `config.js` só tem a chave pública, e os dados ficam protegidos pelas regras do banco (seção 7.7).
3. **Ligar o domínio** em **Settings → Pages → Custom domain** (ou na tela equivalente da hospedagem).
4. **Cadastrar no Google:** Perfil da Empresa no Google e Google Search Console.

Depois disso, o sistema fica em **seudominio.com.br/admin/**.

---

## 5. Informações para o Google (já incluídas)

O topo do `index.html` já tem:

- **`<meta name="description">`**: o texto que aparece nos resultados de busca.
- **`og:title` e `og:description`**: o cartão que aparece quando alguém compartilha o link no WhatsApp ou no Facebook.
- **Bloco `application/ld+json`**: ficha da empresa (nome, razão social, CNPJ, endereço, cidades atendidas e horário).

Falta trocar `telephone` (formato `+55-19-XXXXX-XXXX`) e `url` (o domínio). **Esses dados precisam ser idênticos aos do Perfil da Empresa no Google.**

A área `admin/` tem uma marcação para **não aparecer** no Google.

---

## 6. O sistema de gestão: o que cada tela faz

| Tela | Para que serve |
|---|---|
| **Painel** | Vendas do dia, situação do caixa, contas vencidas, contas a pagar na semana, pedidos do site, estoque baixo e agenda de hoje |
| **Vender (PDV)** | Monta a venda clicando nos produtos, aceita serviço avulso, desconto e frete. Pagamento em Pix, dinheiro, cartão ou **a prazo** (gera conta a receber). O estoque baixa sozinho. Administrador pode cancelar uma venda, e o estoque volta. |
| **Pedidos do site** | Pedidos feitos no carrinho do site. Botão de WhatsApp para falar com o cliente, **Virar venda** (baixa o estoque) ou **Descartar**. |
| **Estoque** | Produtos com preço, custo, quantidade e mínimo. **Movimentar**: entrada (compra, atualiza o custo), saída (perda ou uso) ou contagem (corrige para o valor real). **Histórico** mostra cada mudança, com data e motivo. Valor total do estoque pelo custo. |
| **Clientes** | Cadastro com endereço e volume da piscina, histórico de compras e contas em aberto, botão de WhatsApp. |
| **Mensalidades** | Contratos de manutenção (valor, dia de vencimento, frequência das visitas). **Gerar cobranças do mês** cria as contas de todos os contratos ativos sem duplicar. Botão **Cobrar** manda o lembrete pelo WhatsApp. |
| **Orçamentos** | Monta orçamento com produtos e serviços, desconto, validade e condições. **Enviar** abre o WhatsApp com o orçamento formatado. **Virar venda** quando o cliente aprova. |
| **Agenda** | Visitas da semana: manutenção, instalação, tratamento, visita técnica e entrega. Botão **Avisar** confirma com o cliente pelo WhatsApp. |
| **Caixa** | Abertura com o troco, sangria (retirada) e suprimento (reforço), resumo por forma de pagamento e **fechamento**: você informa o dinheiro contado e o sistema mostra a diferença. Histórico de fechamentos. |
| **Financeiro** | Contas a receber e a pagar, vencidas e pagas no mês. Lança despesas (fornecedor, aluguel, salários, impostos, combustível), dá baixa e mostra o **resultado do mês**. |
| **Equipe** | Só para o administrador: libera ou bloqueia o acesso e define quem é administrador. |

**Regras de segurança já embutidas no banco** (valem mesmo que alguém tente burlar o painel):
- Só usuários **ativados** pelo administrador veem qualquer dado.
- Ninguém altera a quantidade em estoque diretamente: toda mudança vira um movimento registrado.
- Venda paga só com **caixa aberto**. Venda a prazo exige cliente cadastrado.
- Só o **administrador** cancela vendas, corrige contas e apaga registros.
- Venda de um caixa já fechado não pode ser cancelada, para não alterar um fechamento conferido. Nesse caso, lance a devolução como conta a pagar e faça uma entrada no estoque.
- O site só consegue **ler o catálogo** (sem custo nem quantidade exata) e **registrar pedidos**. O preço do pedido é recalculado no servidor, então ninguém consegue mudar o valor pelo navegador.

**O que o sistema não faz:** emitir **nota fiscal** (NF-e ou NFS-e). Continue emitindo pelo emissor que vocês usam hoje (Sebrae, prefeitura ou o contador). Quando quiserem emitir a nota pelo próprio sistema, o caminho é um ERP com emissor integrado, como Bling ou Olist.

---

## 7. Como ligar o sistema (uma vez só, cerca de 20 minutos)

### 7.1 Criar o projeto no Supabase

1. Acesse **supabase.com** e crie uma conta (pode entrar com o GitHub). Use um e-mail da empresa.
2. Clique em **New project**:
   - **Name:** `meliah`
   - **Database password:** crie uma senha forte e **guarde**.
   - **Region:** **South America (São Paulo)**, que é a mais rápida para Campinas.
3. Espere uns 2 minutos até o projeto ficar pronto.

O plano gratuito atende bem uma empresa deste porte. Ele pausa o projeto depois de um período sem nenhum acesso, mas basta entrar no painel do Supabase e reativar. Com uso diário, isso não acontece.

### 7.2 Criar o banco de dados

1. No menu do projeto, abra **SQL Editor** e clique em **New query**.
2. Abra o arquivo `supabase/schema.sql` no computador, copie **todo** o conteúdo, cole e clique em **Run**. Deve aparecer "Success".
3. Clique em **New query** de novo, cole o conteúdo de `supabase/produtos-iniciais.sql` e clique em **Run**.

O schema pode ser rodado de novo sem perder dados. Isso é útil quando houver atualização.

### 7.3 Fechar o cadastro público (importante)

O sistema não tem tela de "criar conta": só o administrador cria usuários. Para ninguém se cadastrar por fora:

- Vá em **Authentication → Sign In / Providers** (o nome pode variar um pouco) e **desative "Allow new users to sign up"**.

Mesmo que alguém consiga criar uma conta, ela nasce **inativa** e não vê nenhum dado até o administrador ativar.

### 7.4 Criar os usuários

1. Vá em **Authentication → Users → Add user → Create new user**.
2. Informe e-mail e senha e marque **Auto Confirm User**.
3. **O primeiro usuário criado vira o administrador** e já entra ativo. Crie primeiro o seu.
4. Os próximos (funcionários) nascem inativos. O administrador ativa cada um na tela **Equipe** do sistema.

Para trocar a senha de alguém: **Authentication → Users → (usuário) → Reset password** ou defina uma nova.

### 7.5 Ligar o site e o sistema ao Supabase

1. No Supabase, vá em **Settings → API Keys** (ou clique no botão **Connect** no topo do projeto).
2. Copie a **Project URL** (`https://xxxx.supabase.co`) e a chave **publishable** (`sb_publishable_...`). Se o projeto mostrar só a chave antiga **anon** (começa com `eyJ`), use essa.
3. Abra o `config.js` e preencha:

```js
window.MELIAH_CONFIG = {
  supabaseUrl: "https://xxxx.supabase.co",
  supabaseAnonKey: "sb_publishable_xxxxxxxx",
  whatsapp: "5519987654321"
};
```

4. Suba o `config.js` atualizado para a hospedagem.

> **Nunca** coloque no `config.js` a chave **secret** (`sb_secret_...`) nem a **service_role**. Elas dão acesso total ao banco e não podem ficar em site nenhum.

### 7.6 Primeiro uso

1. Acesse **seusite/admin/** e entre com o usuário administrador.
2. **Estoque:** confira preços e custos de cada produto (botão **Editar**) e lance a contagem inicial (**Movimentar → Contagem**). Produto com estoque zero aparece como **Esgotado** no site.
3. **Clientes** e **Mensalidades:** cadastre os clientes de manutenção e os contratos.
4. **Caixa:** abra o caixa com o troco do dia antes de vender.
5. No fim do dia, **Caixa → Fechar caixa** com o dinheiro contado.

### 7.7 Backup e segurança

- **Backup:** no plano gratuito, exporte toda semana as tabelas principais (vendas, lancamentos, clientes, produtos) em **Table Editor → (tabela) → Export to CSV** e guarde no Google Drive. Os planos pagos do Supabase fazem backup automático diário.
- **Senhas:** cada pessoa da equipe tem o próprio usuário. Não compartilhe a senha do administrador.
- **Quando alguém sair da empresa:** na tela **Equipe**, clique em **Bloquear**.
- **Repositório público no GitHub:** não tem problema. Nenhum dado de cliente fica nos arquivos: tudo fica no Supabase, protegido por login e pelas regras do banco.

---

## 8. Próximas etapas do projeto

- [ ] Perfil da Empresa no Google (Maps e Busca)
- [ ] Instagram da loja, com link no site
- [ ] Depoimentos de clientes reais (nunca inventados)
- [ ] Nota fiscal integrada (ERP), quando fizer sentido
