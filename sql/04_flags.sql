-- 04_flags.sql : vues de signalement. Rien n'est supprimé ni modifié : ce sont des lignes à arbitrer.
-- Les seuils sont des heuristiques de travail, pas des vérités. Ajustez-les à votre métier.

-- 85 articles à 9.43 : égal à la moyenne arrondie des 166 autres valeurs (9.425). Hypothèse : valeur imputée, non mesurée.
CREATE VIEW v_flag_loss_rate_default AS
SELECT p.item_code, p.item_name, l.loss_rate_pct
FROM loss_rate l JOIN product p USING (item_code)
WHERE l.loss_rate_pct = 9.43;

-- Taux de perte nul : mesure réelle ou donnée manquante ? Non tranchable sur les données seules.
CREATE VIEW v_flag_loss_rate_zero AS
SELECT p.item_code, p.item_name
FROM loss_rate l JOIN product p USING (item_code)
WHERE l.loss_rate_pct = 0;

-- Même libellé, codes différents : produits distincts (conditionnement, catégorie) ou doublon ?
CREATE VIEW v_flag_product_duplicate_name AS
SELECT item_name, COUNT(*) AS nb_codes, GROUP_CONCAT(item_code) AS item_codes
FROM product GROUP BY item_name HAVING COUNT(*) > 1;

-- Articles du catalogue sans aucune transaction.
CREATE VIEW v_flag_product_unsold AS
SELECT item_code, item_name FROM product
WHERE item_code NOT IN (SELECT DISTINCT item_code FROM "transaction");

-- Prix de gros à plus de 5x ou à moins de 1/5 de la moyenne de l'article (la moyenne est elle-même sensible aux pics).
CREATE VIEW v_flag_price_extreme AS
WITH m AS (SELECT item_code, AVG(wholesale_price) AS avg_price FROM price GROUP BY item_code)
SELECT p.price_date, p.item_code, p.wholesale_price, ROUND(m.avg_price, 2) AS item_avg_price
FROM price p JOIN m USING (item_code)
WHERE p.wholesale_price > 5 * m.avg_price OR p.wholesale_price < m.avg_price / 5.0;

-- Quantité unitaire >= 10 kg (seuil arbitraire) : saisie erronée possible (ex. 160 kg d'un article à 5.9 RMB/kg).
CREATE VIEW v_flag_tx_qty_outlier AS
SELECT t.transaction_id, t.sale_date, t.sale_time, t.item_code, p.item_name, t.quantity_sold_kg, t.unit_selling_price
FROM "transaction" t JOIN product p USING (item_code)
WHERE t.quantity_sold_kg >= 10;

-- Vente à un prix inférieur au prix de gros du même jour (colonne discount visible).
CREATE VIEW v_flag_tx_below_wholesale AS
SELECT t.transaction_id, t.sale_date, t.item_code, t.unit_selling_price, w.wholesale_price, t.discount
FROM "transaction" t JOIN price w ON w.price_date = t.sale_date AND w.item_code = t.item_code
WHERE t.sale_or_return = 'sale' AND t.unit_selling_price < w.wholesale_price;

-- Retour sans aucune vente du même article le même jour.
CREATE VIEW v_flag_tx_return_without_sale AS
SELECT r.transaction_id, r.sale_date, r.sale_time, r.item_code, r.quantity_sold_kg
FROM "transaction" r
WHERE r.sale_or_return = 'return'
  AND NOT EXISTS (SELECT 1 FROM "transaction" s
                  WHERE s.sale_or_return = 'sale' AND s.sale_date = r.sale_date AND s.item_code = r.item_code);

-- Même (date, heure, article) sur plusieurs lignes : deux ventes distinctes à la milliseconde (quantités différentes), pas un doublon.
CREATE VIEW v_flag_tx_same_timestamp AS
SELECT t.*
FROM "transaction" t
JOIN (SELECT sale_date, sale_time, item_code FROM "transaction"
      GROUP BY 1, 2, 3 HAVING COUNT(*) > 1) d USING (sale_date, sale_time, item_code);
