# vegetable-sales-sql

Nettoyage en SQL de quatre exports CSV : catalogue de légumes, taux de perte, prix de gros journaliers et transactions de vente (2020-07-01 au 2023-06-30).

## Contenu

| Chemin | Rôle |
|---|---|
| `data/product.csv`, `loss_rate.csv`, `price.csv` | Données sources (251, 251 et 55 982 lignes) |
| `data/transaction.csv` | Source de 878 503 lignes, **non versionnée** (51,8 Mo, voir ci-dessous) |
| `sql/01_schema.sql` | Tables typées, clés, contraintes `CHECK` |
| `sql/02_clean.sql` | Nettoyage : `raw_*` vers tables propres |
| `sql/03_checks.sql` | 16 contrôles, écart attendu égal à 0 |
| `sql/04_flags.sql` | 9 vues listant les lignes à arbitrer |
| `scripts/` | Chargement brut, orchestration, génération de la page |
| `docs/tables.html` | Visualisation : relations, schéma, aperçu, signalements (page autonome, à ouvrir dans un navigateur) |

## Utilisation

```bash
# placer transaction.csv dans data/
python3 scripts/build.py      # produit build/veg.db (SQLite, environ 5 s)
python3 scripts/make_viz.py   # régénère docs/tables.html
```

Python 3 standard, aucune dépendance. Le build échoue (code 1) si un contrôle de `03_checks.sql` n'est pas à 0.

## Modèle

```
product (item_code PK, item_name, category_code, category_name)
  ├─ 1:1  loss_rate   (item_code PK/FK, loss_rate_pct)
  ├─ 1:N  price       (price_date + item_code PK, wholesale_price)
  └─ 1:N  transaction (transaction_id PK, sale_date, sale_time, item_code FK,
                       quantity_sold_kg, unit_selling_price, sale_or_return, discount)
```

Prix en RMB/kg, quantités en kg. `quantity_sold_kg` est négative pour un retour.

## Règles de nettoyage (déterministes, sans perte)

Aucune ligne n'est supprimée. Les sommes des colonnes numériques sont identiques avant et après (contrôle 03).

- `product` : espaces de bord et doubles espaces retirés (6 libellés) ; espace insécable U+00A0 remplacée par une espace dans `category_name` (100 lignes).
- `loss_rate` : espace finale retirée de la valeur (251 lignes), conversion texte vers nombre. La colonne `item_name` n'est pas reprise : identique à celle de `product` (0 écart sur 251).
- `transaction` : l'export a supprimé les zéros finaux des millisecondes (`09:23:08.96` pour `.960`, `09:31:37` pour `.000`, 18 841 lignes). Complété à `HH:MM:SS.mmm`. L'heure est numériquement inchangée (0 écart vérifié sur les 878 503 lignes).
- Contraintes ajoutées parce que vérifiées sur les données : prix > 0, `loss_rate_pct` entre 0 et 100, vente = quantité positive et retour = quantité négative (461 retours, tous négatifs).

## Lignes signalées, non modifiées (`sql/04_flags.sql`)

Elles relèvent d'un jugement métier. Les seuils sont des heuristiques de travail.

| Vue | Lignes | Observation |
|---|---|---|
| `v_flag_loss_rate_default` | 85 | Taux de perte égal à 9,43. La moyenne arrondie des 166 autres valeurs vaut 9,425. **Hypothèse** : valeur imputée par la moyenne, non mesurée. Non démontré. |
| `v_flag_loss_rate_zero` | 22 | Taux nul : mesure réelle ou donnée manquante, non tranchable. |
| `v_flag_product_duplicate_name` | 4 | Même libellé, codes différents. |
| `v_flag_product_unsold` | 5 | Articles sans transaction. |
| `v_flag_price_extreme` | 323 | Prix de gros à plus de 5x ou moins de 1/5 de la moyenne de l'article (3 hauts, 320 bas). Prix minimal observé 0,01 RMB/kg. |
| `v_flag_tx_qty_outlier` | 56 | Quantité d'au moins 10 kg. Maximum : 160 kg d'un article à 5,9 RMB/kg. |
| `v_flag_tx_below_wholesale` | 12 651 | Vente sous le prix de gros du jour (dont 3 356 hors remise). |
| `v_flag_tx_return_without_sale` | 4 | Retour sans vente du même article le même jour. |
| `v_flag_tx_same_timestamp` | 2 | Deux ventes à la même milliseconde, quantités différentes : pas un doublon. |

## Choix de versionnement

`data/transaction.csv` (51,8 Mo) dépasse le seuil d'avertissement de GitHub (50 Mo) et se régénère depuis la source : il est exclu par `.gitignore`. La base `build/veg.db` l'est aussi.
