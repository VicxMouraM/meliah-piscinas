-- =====================================================================
--  MELIAH PISCINAS – Produtos iniciais (os mesmos do site, preços de EXEMPLO)
--  Rode DEPOIS do schema.sql. Não apaga nada: se o código já existir, pula.
--  O estoque começa em zero. Lance a contagem inicial no painel:
--  Estoque → produto → "Entrada".
-- =====================================================================
insert into public.produtos (id, nome, categoria, descricao, preco_venda, estoque_minimo, icone) values
  ('clg10', 'Cloro granulado estabilizado 10 kg', 'Tratamento', 'Uso diário e choque', 289.9, 5, 'balde'),
  ('clg25', 'Cloro granulado 2,5 kg', 'Tratamento', 'Para piscinas pequenas', 84.9, 5, 'balde'),
  ('past', 'Pastilha de cloro 200 g (pote c/ 5)', 'Tratamento', 'Para clorador flutuante', 59.9, 5, 'pastilha'),
  ('alg', 'Algicida de manutenção 1 L', 'Tratamento', 'Evita água verde', 32.9, 5, 'frasco'),
  ('clar', 'Clarificante 1 L', 'Tratamento', 'Água turva → cristalina', 29.9, 5, 'frasco'),
  ('phm', 'Elevador de pH (barrilha) 2 kg', 'Equilíbrio', 'Sobe pH e alcalinidade', 38.9, 3, 'balde'),
  ('phme', 'Redutor de pH 1 L', 'Equilíbrio', 'Baixa pH alto', 27.9, 3, 'frasco'),
  ('kit', 'Estojo de teste pH e cloro', 'Equilíbrio', 'Teste por gotas', 44.9, 3, 'kit'),
  ('pen', 'Peneira cata-folha com cabo', 'Limpeza', 'Cabo telescópico 3 m', 79.9, 2, 'rede'),
  ('asp', 'Aspirador de 8 rodas', 'Limpeza', 'Para fibra e vinil', 119.9, 2, 'rede'),
  ('bomba14', 'Motobomba 1/4 CV', 'Equipamentos', 'Até 18.000 L', 749, 1, 'equip'),
  ('bomba', 'Motobomba 1/2 CV', 'Equipamentos', 'Até 32.000 L', 1149, 1, 'equip'),
  ('bomba34', 'Motobomba 3/4 CV', 'Equipamentos', 'Até 50.000 L', 1489, 1, 'equip'),
  ('bomba1', 'Motobomba 1 CV', 'Equipamentos', 'Até 75.000 L', 1790, 1, 'equip'),
  ('areia', 'Areia para filtro 25 kg', 'Equipamentos', 'Troca a cada 2 anos', 69.9, 1, 'balde')
on conflict (id) do nothing;
