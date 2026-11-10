-- transaction.sql : table transaction (ventes et retours, 878 503 lignes). Dialecte SQLite.
-- Sections lues par scripts/build.py : @schema, @clean, @checks, @flags.
-- Table liée à product (item_code). Source : data/transaction.csv, raw_transaction
-- (colonnes TEXT c0..c6 : date, heure, article, quantité, prix unitaire, vente/retour, remise).
-- Attention : transaction.csv n'est pas dans le dépôt (51,8 Mo), à placer dans data/ (voir README).

-- @schema
CREATE TABLE "transaction" (
    transaction_id      INTEGER       NOT NULL PRIMARY KEY AUTOINCREMENT,
    sale_date           DATE          NOT NULL,
    sale_time           TIME          NOT NULL,                    -- cible : 'HH:MM:SS.mmm'
    item_code           INTEGER       NOT NULL REFERENCES product (item_code),
    quantity_sold_kg    DECIMAL(10,3) NOT NULL,                    -- négatif pour un retour
    unit_selling_price  DECIMAL(10,2) NOT NULL CHECK (unit_selling_price > 0),  -- RMB/kg
    sale_or_return      VARCHAR(6)    NOT NULL CHECK (sale_or_return IN ('sale', 'return')),
    discount            VARCHAR(3)    NOT NULL CHECK (discount IN ('Yes', 'No')),
    CHECK ((sale_or_return = 'sale' AND quantity_sold_kg > 0)
        OR (sale_or_return = 'return' AND quantity_sold_kg < 0))
);
CREATE INDEX idx_tx_item ON "transaction" (item_code);
CREATE INDEX idx_tx_date ON "transaction" (sale_date);

-- @clean
-- Une seule correction, déterministe et sans perte : l'heure est complétée par des zéros à droite
-- pour obtenir 'HH:MM:SS.mmm' (18 841 heures sur 878 503 avaient 0, 1 ou 2 décimales au lieu de 3).
-- Hypothèse : zéros finaux supprimés à l'export. La valeur numérique est identique, vérifié dans @checks.
-- Rien d'autre à corriger : dates toutes ISO, aucune valeur vide, aucune espace de bord, quantités à 3 décimales
-- au plus, prix à 2 au plus, signe de la quantité cohérent avec vente/retour, aucun article hors product.
-- Aucune ligne supprimée : l'ordre du fichier est conservé (transaction_id = numéro de ligne).
INSERT INTO "transaction" (sale_date, sale_time, item_code, quantity_sold_kg, unit_selling_price, sale_or_return, discount)
SELECT c0,
       CASE LENGTH(c1) WHEN 8 THEN c1 || '.000'
                       WHEN 10 THEN c1 || '00'
                       WHEN 11 THEN c1 || '0'
                       ELSE c1 END,
       CAST(c2 AS INTEGER),
       ROUND(CAST(c3 AS REAL), 3),
       ROUND(CAST(c4 AS REAL), 2),
       c5,
       c6
FROM raw_transaction
ORDER BY rowid;

-- @checks
SELECT 'rowcount transaction' AS nom, (SELECT COUNT(*) FROM "transaction") - (SELECT COUNT(*) FROM raw_transaction) AS ecart
UNION ALL SELECT 'sum quantite',
          ABS((SELECT SUM(quantity_sold_kg) FROM "transaction") - (SELECT SUM(CAST(c3 AS REAL)) FROM raw_transaction)) > 1e-3
UNION ALL SELECT 'sum prix unitaire',
          ABS((SELECT SUM(unit_selling_price) FROM "transaction") - (SELECT SUM(CAST(c4 AS REAL)) FROM raw_transaction)) > 1e-3
UNION ALL SELECT 'lignes alterees vs brut (hors heure)', COUNT(*)
          FROM "transaction" t JOIN raw_transaction r ON r.rowid = t.transaction_id
          WHERE t.sale_date <> r.c0 OR t.item_code <> CAST(r.c2 AS INTEGER)
             OR t.quantity_sold_kg <> CAST(r.c3 AS REAL) OR t.unit_selling_price <> CAST(r.c4 AS REAL)
             OR t.sale_or_return <> r.c5 OR t.discount <> r.c6
UNION ALL SELECT 'heure differente en valeur', COUNT(*)
          FROM "transaction" t JOIN raw_transaction r ON r.rowid = t.transaction_id
          WHERE SUBSTR(t.sale_time, 1, 8) <> SUBSTR(r.c1, 1, 8)
             OR CAST(SUBSTR(t.sale_time, 9) AS REAL) <> CAST(SUBSTR(r.c1, 9) AS REAL)
