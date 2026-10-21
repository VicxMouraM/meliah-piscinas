# Meliah Piscinas – Site e Sistema de Gestão

**MELIAH PISCINAS COMÉRCIO E SERVIÇOS LTDA – ME** · CNPJ 06.120.369/0001-14
Sede: Av. Orosimbo Maia, 1806 – Cambuí, Campinas/SP · CEP 13024-045

O pacote tem duas partes que conversam entre si:

1. **O site** (`index.html`): catálogo de piscinas, loja com carrinho, checkout completo, acompanhamento de pedido, pedido de orçamento, contato, galeria e políticas.
2. **O sistema de gestão** (`admin/`): área com login para a equipe. Vendas e entregas, pedidos e mensagens do site, estoque, clientes, orçamentos, mensalidades, agenda, financeiro e configurações do site.

A Meliah **não tem caixa físico**: todas as vendas são online (site, WhatsApp, telefone, Instagram) com entrega no endereço do cliente.

## Arquivos do pacote

```
meliah-piscinas/
├── index.html                 ← o site
├── config.exemplo.js          ← modelo do config.js (endereço e chave do Supabase, seção 7.5)
├── comum.js                   ← máscaras, validação de CPF/CNPJ e busca de CEP (site e sistema)
├── admin/
│   └── index.html             ← o sistema de gestão (endereço: seusite/admin/)
├── supabase/
│   ├── schema.sql             ← cria ou ATUALIZA o banco de dados (roda no Supabase)
│   └── produtos-iniciais.sql  ← cadastra os 15 produtos iniciais
├── vendor/
│   └── supabase.js            ← biblioteca de conexão com o Supabase (não mexer)
├── fotos/                     ← fotos reais da galeria
└── README.md                  ← este guia
```

Tudo é estático: GitHub Pages, Netlify ou qualquer hospedagem simples serve. **Sempre envie a pasta completa**: o site e o sistema dependem do `comum.js` e do `config.js`.

> O pacote traz o `config.exemplo.js` em vez do `config.js`, para uma atualização nunca apagar o seu `config.js` já preenchido. Na primeira instalação, copie o exemplo com o nome `config.js` e preencha.

---

## 1. Como o site e o sistema conversam

| No site o cliente… | …e no sistema aparece |
|---|---|
| Vê produtos, preços e o que está **Esgotado** | O que está cadastrado em **Estoque** (preço e quantidade) |
| Vê frete, cidades atendidas, WhatsApp e aviso do topo | O que está em **Configurações** |
| Finaliza um pedido no carrinho | Em **Site → Pedidos**, com nome, WhatsApp, CPF/CNPJ, endereço completo e itens |
| Paga com Pix | A chave Pix das **Configurações** aparece na confirmação do pedido |
| Clica em **Meu pedido** e consulta pelo número + WhatsApp | A situação que a equipe marca em **Vendas e entregas** (confirmado, separando, saiu para entrega, entregue) e se o pagamento foi recebido |
| Clica em "Pedir orçamento" de uma piscina | Em **Site → Orçamentos e contatos**, com botão para criar o orçamento já preenchido |
| Manda uma mensagem pelo formulário de contato | Em **Site → Orçamentos e contatos** |

**Validações em todos os formulários** (no site, no sistema e de novo no banco, para ninguém burlar):
- **WhatsApp/telefone** com máscara `(19) 99999-9999` e conferência de DDD + 10 ou 11 dígitos.
- **CEP** com máscara `00000-000`: ao completar, **o endereço é preenchido sozinho** (rua, bairro, cidade e UF, pelo serviço gratuito ViaCEP). Se o CEP não existir ou o serviço estiver fora, aparece um aviso e o endereço pode ser digitado.
- **CPF/CNPJ** com máscara automática (vira CNPJ a partir do 12º número) e **conferência dos dígitos verificadores**. CPF ou CNPJ inválido é recusado.
- **Cidade atendida:** se o CEP for de uma cidade fora da lista, o site avisa e oferece o WhatsApp.
- **Produto esgotado** não pode ser comprado. Se esgotar enquanto o cliente está no carrinho, o pedido é recusado com aviso.
- **Preço e frete são sempre calculados no servidor.** Ninguém altera o valor pelo navegador.
- **Sem internet:** o site avisa e oferece mandar o pedido pelo WhatsApp. O sistema mostra uma faixa vermelha avisando que nada será salvo até a conexão voltar.
- **Proteção contra excesso de envios:** no máximo 30 pedidos e 60 mensagens por hora vindos do site.

Sem o `config.js` preenchido, o site continua funcionando sozinho: pedidos, orçamentos e contatos vão direto pelo WhatsApp.

---

## 2. Checklist antes de divulgar

