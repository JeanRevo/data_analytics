-- transaction.sql : table transaction (ventes et retours). Dialecte SQLite.
-- Sections lues par scripts/build.py : @schema, @clean, @checks, @flags.
--
-- À COMPLÉTER sur la branche feature/transaction. Ne modifier que ce fichier.
-- Table liée à product (item_code). Source : data/transaction.csv, 878 503 lignes, raw_transaction
-- (colonnes TEXT c0..c6 : date, heure, article, quantité, prix unitaire, vente/retour, remise).
-- Attention : transaction.csv n'est pas dans le dépôt (51,8 Mo), à placer dans data/ (voir README).
--
-- À faire :
--   1. Profiler raw_transaction avec des requêtes simples (formats de date et d'heure, quantités négatives
--      et leur lien avec la colonne vente/retour, doublons, valeurs extrêmes, articles absents de product).
--      Astuce performance : sur 878 503 lignes, créer des index avant toute sous-requête corrélée.
--   2. Décider ce qui se corrige (déterministe, sans perte) et ce qui se signale seulement.
--   3. Écrire @checks : une ligne (nom, écart) par contrôle, écart attendu = 0.
--   4. Écrire @flags : une vue v_flag_tx_<sujet> par anomalie à arbitrer. Ne rien supprimer.

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
-- TODO : chargement brut, sans nettoyage. Documenter ici chaque correction ajoutée.
INSERT INTO "transaction" (sale_date, sale_time, item_code, quantity_sold_kg, unit_selling_price, sale_or_return, discount)
SELECT c0, c1, CAST(c2 AS INTEGER), CAST(c3 AS REAL), CAST(c4 AS REAL), c5, c6
FROM raw_transaction
ORDER BY rowid;

-- @checks
-- TODO : SELECT 'nom du contrôle' AS nom, <écart attendu 0> AS ecart UNION ALL SELECT ... ;

-- @flags
-- TODO : CREATE VIEW v_flag_tx_<sujet> AS SELECT ...;
