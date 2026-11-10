# vegetable-sales-sql

Mini-exercice : nettoyer en SQL quatre exports CSV (catalogue de légumes, taux de perte, prix de gros journaliers, transactions de vente, du 2020-07-01 au 2023-06-30), à trois, avec Git.

## Répartition

| Table | Source | Lignes | Branche | Contributeur | État |
|---|---|---|---|---|---|
| `product` | `data/product.csv` | 251 | `feature/product-loss_rate` | à renseigner | fait |
| `loss_rate` | `data/loss_rate.csv` | 251 | `feature/product-loss_rate` | à renseigner | fait |
| `price` | `data/price.csv` | 55 982 | `feature/price` | à renseigner | à compléter |
| `transaction` | `data/transaction.csv` | 878 503 | `feature/transaction` | à renseigner | à compléter |

Les constats de départ sur chaque table sont dans [docs/PROFILAGE.md](docs/PROFILAGE.md).

## Branches

```
main                        version stable, mise à jour par fusion depuis dev uniquement
dev                         intégration des trois features
feature/product-loss_rate   product + loss_rate
feature/price               price
feature/transaction         transaction
```

Workflow :

```bash
git clone <url> && cd vegetable-sales-sql
git checkout feature/<votre-branche>
# éditer UNIQUEMENT votre fichier sql/<table>.sql, puis :
python3 scripts/build.py             # doit finir sans "contrôle(s) en échec"
git add sql/<table>.sql && git commit -m "price : contrôles et signalements"
git push -u origin feature/<votre-branche>
# ouvrir une Pull Request vers dev ; une relecture par un autre membre avant fusion
```

Règles pour éviter les conflits de fusion :

- Chacun ne modifie que son fichier `sql/<table>.sql`. Les sections `@schema`, `@clean`, `@checks`, `@flags` sont lues par `scripts/build.py`.
- Ne pas modifier `scripts/`, ce README ni `docs/` dans une branche feature. Les fichiers de `docs/` sont générés : après fusion dans `dev`, une seule personne lance `python3 scripts/make_viz.py && python3 scripts/make_log.py` et commite le résultat.
- Fusion `dev` vers `main` quand les trois features sont intégrées et que `build.py` passe sur `dev`.

## Utilisation

```bash
# placer transaction.csv dans data/ (non versionné : 51,8 Mo, à échanger hors de Git)
python3 scripts/build.py      # produit build/veg.db (SQLite, environ 5 s)
python3 scripts/make_viz.py   # régénère docs/tables.html (visualisation des tables)
python3 scripts/make_log.py   # régénère docs/COMMANDES.md (journal des commandes SQL)
```

Python 3 standard, aucune dépendance. Le build échoue (code 1) si un contrôle `@checks` n'est pas à 0.

## Contenu

| Chemin | Rôle |
|---|---|
| `sql/<table>.sql` | Un fichier par table : schéma, nettoyage, contrôles, vues de signalement |
| `scripts/load_raw.py` | Charge les CSV tels quels dans des tables `raw_*` (colonnes TEXT) |
| `scripts/build.py` | Exécute les sections de `sql/*.sql` dans l'ordre des clés étrangères |
| `docs/tables.html` | Visualisation : relations, schéma, aperçu des données, lignes signalées (page autonome) |
| `docs/COMMANDES.md` | Journal des commandes SQL utilisées, extrait des fichiers SQL |
| `docs/PROFILAGE.md` | Constats de qualité des données avant nettoyage |

## Modèle

```
product (item_code PK, item_name, category_code, category_name)
  ├─ 1:1  loss_rate   (item_code PK/FK, loss_rate_pct)
  ├─ 1:N  price       (price_date + item_code PK, wholesale_price)
  └─ 1:N  transaction (transaction_id PK, sale_date, sale_time, item_code FK,
                       quantity_sold_kg, unit_selling_price, sale_or_return, discount)
```

Prix en RMB/kg, quantités en kg. `quantity_sold_kg` est négative pour un retour.

## Principe de nettoyage

- Corriger seulement ce qui est déterministe et sans perte (types, espaces, formats). Aucune ligne supprimée.
- Signaler dans des vues `v_flag_*` tout ce qui relève d'un jugement métier. Les seuils sont des heuristiques.
- Chaque table a ses contrôles `@checks` : écart attendu égal à 0 (nombre de lignes, sommes conservées, orphelins).
