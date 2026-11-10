"""Génère docs/COMMANDES.md : journal des commandes SQL utilisées, extrait de sql/<table>.sql (toujours synchrone).
Usage : python3 scripts/make_log.py"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
TABLES = ["product", "loss_rate", "price", "transaction"]
TITLES = {
    "schema": "Schéma (CREATE TABLE)",
    "clean": "Nettoyage (INSERT ... SELECT depuis les données brutes)",
    "checks": "Contrôles (écart attendu = 0)",
    "flags": "Lignes signalées, non modifiées (CREATE VIEW)",
}

out = [
    "# Commandes SQL utilisées",
    "",
    "Journal généré par `scripts/make_log.py` à partir de `sql/<table>.sql`. Ne pas éditer à la main : modifier le fichier SQL puis relancer le script.",
    "Les tables `raw_*` sont la copie fidèle des CSV (colonnes TEXT `c0`, `c1`, ...). Dialecte SQLite.",
    "",
]
for t in TABLES:
    parts = re.split(r"^-- @(\w+)[^\n]*\n", (ROOT / "sql" / f"{t}.sql").read_text(encoding="utf-8"), flags=re.M)
    secs = dict(zip(parts[1::2], parts[2::2]))
    out += [f"## {t}", "", f"Fichier : `sql/{t}.sql`", ""]
    for name in ("schema", "clean", "checks", "flags"):
        body = secs.get(name, "").strip()
        has_sql = any(l.strip() and not l.strip().startswith("--") for l in body.splitlines())
        out += [f"### {TITLES[name]}", ""]
        out += ["```sql", body, "```", ""] if has_sql else ["_À compléter._", ""]
(ROOT / "docs" / "COMMANDES.md").write_text("\n".join(out), encoding="utf-8")
print("docs/COMMANDES.md")