UNION ALL SELECT 'heure hors format HH:MM:SS.mmm', COUNT(*)
          FROM "transaction"
          WHERE sale_time NOT GLOB '[0-2][0-9]:[0-5][0-9]:[0-5][0-9].[0-9][0-9][0-9]'
UNION ALL SELECT 'date hors format ISO', COUNT(*)
          FROM "transaction"
          WHERE sale_date NOT GLOB '[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]' OR sale_date <> DATE(sale_date)
UNION ALL SELECT 'orphelins transaction', COUNT(*)
          FROM "transaction" WHERE item_code NOT IN (SELECT item_code FROM product)
UNION ALL SELECT 'signe quantite incoherent', COUNT(*)
          FROM "transaction"
          WHERE (sale_or_return = 'sale' AND quantity_sold_kg <= 0) OR (sale_or_return = 'return' AND quantity_sold_kg >= 0);

-- @flags
-- Lignes non modifiées, à arbitrer. Chaque vue renvoie les lignes de transaction concernées.

-- Vente à un prix inférieur au prix de gros du même jour (12 651 lignes, dont 3 356 sans remise).
-- Erreur de saisie, vente à perte assumée ou prix de gros peu fiable : non tranchable sur les données seules.
CREATE VIEW v_flag_tx_below_wholesale AS
SELECT t.transaction_id, t.sale_date, t.sale_time, t.item_code,
       t.unit_selling_price, p.wholesale_price, t.discount
FROM "transaction" t JOIN price p ON p.price_date = t.sale_date AND p.item_code = t.item_code
WHERE t.sale_or_return = 'sale' AND t.unit_selling_price < p.wholesale_price;

-- Quantité de 10 kg ou plus (56 lignes, maximum 160 kg d'un article à 5,9 RMB/kg).
-- Vente en gros réelle ou erreur d'unité (grammes saisis en kilos) : non tranchable.
CREATE VIEW v_flag_tx_large_qty AS
SELECT transaction_id, sale_date, sale_time, item_code, quantity_sold_kg, unit_selling_price, sale_or_return
FROM "transaction"
WHERE ABS(quantity_sold_kg) >= 10;

-- Retour sans aucune vente du même article le même jour (4 lignes).
-- La vente d'origine peut dater d'un autre jour : à ce stade, pas une erreur démontrée.
CREATE VIEW v_flag_tx_return_no_sale AS
SELECT r.transaction_id, r.sale_date, r.sale_time, r.item_code, r.quantity_sold_kg
FROM "transaction" r
WHERE r.sale_or_return = 'return'
  AND NOT EXISTS (SELECT 1 FROM "transaction" s
                  WHERE s.sale_or_return = 'sale' AND s.item_code = r.item_code AND s.sale_date = r.sale_date);

-- Même (date, heure, article) sur 2 lignes (1 couple) : quantités différentes (0,565 et 0,578).
-- Lu comme deux ventes distinctes, pas comme un doublon.
CREATE VIEW v_flag_tx_same_timestamp AS
SELECT t.transaction_id, t.sale_date, t.sale_time, t.item_code, t.quantity_sold_kg, t.unit_selling_price
FROM "transaction" t
JOIN (SELECT sale_date, sale_time, item_code FROM "transaction"
      GROUP BY sale_date, sale_time, item_code HAVING COUNT(*) > 1) d
  USING (sale_date, sale_time, item_code);

-- Prix très éloigné de la moyenne de l'article : plus de 5 fois (2 lignes) ou moins d'un cinquième (61 lignes).
-- La moyenne étant sensible aux pics, c'est un indice et non une preuve d'erreur.
CREATE VIEW v_flag_tx_price_outlier AS
SELECT t.transaction_id, t.sale_date, t.item_code, t.unit_selling_price,
       ROUND(a.avg_price, 2) AS avg_item_price,
       ROUND(t.unit_selling_price / a.avg_price, 2) AS ratio
FROM "transaction" t
JOIN (SELECT item_code, AVG(unit_selling_price) AS avg_price FROM "transaction" GROUP BY item_code) a USING (item_code)
WHERE t.unit_selling_price > 5 * a.avg_price OR t.unit_selling_price < a.avg_price / 5.0;
