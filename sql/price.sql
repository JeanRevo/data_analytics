-- price.sql : table price (prix de gros journalier par article, RMB/kg). Dialecte SQLite.
-- Sections lues par scripts/build.py : @schema, @clean, @checks, @flags.
--
-- À COMPLÉTER sur la branche feature/price. Ne modifier que ce fichier.
-- Table liée à product (item_code). Source : data/price.csv, 55 982 lignes, raw_price (colonnes TEXT c0, c1, c2).
--
-- À faire :
--   1. Profiler raw_price avec des requêtes simples (doublons sur (date, article), valeurs min/max, formats de date,
--      couverture en jours par article, valeurs inhabituelles).
--   2. Décider ce qui se corrige (déterministe, sans perte) et ce qui se signale seulement.
--   3. Écrire @checks : une ligne (nom, écart) par contrôle, écart attendu = 0.
--   4. Écrire @flags : une vue v_flag_price_<sujet> par anomalie à arbitrer. Ne rien supprimer.

-- @schema
CREATE TABLE price (
    price_date       DATE          NOT NULL,
    item_code        INTEGER       NOT NULL REFERENCES product (item_code),
    wholesale_price  DECIMAL(10,2) NOT NULL CHECK (wholesale_price > 0),
    PRIMARY KEY (price_date, item_code)
);
CREATE INDEX idx_price_item ON price (item_code);

-- @clean
-- TODO : chargement brut, sans nettoyage. Documenter ici chaque correction ajoutée.
INSERT INTO price (price_date, item_code, wholesale_price)
SELECT c0, CAST(c1 AS INTEGER), CAST(c2 AS REAL)
FROM raw_price;

-- @checks
-- TODO : SELECT 'nom du contrôle' AS nom, <écart attendu 0> AS ecart UNION ALL SELECT ... ;

-- @flags
-- TODO : CREATE VIEW v_flag_price_<sujet> AS SELECT ...;
