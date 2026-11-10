# Commandes SQL utilisées

Journal généré par `scripts/make_log.py` à partir de `sql/<table>.sql`. Ne pas éditer à la main : modifier le fichier SQL puis relancer le script.
Les tables `raw_*` sont la copie fidèle des CSV (colonnes TEXT `c0`, `c1`, ...). Dialecte SQLite.

## product

Fichier : `sql/product.sql`

### Schéma (CREATE TABLE)

```sql
CREATE TABLE product (
    item_code      INTEGER      NOT NULL PRIMARY KEY,
    item_name      VARCHAR(128) NOT NULL,
    category_code  INTEGER      NOT NULL,
    category_name  VARCHAR(64)  NOT NULL
);
CREATE INDEX idx_product_category ON product (category_code);
```

### Nettoyage (INSERT ... SELECT depuis les données brutes)

```sql
-- Espaces de bord et doubles espaces retirés ; espace insécable (U+00A0) remplacée par une espace.
INSERT INTO product (item_code, item_name, category_code, category_name)
SELECT CAST(c0 AS INTEGER),
       REPLACE(TRIM(c1), '  ', ' '),
       CAST(c2 AS INTEGER),
       TRIM(REPLACE(c3, char(160), ' '))
FROM raw_product;
```

### Contrôles (écart attendu = 0)

```sql
-- Une ligne par contrôle : (nom, écart). Attendu : 0.
SELECT 'rowcount product' AS nom, (SELECT COUNT(*) FROM product) - (SELECT COUNT(*) FROM raw_product) AS ecart
UNION ALL SELECT 'product.item_name espaces', COUNT(*) FROM product
          WHERE item_name <> TRIM(item_name) OR item_name LIKE '%  %'
UNION ALL SELECT 'product.category_name nbsp/espaces', COUNT(*) FROM product
          WHERE category_name LIKE '%' || char(160) || '%' OR category_name <> TRIM(category_name);
```

### Lignes signalées, non modifiées (CREATE VIEW)

```sql
-- Lignes à arbitrer : jamais modifiées ni supprimées.

-- Même libellé, codes différents : produits distincts (conditionnement, catégorie) ou doublon ?
CREATE VIEW v_flag_product_duplicate_name AS
SELECT item_name, COUNT(*) AS nb_codes, GROUP_CONCAT(item_code) AS item_codes
FROM product GROUP BY item_name HAVING COUNT(*) > 1;

-- Articles du catalogue sans aucune transaction.
CREATE VIEW v_flag_product_unsold AS
SELECT item_code, item_name FROM product
WHERE item_code NOT IN (SELECT DISTINCT item_code FROM "transaction");
```

## loss_rate

Fichier : `sql/loss_rate.sql`

### Schéma (CREATE TABLE)

```sql
CREATE TABLE loss_rate (
    item_code      INTEGER      NOT NULL PRIMARY KEY REFERENCES product (item_code),
    loss_rate_pct  DECIMAL(5,2) NOT NULL CHECK (loss_rate_pct BETWEEN 0 AND 100)
);
```

### Nettoyage (INSERT ... SELECT depuis les données brutes)

```sql
-- Espace finale retirée de la valeur, texte -> nombre.
-- item_name n'est pas repris : identique à product (0 écart sur 251).
INSERT INTO loss_rate (item_code, loss_rate_pct)
SELECT CAST(c0 AS INTEGER),
       ROUND(CAST(TRIM(c2) AS REAL), 2)
FROM raw_loss_rate;
```

### Contrôles (écart attendu = 0)

```sql
SELECT 'rowcount loss_rate' AS nom, (SELECT COUNT(*) FROM loss_rate) - (SELECT COUNT(*) FROM raw_loss_rate) AS ecart
UNION ALL SELECT 'sum loss_rate',
          ABS((SELECT SUM(loss_rate_pct) FROM loss_rate) - (SELECT SUM(CAST(c2 AS REAL)) FROM raw_loss_rate)) > 1e-6
UNION ALL SELECT 'orphelins loss_rate', COUNT(*) FROM loss_rate WHERE item_code NOT IN (SELECT item_code FROM product)
UNION ALL SELECT 'articles sans loss_rate', COUNT(*) FROM product WHERE item_code NOT IN (SELECT item_code FROM loss_rate);
```

### Lignes signalées, non modifiées (CREATE VIEW)

```sql
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
```

## price

Fichier : `sql/price.sql`

### Schéma (CREATE TABLE)

```sql
CREATE TABLE price (
    price_date       DATE          NOT NULL,
    item_code        INTEGER       NOT NULL REFERENCES product (item_code),
    wholesale_price  DECIMAL(10,2) NOT NULL CHECK (wholesale_price > 0),
    PRIMARY KEY (price_date, item_code)
);
CREATE INDEX idx_price_item ON price (item_code);
```

### Nettoyage (INSERT ... SELECT depuis les données brutes)

```sql
-- TODO : chargement brut, sans nettoyage. Documenter ici chaque correction ajoutée.
INSERT INTO price (price_date, item_code, wholesale_price)
SELECT c0, CAST(c1 AS INTEGER), CAST(c2 AS REAL)
FROM raw_price;
```

### Contrôles (écart attendu = 0)

_À compléter._

### Lignes signalées, non modifiées (CREATE VIEW)

_À compléter._

## transaction

Fichier : `sql/transaction.sql`

### Schéma (CREATE TABLE)

```sql
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
```

### Nettoyage (INSERT ... SELECT depuis les données brutes)

```sql
-- TODO : chargement brut, sans nettoyage. Documenter ici chaque correction ajoutée.
INSERT INTO "transaction" (sale_date, sale_time, item_code, quantity_sold_kg, unit_selling_price, sale_or_return, discount)
SELECT c0, c1, CAST(c2 AS INTEGER), CAST(c3 AS REAL), CAST(c4 AS REAL), c5, c6
FROM raw_transaction
ORDER BY rowid;
```

### Contrôles (écart attendu = 0)

_À compléter._

### Lignes signalées, non modifiées (CREATE VIEW)

_À compléter._
