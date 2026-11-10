"""Génère docs/tables.html (page autonome, sans dépendance externe) à partir de build/veg.db.
Usage : python3 scripts/make_viz.py   (après scripts/build.py)"""
import json
import pathlib
import sqlite3

ROOT = pathlib.Path(__file__).resolve().parent.parent
con = sqlite3.connect(ROOT / "build" / "veg.db")
con.row_factory = sqlite3.Row

TABLES = ["product", "loss_rate", "price", "transaction"]
PREVIEW_ROWS = {"product": None, "loss_rate": None, "price": 100, "transaction": 100}  # None = tout

FLAG_DOC = {
    "v_flag_loss_rate_default": ("loss_rate", "Taux de perte égal à 9,43 : moyenne arrondie des autres valeurs. Hypothèse : valeur imputée, non mesurée."),
    "v_flag_loss_rate_zero": ("loss_rate", "Taux de perte nul : mesure réelle ou donnée manquante, non tranchable."),
    "v_flag_product_duplicate_name": ("product", "Même libellé pour plusieurs codes : produits distincts ou doublon."),
    "v_flag_product_unsold": ("product", "Article du catalogue sans aucune transaction."),
    "v_flag_price_extreme": ("price", "Prix de gros à plus de 5x ou moins de 1/5 de la moyenne de l'article."),
    "v_flag_tx_qty_outlier": ("transaction", "Quantité unitaire d'au moins 10 kg (seuil arbitraire)."),
    "v_flag_tx_below_wholesale": ("transaction", "Vente à un prix inférieur au prix de gros du même jour."),
    "v_flag_tx_return_without_sale": ("transaction", "Retour sans vente du même article le même jour."),
    "v_flag_tx_same_timestamp": ("transaction", "Même (date, heure, article) sur 2 lignes : deux ventes distinctes à la milliseconde."),
}

STATS_SQL = {
    "product": [
        ("Catégories", "SELECT COUNT(DISTINCT category_code) FROM product"),
    ],
    "loss_rate": [
        ("Min (%)", "SELECT MIN(loss_rate_pct) FROM loss_rate"),
        ("Max (%)", "SELECT MAX(loss_rate_pct) FROM loss_rate"),
        ("Moyenne (%)", "SELECT ROUND(AVG(loss_rate_pct), 2) FROM loss_rate"),
    ],
    "price": [
        ("Du", "SELECT MIN(price_date) FROM price"),
        ("Au", "SELECT MAX(price_date) FROM price"),
        ("Jours distincts", "SELECT COUNT(DISTINCT price_date) FROM price"),
        ("Prix min (RMB/kg)", "SELECT MIN(wholesale_price) FROM price"),
        ("Prix max (RMB/kg)", "SELECT MAX(wholesale_price) FROM price"),
    ],
    "transaction": [
        ("Du", 'SELECT MIN(sale_date) FROM "transaction"'),
        ("Au", 'SELECT MAX(sale_date) FROM "transaction"'),
        ("Ventes", "SELECT COUNT(*) FROM \"transaction\" WHERE sale_or_return = 'sale'"),
        ("Retours", "SELECT COUNT(*) FROM \"transaction\" WHERE sale_or_return = 'return'"),
        ("Avec remise", "SELECT COUNT(*) FROM \"transaction\" WHERE discount = 'Yes'"),
    ],
}


def table_meta(t):
    cols = con.execute(f'PRAGMA table_info("{t}")').fetchall()
    fks = {r["from"]: f'{r["table"]}.{r["to"]}' for r in con.execute(f'PRAGMA foreign_key_list("{t}")')}
    return [
        {"name": c["name"], "type": (c["type"] or "").lower(), "pk": bool(c["pk"]), "fk": fks.get(c["name"])}
        for c in cols
    ]


data = {"tables": {}, "flags": []}
for t in TABLES:
    q = f'SELECT * FROM "{t}"'
    lim = PREVIEW_ROWS[t]
    if lim:
        q += f" LIMIT {lim}"
    rows = [list(r) for r in con.execute(q)]
    total = con.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
    data["tables"][t] = {
        "columns": table_meta(t),
        "total": total,
        "rows": rows,
        "stats": [[label, con.execute(sql).fetchone()[0]] for label, sql in STATS_SQL[t]],
    }
existing = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='view'")}
for v, (tbl, desc) in FLAG_DOC.items():
    if v not in existing:  # vue pas encore écrite par le contributeur de la table
        continue
    data["flags"].append({"view": v, "table": tbl, "rows": con.execute(f"SELECT COUNT(*) FROM {v}").fetchone()[0], "desc": desc})

payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
html = (ROOT / "scripts" / "tables_template.html").read_text(encoding="utf-8").replace("/*__DATA__*/null", payload)
out = ROOT / "docs" / "tables.html"
out.parent.mkdir(exist_ok=True)
out.write_text(html, encoding="utf-8")
print(f"{out} ({out.stat().st_size / 1024:.0f} Ko)")
