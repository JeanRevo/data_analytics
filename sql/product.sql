-- product.sql : table product (catalogue). Dialecte SQLite.
-- Sections lues par scripts/build.py : @schema, @clean, @checks, @flags.
-- Les tables raw_* (colonnes TEXT c0, c1, ... = copie fidèle du CSV) sont créées par scripts/load_raw.py.

-- @schema
CREATE TABLE product (
    item_code      INTEGER      NOT NULL PRIMARY KEY,
    item_name      VARCHAR(128) NOT NULL,
    category_code  INTEGER      NOT NULL,
    category_name  VARCHAR(64)  NOT NULL
);
CREATE INDEX idx_product_category ON product (category_code);

-- @clean
-- Espaces de bord et doubles espaces retirés ; espace insécable (U+00A0) remplacée par une espace.
INSERT INTO product (item_code, item_name, category_code, category_name)
SELECT CAST(c0 AS INTEGER),
       REPLACE(TRIM(c1), '  ', ' '),
       CAST(c2 AS INTEGER),
       TRIM(REPLACE(c3, char(160), ' '))
FROM raw_product;

-- @checks
-- Une ligne par contrôle : (nom, écart). Attendu : 0.
SELECT 'rowcount product' AS nom, (SELECT COUNT(*) FROM product) - (SELECT COUNT(*) FROM raw_product) AS ecart
UNION ALL SELECT 'product.item_name espaces', COUNT(*) FROM product
          WHERE item_name <> TRIM(item_name) OR item_name LIKE '%  %'
UNION ALL SELECT 'product.category_name nbsp/espaces', COUNT(*) FROM product
          WHERE category_name LIKE '%' || char(160) || '%' OR category_name <> TRIM(category_name);

-- @flags
-- Lignes à arbitrer : jamais modifiées ni supprimées.

-- Même libellé, codes différents : produits distincts (conditionnement, catégorie) ou doublon ?
CREATE VIEW v_flag_product_duplicate_name AS
SELECT item_name, COUNT(*) AS nb_codes, GROUP_CONCAT(item_code) AS item_codes
FROM product GROUP BY item_name HAVING COUNT(*) > 1;

-- Articles du catalogue sans aucune transaction.
CREATE VIEW v_flag_product_unsold AS
SELECT item_code, item_name FROM product
WHERE item_code NOT IN (SELECT DISTINCT item_code FROM "transaction");
