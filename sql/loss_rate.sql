-- loss_rate.sql : table loss_rate (taux de perte par article, en %). Dialecte SQLite.
-- Sections lues par scripts/build.py : @schema, @clean, @checks, @flags.

-- @schema
CREATE TABLE loss_rate (
    item_code      INTEGER      NOT NULL PRIMARY KEY REFERENCES product (item_code),
    loss_rate_pct  DECIMAL(5,2) NOT NULL CHECK (loss_rate_pct BETWEEN 0 AND 100)
);

-- @clean
-- Espace finale retirée de la valeur, texte -> nombre.
-- item_name n'est pas repris : identique à product (0 écart sur 251).
INSERT INTO loss_rate (item_code, loss_rate_pct)
SELECT CAST(c0 AS INTEGER),
       ROUND(CAST(TRIM(c2) AS REAL), 2)
FROM raw_loss_rate;

-- @checks
SELECT 'rowcount loss_rate' AS nom, (SELECT COUNT(*) FROM loss_rate) - (SELECT COUNT(*) FROM raw_loss_rate) AS ecart
UNION ALL SELECT 'sum loss_rate',
          ABS((SELECT SUM(loss_rate_pct) FROM loss_rate) - (SELECT SUM(CAST(c2 AS REAL)) FROM raw_loss_rate)) > 1e-6
UNION ALL SELECT 'orphelins loss_rate', COUNT(*) FROM loss_rate WHERE item_code NOT IN (SELECT item_code FROM product)
UNION ALL SELECT 'articles sans loss_rate', COUNT(*) FROM product WHERE item_code NOT IN (SELECT item_code FROM loss_rate);

-- @flags
-- 85 articles à 9.43 : égal à la moyenne arrondie des 166 autres valeurs (9.425).
-- Hypothèse : valeur imputée, non mesurée. Non démontré.
CREATE VIEW v_flag_loss_rate_default AS
SELECT p.item_code, p.item_name, l.loss_rate_pct
FROM loss_rate l JOIN product p USING (item_code)
WHERE l.loss_rate_pct = 9.43;

-- Taux de perte nul : mesure réelle ou donnée manquante ? Non tranchable sur les données seules.
CREATE VIEW v_flag_loss_rate_zero AS
SELECT p.item_code, p.item_name
FROM loss_rate l JOIN product p USING (item_code)
WHERE l.loss_rate_pct = 0;
