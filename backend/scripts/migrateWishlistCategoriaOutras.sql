-- Executar uma vez se a tabela wishlist_itens ja existia sem a categoria "Outras".
-- psql $DATABASE_URL -f scripts/migrateWishlistCategoriaOutras.sql

ALTER TABLE wishlist_itens DROP CONSTRAINT IF EXISTS wishlist_itens_categoria_check;
ALTER TABLE wishlist_itens
  ADD CONSTRAINT wishlist_itens_categoria_check
  CHECK (categoria IN ('Comer', 'Visitar', 'Comprar', 'Outras'));
