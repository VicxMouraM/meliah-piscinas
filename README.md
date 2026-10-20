# Site Meliah Piscinas

Site da **MELIAH PISCINAS COMÉRCIO E SERVIÇOS LTDA – ME** (CNPJ 06.120.369/0001-14).

## Arquivos do pacote

```
meliah-piscinas/
├── index.html   ← o site inteiro (página, estilos e funções)
├── fotos/       ← coloque aqui as fotos reais da galeria
└── README.md    ← este guia
```

O site é um único arquivo, `index.html`. Não precisa de banco de dados nem de servidor especial. Qualquer hospedagem de site estático serve. Para ver no computador, basta dar dois cliques no `index.html`.

---

## 1. O que o site tem

| Seção | Endereço | O que faz |
|---|---|---|
| Início + calculadora | `#inicio` | Calcula os litros da piscina, sugere o kit de 1 mês e a bomba certa, com botão para adicionar ao carrinho |
| Piscinas | `#piscinas` | 3 modelos com medidas e botão "Pedir orçamento" pelo WhatsApp |
| Galeria de obras | `#galeria` | 6 obras (hoje com ilustrações de exemplo) |
| Loja | `#loja` | 15 produtos, filtro por categoria, busca e carrinho |
| Serviços | `#servicos` | Instalação, manutenção mensal e tratamento de água verde |
| Dúvidas | `#duvidas` | Perguntas frequentes |
| Contato | `#contato` | WhatsApp, endereço, horário e e-mail |
| Política de Privacidade | `#privacidade` | Página própria (LGPD) |
| Trocas e Devoluções | `#trocas` | Página própria (Código de Defesa do Consumidor) |

**Como funciona uma compra:** o cliente monta o carrinho, informa nome, CEP e forma de pagamento e clica em "Enviar pedido pelo WhatsApp". O WhatsApp abre com a lista de produtos, os valores e o total já escritos. A loja confirma a entrega e recebe o pagamento (Pix, cartão ou dinheiro).

O carrinho fica salvo só no navegador do cliente. O site não guarda dados de ninguém.

---

## 2. Checklist antes de colocar no ar

Itens marcados com a etiqueta laranja **EXEMPLO** no site precisam ser trocados.

- [ ] Número do WhatsApp (seção 3.1)
- [ ] Telefone, endereço e e-mail da seção Contato (3.2)
- [ ] E-mail do encarregado de dados na Política de Privacidade (3.8)
- [ ] Preços e produtos reais (3.3)
- [ ] Quantidades do kit conforme o rótulo dos produtos vendidos (3.4)
- [ ] Capacidade real das bombas vendidas (3.4)
- [ ] Modelos, medidas e preços das piscinas (3.5)
- [ ] Fotos reais na galeria (3.6)
- [ ] Respostas das Dúvidas frequentes: prazos, cidades atendidas, garantia (3.7)
- [ ] Regra de frete (3.3)
- [ ] Revisão das políticas por um advogado ou contador (3.8)
- [ ] Telefone, endereço e domínio no bloco de dados para o Google (5)

---

## 3. Como alterar cada parte

Abra `index.html` em um editor de texto. O **VS Code** é gratuito e recomendado. Use **Ctrl+F** para achar os trechos abaixo.

### 3.1 Número do WhatsApp

Procure:

```js
const WA = "5511900000000";
```

Troque pelo número real no formato **55 + DDD + número**, só dígitos. Exemplo: `"5511987654321"`. Isso atualiza de uma vez todos os botões de WhatsApp do site.

### 3.2 Dados de contato

Procure `(11) 90000-0000`, `Rua Exemplo, 123` e `contato@meliahpiscinas.com.br`. Troque pelos dados reais e apague o `<span class="example">exemplo</span>` logo ao lado de cada um.

### 3.3 Produtos da loja

Procure `const products=[`. Cada linha é um produto:

```js
{id:"clg10", n:"Cloro granulado estabilizado 10 kg", cat:"Tratamento", m:"Uso diário e choque", p:289.9, i:"balde"},
```

| Campo | Significado |
|---|---|
| `id` | Código único, sem espaços. Pode ser o código do estoque. |
| `n` | Nome que aparece no site |
| `cat` | Categoria. As categorias do filtro são criadas automaticamente a partir deste campo. |
| `m` | Linha curta abaixo do nome |
| `p` | Preço, com **ponto** para os centavos: `289.9` = R$ 289,90 |
| `i` | Ícone: `balde`, `frasco`, `pastilha`, `kit`, `equip` ou `rede` |

Para incluir um produto, copie uma linha, cole embaixo e altere. Para remover, apague a linha. Atenção: se o `id` estiver sendo usado no kit (3.4), ajuste o kit também.

**Frete:** procure `sub>=300?0:20`. O `300` é o valor mínimo para frete grátis e o `20` é o valor do frete. Atualize também o texto "Frete grátis acima de R$ 300" no carrinho.

### 3.4 Kit da calculadora e bombas

Procure `const KIT_RULES=[`:

```js
{ate:15000, itens:{clg25:1, alg:1, clar:1, phm:1, kit:1}},
{ate:35000, itens:{clg10:1, alg:2, clar:1, phm:1, kit:1}},
```

- `ate` = volume máximo da faixa, em litros.
- `itens` = `id do produto: quantidade`.

As quantidades atuais são **estimativas**. Calcule o consumo de 1 mês para cada faixa usando a dose do rótulo dos produtos que vocês vendem.

