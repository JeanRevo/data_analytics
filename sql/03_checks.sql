-- 03_checks.sql : contrôles après nettoyage. Chaque ligne = (nom, écart). Attendu : écart = 0 partout.

SELECT 'rowcount product',     (SELECT COUNT(*) FROM product)       - (SELECT COUNT(*) FROM raw_product)     AS ecart
UNION ALL SELECT 'rowcount loss_rate',  (SELECT COUNT(*) FROM loss_rate)     - (SELECT COUNT(*) FROM raw_loss_rate)
UNION ALL SELECT 'rowcount price',      (SELECT COUNT(*) FROM price)         - (SELECT COUNT(*) FROM raw_price)
UNION ALL SELECT 'rowcount transaction',(SELECT COUNT(*) FROM "transaction") - (SELECT COUNT(*) FROM raw_transaction)

-- aucune valeur numérique altérée par le nettoyage (somme conservée, tolérance 1e-6)
UNION ALL SELECT 'sum loss_rate',  ABS((SELECT SUM(loss_rate_pct) FROM loss_rate) - (SELECT SUM(CAST(c2 AS REAL)) FROM raw_loss_rate)) > 1e-6
UNION ALL SELECT 'sum wholesale',  ABS((SELECT SUM(wholesale_price) FROM price) - (SELECT SUM(CAST(c2 AS REAL)) FROM raw_price)) > 1e-6
UNION ALL SELECT 'sum quantity',   ABS((SELECT SUM(quantity_sold_kg) FROM "transaction") - (SELECT SUM(CAST(c3 AS REAL)) FROM raw_transaction)) > 1e-6
UNION ALL SELECT 'sum unit price', ABS((SELECT SUM(unit_selling_price) FROM "transaction") - (SELECT SUM(CAST(c4 AS REAL)) FROM raw_transaction)) > 1e-6

-- chaînes propres
UNION ALL SELECT 'product.item_name espaces', COUNT(*) FROM product
          WHERE item_name <> TRIM(item_name) OR item_name LIKE '%  %'
UNION ALL SELECT 'product.category_name nbsp/espaces', COUNT(*) FROM product
          WHERE category_name LIKE '%' || char(160) || '%' OR category_name <> TRIM(category_name)

-- format d'heure uniforme HH:MM:SS.mmm
UNION ALL SELECT 'sale_time format', COUNT(*) FROM "transaction"
          WHERE sale_time NOT GLOB '[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]'

-- intégrité référentielle (en plus des FK déclarées)
UNION ALL SELECT 'orphelins loss_rate',   COUNT(*) FROM loss_rate WHERE item_code NOT IN (SELECT item_code FROM product)
UNION ALL SELECT 'orphelins price',       COUNT(*) FROM price WHERE item_code NOT IN (SELECT item_code FROM product)
UNION ALL SELECT 'orphelins transaction', COUNT(*) FROM "transaction" WHERE item_code NOT IN (SELECT item_code FROM product)
UNION ALL SELECT 'articles sans loss_rate', COUNT(*) FROM product WHERE item_code NOT IN (SELECT item_code FROM loss_rate)
UNION ALL SELECT 'articles sans price',     COUNT(*) FROM product WHERE item_code NOT IN (SELECT item_code FROM price);
