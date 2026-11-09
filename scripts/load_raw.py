"""Charge les 4 CSV tels quels (colonnes TEXT) dans des tables raw_* d'une base SQLite.
Usage : python3 scripts/load_raw.py data/ build/veg.db
Aucune transformation ici : le nettoyage se fait en SQL (sql/02_clean.sql)."""
import csv, sqlite3, sys, pathlib

data, db = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
db.parent.mkdir(parents=True, exist_ok=True)
if db.exists():
    db.unlink()
con = sqlite3.connect(db)
for name in ("product", "loss_rate", "price", "transaction"):
    with open(data / f"{name}.csv", newline="", encoding="utf-8") as f:
        r = csv.reader(f)
        header = next(r)
        cols = [f"c{i}" for i in range(len(header))]
        con.execute(f'CREATE TABLE raw_{name} ({", ".join(c + " TEXT" for c in cols)})')
        con.executemany(
            f'INSERT INTO raw_{name} VALUES ({",".join("?" * len(cols))})',
            (row for row in r if row),
        )
    print(name, header, con.execute(f"select count(*) from raw_{name}").fetchone()[0])
con.commit()