- [ ] **Configurações** no sistema: WhatsApp real, chave Pix, frete, cidades atendidas (7.6)
- [ ] **Estoque:** preços, custos e contagem inicial. Sem estoque, o produto aparece como **Esgotado** (7.6)
- [ ] Telefone e e-mail da seção Contato no `index.html` (3.1)
- [ ] E-mail do encarregado de dados na Política de Privacidade (3.6)
- [ ] Quantidades do kit da calculadora conforme o rótulo dos produtos (3.2)
- [ ] Modelos, medidas e preços das piscinas (3.3)
- [ ] Fotos reais na galeria (3.4)
- [ ] Respostas das Dúvidas frequentes (3.5)
- [ ] Revisão das políticas por um advogado ou contador (3.6)
- [ ] Telefone e domínio no bloco de dados para o Google (5)

---

## 3. O que se altera direto no `index.html`

A maior parte agora é feita **pelo sistema** (seção 6): produtos, preços, estoque, frete, cidades, WhatsApp, Pix e aviso do topo. No arquivo ficam só os textos fixos. Use um editor de texto (o VS Code é gratuito) ou o lápis do GitHub, e **Ctrl+F** para achar os trechos.

### 3.1 Telefone e e-mail exibidos na seção Contato
Procure `contato@meliahpiscinas.com.br` e troque pelo e-mail real. Apague o `<span class="example">exemplo</span>` ao lado. O número de WhatsApp exibido é trocado sozinho pelo das **Configurações**.

### 3.2 Kit da calculadora e bombas
Procure `const KIT_RULES=[`:

```js
{ate:15000, itens:{clg25:1, alg:1, clar:1, phm:1, kit:1}},
```

`ate` é o volume máximo da faixa, em litros. `itens` é `código do produto: quantidade`. As quantidades atuais são **estimativas**: ajuste pela dose do rótulo. Produtos esgotados saem do kit sozinhos. `const PUMP_RULES=[` define qual bomba atende até quantos litros.

### 3.3 Piscinas
Procure `const pools=[`. Cada piscina tem nome (`n`), formato do desenho (`shape`: `rect`, `beach` ou `free`), características (`d`) e o texto de preço (`from`). O nome vai junto no pedido de orçamento.

### 3.4 Fotos da galeria
Procure `const GALERIA=[`. Coloque a foto em `fotos/` (nome sem espaço nem acento) e preencha `foto:"fotos/nome.jpg"`. A etiqueta "foto de exemplo" some sozinha. Use fotos horizontais de até 300 KB (o site squoosh.app reduz), só de obras da Meliah e com autorização do cliente.

### 3.5 Dúvidas frequentes
Procure `<section id="duvidas"`. Cada pergunta é `<details><summary>Pergunta</summary><p>Resposta</p></details>`. As respostas atuais são modelos.

### 3.6 Políticas
Procure `<section id="privacidade"` e `<section id="trocas"`. Troque o e-mail do encarregado e atualize a data de "Última atualização". Os pedidos do site guardam nome, WhatsApp, CPF/CNPJ (opcional) e endereço no Supabase, e a política já cobre isso. Peça a revisão de um advogado antes de divulgar.

### 3.7 Cores
No topo do `index.html`, em `:root{`: `--tile` (azul escuro), `--water` (azul água), `--buoy` (laranja).

---

## 4. Colocar no ar e atualizar

**Primeira vez:** suba **todo o conteúdo** da pasta na raiz do repositório do GitHub e ative **Settings → Pages → main / (root)**. O sistema fica em `seusite/admin/`.

**Atualizar (como agora):**
1. No Supabase, rode o `supabase/schema.sql` novo (**SQL Editor → New query → colar → Run**). Ele atualiza o banco **sem apagar dados**.
2. No GitHub, envie os arquivos novos por cima dos antigos (**Add file → Upload files**): `index.html`, `comum.js`, `admin/index.html` e `README.md`. O seu `config.js` continua como está (o pacote não traz um `config.js` para não sobrescrever o seu).
3. Abra o site e o sistema e aperte **Ctrl+F5** para o navegador pegar a versão nova.

**Domínio próprio:** registre `meliahpiscinas.com.br` no registro.br e configure em **Settings → Pages → Custom domain**.

---

## 5. Informações para o Google (já incluídas)

O topo do `index.html` tem a descrição para a busca, o cartão de compartilhamento (WhatsApp e Facebook) e a ficha da empresa (`application/ld+json`) com nome, CNPJ, endereço, cidades atendidas e horário. Falta trocar `telephone` (`+55-19-XXXXX-XXXX`) e `url` (o domínio). Esses dados precisam ser **idênticos** aos do Perfil da Empresa no Google. A área `admin/` não aparece no Google.

---

## 6. O sistema de gestão: telas

