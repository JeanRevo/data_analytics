-- 01_schema.sql : tables propres (typées, contraintes). Dialecte SQLite.
-- Les tables raw_* (colonnes TEXT, copie fidèle des CSV) sont créées par scripts/load_raw.py.

CREATE TABLE product (
    item_code      INTEGER      NOT NULL PRIMARY KEY,
    item_name      VARCHAR(128) NOT NULL,
    category_code  INTEGER      NOT NULL,
    category_name  VARCHAR(64)  NOT NULL
);

CREATE TABLE loss_rate (
    item_code      INTEGER      NOT NULL PRIMARY KEY REFERENCES product (item_code),
    loss_rate_pct  DECIMAL(5,2) NOT NULL CHECK (loss_rate_pct BETWEEN 0 AND 100)
);

CREATE TABLE price (
    price_date       DATE          NOT NULL,
    item_code        INTEGER       NOT NULL REFERENCES product (item_code),
    wholesale_price  DECIMAL(10,2) NOT NULL CHECK (wholesale_price > 0),  -- RMB/kg
    PRIMARY KEY (price_date, item_code)
);

CREATE TABLE "transaction" (
    transaction_id      INTEGER       NOT NULL PRIMARY KEY AUTOINCREMENT,
    sale_date           DATE          NOT NULL,
    sale_time           TIME          NOT NULL,                    -- 'HH:MM:SS.mmm'
    item_code           INTEGER       NOT NULL REFERENCES product (item_code),
    quantity_sold_kg    DECIMAL(10,3) NOT NULL,                    -- négatif pour un retour
    unit_selling_price  DECIMAL(10,2) NOT NULL CHECK (unit_selling_price > 0),  -- RMB/kg
    sale_or_return      VARCHAR(6)    NOT NULL CHECK (sale_or_return IN ('sale', 'return')),
    discount            VARCHAR(3)    NOT NULL CHECK (discount IN ('Yes', 'No')),
    -- invariant vérifié sur les données : vente = quantité > 0, retour = quantité < 0
    CHECK ((sale_or_return = 'sale' AND quantity_sold_kg > 0)
        OR (sale_or_return = 'return' AND quantity_sold_kg < 0))
);

CREATE INDEX idx_product_category ON product (category_code);
CREATE INDEX idx_price_item       ON price (item_code);
CREATE INDEX idx_tx_item          ON "transaction" (item_code);
CREATE INDEX idx_tx_date          ON "transaction" (sale_date);
