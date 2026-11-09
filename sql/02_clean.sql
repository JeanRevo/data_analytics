-- 02_clean.sql : raw_* -> tables propres. Corrections déterministes uniquement, aucune ligne supprimée.
-- Colonnes raw : c0, c1, ... dans l'ordre des colonnes du CSV.

-- product : espaces de bord et doubles espaces retirés ; espace insécable (U+00A0) remplacé par une espace.
INSERT INTO product (item_code, item_name, category_code, category_name)
SELECT CAST(c0 AS INTEGER),
       REPLACE(TRIM(c1), '  ', ' '),
       CAST(c2 AS INTEGER),
       TRIM(REPLACE(c3, char(160), ' '))
FROM raw_product;

-- loss_rate : espace finale retirée, texte -> nombre. (item_name n'est pas repris : identique à product, 0 écart.)
INSERT INTO loss_rate (item_code, loss_rate_pct)
SELECT CAST(c0 AS INTEGER),
       ROUND(CAST(TRIM(c2) AS REAL), 2)
FROM raw_loss_rate;

-- price : texte -> types.
INSERT INTO price (price_date, item_code, wholesale_price)
SELECT c0, CAST(c1 AS INTEGER), ROUND(CAST(c2 AS REAL), 2)
FROM raw_price;

-- transaction : l'export a supprimé les zéros finaux des millisecondes ('09:23:08.96' = .960, '09:31:37' = .000).
-- On complète à 3 décimales : la valeur numérique du temps est inchangée.
-- ORDER BY rowid conserve l'ordre du fichier pour transaction_id.
INSERT INTO "transaction" (sale_date, sale_time, item_code, quantity_sold_kg, unit_selling_price, sale_or_return, discount)
SELECT c0,
       substr(c1, 1, 8) || '.' || substr(substr(c1, 10) || '000', 1, 3),
       CAST(c2 AS INTEGER),
       CAST(c3 AS REAL),
       CAST(c4 AS REAL),
       LOWER(TRIM(c5)),
       TRIM(c6)
FROM raw_transaction
ORDER BY rowid;