| Tela | Para que serve |
|---|---|
| **Painel** | Vendas e recebimentos do dia, vendas aguardando pagamento, entregas em aberto, novidades do site, contas vencidas e da semana, estoque baixo e agenda de hoje. Os cartões levam direto à tela certa. |
| **Nova venda** | Vendas fechadas por WhatsApp, telefone ou Instagram. Clique nos produtos, inclua serviço avulso, escolha o cliente (o endereço de entrega é preenchido) ou cadastre na hora. Marque se o pagamento já foi recebido; se não, informe o vencimento. Desconto e frete. O estoque baixa sozinho. |
| **Vendas e entregas** | Todas as vendas com filtro por período, pagamento e entregas em aberto. Mude a situação da entrega (a separar → separando → saiu para entrega → entregue) e o cliente vê no site. Botões **Recebido**, **WhatsApp** (mensagem pronta com a situação e a chave Pix), **Detalhes** (itens e endereço com link para o mapa) e **Cancelar** (administrador). |
| **Site** | **Pedidos**: confirme (vira venda, baixa o estoque e cadastra o cliente sozinho se ele for novo) ou descarte. **Orçamentos e contatos**: responda pelo WhatsApp, crie o orçamento já preenchido ou descarte. O número de novidades aparece no menu. |
| **Estoque** | Preço, custo, margem, quantidade e mínimo. **Movimentar**: entrada (atualiza o custo), saída (não deixa sair mais do que existe) ou contagem. **Histórico** de cada produto. |
| **Clientes** | Cadastro com máscaras, CPF/CNPJ conferido e endereço pelo CEP. Busca por nome, telefone, documento ou bairro. Histórico de compras e contas em aberto. |
| **Orçamentos** | Produtos e serviços, desconto, validade e condições. **Enviar** abre o WhatsApp com o orçamento formatado. **Virar venda** quando o cliente aprova. |
| **Mensalidades** | Contratos de manutenção. **Gerar cobranças do mês** sem duplicar e **Cobrar** pelo WhatsApp, com a chave Pix na mensagem. |
| **Agenda** | Visitas da semana, com link do endereço no mapa e botão **Avisar** o cliente. |
| **Financeiro** | A receber, a pagar, vencidos e **Recebimentos**: quanto entrou por forma de pagamento (Pix, cartão, boleto…) no dia, na semana ou no mês, para conferir com o extrato do banco e da maquininha. Resultado do mês. |
| **Configurações** (administrador) | WhatsApp da loja, chave Pix, valor do frete, frete grátis a partir de, cidades atendidas, pausar pedidos do site e aviso no topo do site. Vale na hora. |
| **Equipe** (administrador) | Libera, bloqueia e define quem é administrador. |

**Regras de segurança no banco:**
- Só usuários **ativados** pelo administrador veem dados.
- Toda mudança de estoque fica registrada.
- Só o **administrador** cancela vendas, cancela contas e altera as configurações do site.
- Cancelar uma venda **já paga** devolve o estoque e cria uma conta a pagar "Devolver ao cliente", para ninguém esquecer o reembolso.

**O que o sistema não faz:** emitir **nota fiscal** (continue com o emissor atual ou o contador) e cobrar cartão automaticamente. Para cartão, use o link de pagamento do seu banco ou maquininha e marque **Recebido** quando cair.

---

## 7. Ligar o sistema (primeira vez)

### 7.1 Criar o projeto
Em **supabase.com**, crie a organização e o projeto (Data API ligado; "Automatically expose new tables" pode ficar desligado). Guarde a senha do banco.

### 7.2 Criar o banco
**SQL Editor → New query**: cole o `supabase/schema.sql` inteiro e clique em **Run**. Depois faça o mesmo com o `supabase/produtos-iniciais.sql`.

### 7.3 Fechar o cadastro público
**Authentication → Sign In / Providers**: desligue **"Allow new users to sign up"**.

### 7.4 Usuários
**Authentication → Users → Add user → Create new user**, com e-mail, senha e **Auto Confirm User** marcado. O primeiro usuário vira administrador. Os próximos você ativa na tela **Equipe**.

Se o administrador aparecer como "não liberado" (acontece quando o usuário é criado antes do schema), rode no SQL Editor:

```sql
insert into public.perfis (id, nome, email, papel, ativo)
select id, split_part(email,'@',1), email, 'admin', true from auth.users where email = 'SEU-EMAIL'
on conflict (id) do update set papel = 'admin', ativo = true;
```

### 7.5 `config.js`
Copie o `config.exemplo.js` com o nome `config.js`. Em **Settings → API Keys** (ou no botão **Connect**), copie a **Project URL** e a chave **publishable** (`sb_publishable_...`) para ele. **Nunca** use a chave `secret`.

### 7.6 Primeiro uso
1. **Configurações:** WhatsApp, chave Pix, frete e cidades.
2. **Estoque:** confira preços e custos e lance a contagem inicial (**Movimentar → Contagem**).
3. **Clientes** e **Mensalidades:** cadastre os clientes de manutenção e os contratos.
4. Faça um **pedido de teste** no site e confirme em **Site → Pedidos**. Depois cancele a venda de teste em **Vendas e entregas**.

### 7.7 Backup
No plano gratuito, exporte semanalmente as tabelas principais (`vendas`, `lancamentos`, `clientes`, `produtos`, `pedidos_site`) em **Table Editor → Export to CSV** e guarde no Google Drive.

---

## 8. Próximas etapas

- [ ] Perfil da Empresa no Google (Maps e Busca)
- [ ] Instagram da loja, com link no site
- [ ] Depoimentos de clientes reais (nunca inventados)
- [ ] Nota fiscal e cobrança automática por cartão (ERP ou plataforma de pagamento), quando fizer sentido