Procure `const PUMP_RULES=[` para ajustar qual bomba atende até quantos litros. Acima da última faixa, o site manda o cliente consultar a loja pelo WhatsApp.

### 3.5 Piscinas

Procure `const pools=[`. Cada piscina tem nome (`n`), formato do desenho (`shape`: `rect`, `beach` ou `free`), uma lista de características (`d`) e o texto de preço (`from`).

### 3.6 Fotos da galeria

Procure `const GALERIA=[`:

```js
{titulo:"Fibra 8 × 4 m com prainha", local:"Alphaville – Barueri/SP", foto:"", forma:"beach", deck:"#D6CBB5", grama:"#7FA65A"},
```

Enquanto `foto` estiver vazio (`""`), aparece uma ilustração com a etiqueta "foto de exemplo". Para usar uma foto real:

1. Coloque a foto na pasta `fotos`, por exemplo `fotos/obra-alphaville.jpg`.
2. Use nomes sem espaço, sem acento e em minúsculas.
3. Preencha `foto:"fotos/obra-alphaville.jpg"`.

A etiqueta de exemplo some sozinha. Os campos `forma`, `deck` e `grama` só são usados pela ilustração e podem ficar como estão.

**Dicas para as fotos:**
- Formato horizontal (paisagem). A primeira foto da lista aparece em destaque, maior.
- Largura de até 1600 px e no máximo 300 KB por foto. Use o site squoosh.app para reduzir, porque fotos pesadas deixam o site lento no celular.
- Peça autorização do cliente antes de publicar a foto da casa dele. Não mostre o número da casa nem pessoas sem autorização.
- Use apenas obras feitas pela Meliah.

### 3.7 Dúvidas frequentes

Procure `<section id="duvidas"`. Cada pergunta é um bloco:

```html
<details><summary>Pergunta</summary><p>Resposta</p></details>
```

As respostas atuais são **modelos**. Confirme prazos, cidades atendidas, garantia e parcelamento reais.

### 3.8 Políticas (Privacidade e Trocas)

Procure `<section id="privacidade"` e `<section id="trocas"`. Ao alterar, atualize também a data em "Última atualização".

- **Privacidade (LGPD):** troque o e-mail do encarregado (`privacidade@meliahpiscinas.com.br`). Se a loja passar a usar newsletter, Google Analytics, Meta Pixel ou uma plataforma de loja virtual, a política precisa citar isso.
- **Trocas (CDC):** segue os prazos legais: 7 dias de arrependimento para compras fora da loja (art. 49), e 30 dias (não duráveis) ou 90 dias (duráveis) para defeitos (art. 26). O prazo de reembolso (10 dias úteis) e as regras para piscinas e obras devem bater com o contrato que vocês usam.

> Os textos são um ponto de partida bem fundamentado, mas não substituem a revisão de um advogado. Vale uma revisão antes de publicar.

### 3.9 Cores

No topo do arquivo, em `:root{`, ficam as cores: `--tile` (azul escuro), `--water` (azul água), `--buoy` (laranja dos botões principais), entre outras. O bloco seguinte define as cores do modo escuro. Se a empresa criar um logo, ajustamos essas cores a partir dele.

---

## 4. Como colocar o site no ar

1. **Registrar o domínio** em **registro.br** (por exemplo, `meliahpiscinas.com.br`). É preciso o CNPJ da empresa.
2. **Escolher uma hospedagem de site estático.** Netlify, Vercel e GitHub Pages têm plano gratuito que atende este site. No Netlify basta arrastar a pasta `meliah-piscinas` inteira.
3. **Ligar o domínio à hospedagem**, seguindo as instruções da própria hospedagem.
4. **Cadastrar no Google:** criar o Perfil da Empresa no Google (Maps e Busca) e o Google Search Console, para o Google encontrar o site.

**Quando migrar para uma plataforma de loja** (Nuvemshop, Shopify, Loja Integrada): quando quiser pagamento automático por Pix e cartão no próprio site, cálculo de frete pelos Correios e por transportadoras, ou controle de estoque ligado às vendas. Os produtos, textos e políticas deste site podem ser reaproveitados lá.

---

## 5. Informações para o Google (já incluídas)

O topo do `index.html` já tem o que o Google lê:

- **`<meta name="description">`**: o texto que aparece embaixo do título nos resultados de busca. Ajuste a cidade se a empresa atender outra região.
- **`og:title` e `og:description`**: título e texto do cartão que aparece quando alguém compartilha o link no WhatsApp ou no Facebook.
- **Bloco `application/ld+json`**: ficha da empresa em formato que o Google entende (nome, razão social, CNPJ, telefone, endereço e horário).

No bloco `application/ld+json`, troque pelos dados reais: `telephone`, `streetAddress`, `addressLocality`, `postalCode` e `url` (o domínio registrado). **Esses dados precisam ser exatamente iguais aos do Perfil da Empresa no Google**, com o mesmo endereço e telefone, escritos da mesma forma. Dados diferentes atrapalham a empresa a aparecer no Maps.

---

## 6. Próximas etapas do projeto

- [ ] Perfil da Empresa no Google (Maps e Busca)
- [ ] Sistema de estoque com os mesmos códigos (`id`) dos produtos do site
- [ ] Instagram da loja, com link no site
- [ ] Depoimentos de clientes reais (nunca inventados)
