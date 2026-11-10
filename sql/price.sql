-- price.sql : table price (prix de gros journalier par article, RMB/kg). Dialecte SQLite.
-- Sections lues par scripts/build.py : @schema, @clean, @checks, @flags.
-- Table liée à product (item_code). Source : data/price.csv, 55 982 lignes, raw_price (colonnes TEXT c0, c1, c2).
--
-- Profilage de raw_price :
--   - 55 982 lignes, 251 articles, 1 091 jours distincts du 2020-07-01 au 2023-06-30 (plage de 1 095 jours).
--   - Aucun doublon sur (date, article), aucune valeur vide, aucune espace de bord, aucun orphelin vis-à-vis de product.
--   - Dates toutes au format ISO AAAA-MM-JJ et valides ; prix tous numériques, au plus 2 décimales, de 0,01 à 141,00.
--   - 4 jours sans aucun prix (2021-02-11, 2021-02-12, 2022-01-31, 2023-01-21), sans aucune transaction non plus.
--   - Couverture de 1 à 1 085 jours par article ; 84 articles ont moins de 30 jours de prix.
--   - 273 prix sous 0,50 RMB/kg sur 86 articles, dont 257 entre août 2022 et février 2023 (surtout 0,10 et 0,01).
--   - 119 prix au moins 5 fois plus bas (109) ou plus haut (10) que les prix précédent et suivant du même article.

-- @schema
CREATE TABLE price (
    price_date       DATE          NOT NULL,
    item_code        INTEGER       NOT NULL REFERENCES product (item_code),
    wholesale_price  DECIMAL(10,2) NOT NULL CHECK (wholesale_price > 0),
    PRIMARY KEY (price_date, item_code)
);
CREATE INDEX idx_price_item ON price (item_code);

-- @clean
-- Aucune correction de valeur nécessaire (formats déjà propres, voir profilage) : texte -> entier et réel.
INSERT INTO price (price_date, item_code, wholesale_price)
SELECT c0, CAST(c1 AS INTEGER), CAST(c2 AS REAL)
FROM raw_price;

-- @checks
-- Une ligne par contrôle : (nom, écart). Attendu : 0.
SELECT 'rowcount price' AS nom, (SELECT COUNT(*) FROM price) - (SELECT COUNT(*) FROM raw_price) AS ecart
UNION ALL SELECT 'sum price',
          ABS((SELECT SUM(wholesale_price) FROM price) - (SELECT SUM(CAST(c2 AS REAL)) FROM raw_price)) > 1e-6
-- Affinité NUMERIC de DECIMAL : un prix rond (6.0) est stocké en entier, d'où 'integer' accepté.
UNION ALL SELECT 'price types', COUNT(*) FROM price
          WHERE typeof(item_code) <> 'integer' OR typeof(wholesale_price) NOT IN ('integer', 'real')
UNION ALL SELECT 'price.price_date invalide', COUNT(*) FROM price
          WHERE date(price_date) IS NOT price_date OR price_date NOT BETWEEN '2020-07-01' AND '2023-06-30'
UNION ALL SELECT 'orphelins price', COUNT(*) FROM price WHERE item_code NOT IN (SELECT item_code FROM product)
UNION ALL SELECT 'articles sans price', COUNT(*) FROM product WHERE item_code NOT IN (SELECT item_code FROM price)
UNION ALL SELECT 'ventes sans prix de gros du jour', COUNT(*)
          FROM (SELECT DISTINCT sale_date, item_code FROM "transaction") t
          WHERE NOT EXISTS (SELECT 1 FROM price p WHERE p.price_date = t.sale_date AND p.item_code = t.item_code);

-- @flags
-- Lignes à arbitrer : jamais modifiées ni supprimées. Les seuils sont des heuristiques.

-- Prix sous 0,50 RMB/kg : 257 sur 273 entre août 2022 et février 2023, surtout 0,10 et 0,01.
-- Hypothèse : valeur de remplissage saisie à la place du prix réel. Non démontré.
CREATE VIEW v_flag_price_very_low AS
SELECT p.price_date, p.item_code, pr.item_name, p.wholesale_price, ROUND(p.item_avg, 2) AS item_avg_price
FROM (SELECT *, AVG(wholesale_price) OVER (PARTITION BY item_code) AS item_avg FROM price) p
JOIN product pr USING (item_code)
WHERE p.wholesale_price < 0.5;

-- Pic isolé : prix au moins 5 fois plus bas ou plus haut que le prix précédent ET le prix suivant du même article.
-- Comparaison aux voisins plutôt qu'à la moyenne de l'article, que les pics eux-mêmes faussent.
CREATE VIEW v_flag_price_spike AS
SELECT p.item_code, pr.item_name, p.prev_date, p.prev_price, p.price_date, p.wholesale_price, p.next_date, p.next_price
FROM (SELECT *,
             LAG(price_date)       OVER w AS prev_date,
             LAG(wholesale_price)  OVER w AS prev_price,
             LEAD(price_date)      OVER w AS next_date,
             LEAD(wholesale_price) OVER w AS next_price
      FROM price WINDOW w AS (PARTITION BY item_code ORDER BY price_date)) p
JOIN product pr USING (item_code)
WHERE p.wholesale_price * 5 <= MIN(p.prev_price, p.next_price)
   OR p.wholesale_price >= 5 * MAX(p.prev_price, p.next_price);

-- Jours de la plage sans aucun prix. Aucune vente ces jours-là non plus.
-- Hypothèse : magasin fermé (veilles du Nouvel An chinois). Non démontré.
CREATE VIEW v_flag_price_missing_day AS
WITH RECURSIVE d(day) AS (
    SELECT MIN(price_date) FROM price
    UNION ALL SELECT date(day, '+1 day') FROM d WHERE day < (SELECT MAX(price_date) FROM price)
)
SELECT day AS missing_date,
       (SELECT COUNT(*) FROM "transaction" t WHERE t.sale_date = d.day) AS nb_transactions
FROM d
WHERE day NOT IN (SELECT price_date FROM price);

-- Articles avec moins de 30 jours de prix : série trop courte pour une analyse de prix fiable.
CREATE VIEW v_flag_price_low_coverage AS
SELECT p.item_code, pr.item_name, COUNT(*) AS nb_days, MIN(p.price_date) AS first_date, MAX(p.price_date) AS last_date
FROM price p JOIN product pr USING (item_code)
GROUP BY p.item_code
HAVING COUNT(*) < 30;
