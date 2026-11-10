"""Construit build/veg.db : chargement brut -> sql/<table>.sql (schema, clean) -> contrôles -> vues de signalement.
Usage : python3 scripts/build.py            (CSV attendus dans data/)
Sortie : build/veg.db ; code retour 1 si un contrôle (section @checks) n'est pas à 0.

Chaque fichier sql/<table>.sql contient les sections @schema, @clean, @checks, @flags.
Ordre : tous les @schema + @clean (dans l'ordre des dépendances), puis tous les @checks, puis tous les @flags."""
import pathlib
import re
import sqlite3
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
DB = ROOT / "build" / "veg.db"
SQL = ROOT / "sql"
TABLES = ["product", "loss_rate", "price", "transaction"]  # ordre des clés étrangères


def sections(table):
    """Découpe sql/<table>.sql selon les marqueurs '-- @nom'."""
    parts = re.split(r"^-- @(\w+)[^\n]*\n", (SQL / f"{table}.sql").read_text(encoding="utf-8"), flags=re.M)
    return dict(zip(parts[1::2], parts[2::2]))


def main():
    subprocess.run([sys.executable, "-I", str(ROOT / "scripts" / "load_raw.py"), str(ROOT / "data"), str(DB)], check=True)
    con = sqlite3.connect(DB)
    con.execute("PRAGMA foreign_keys = ON")
    secs = {t: sections(t) for t in TABLES}

    print()
    for t in TABLES:
        for name in ("schema", "clean"):
            start = time.time()
            con.executescript(secs[t].get(name, ""))
            con.commit()
            print(f"{t + '.' + name:<22} ok  ({time.time() - start:.1f} s)")

    print("\nContrôles (écart attendu = 0)")
    failed = 0
    for t in TABLES:
        lines = secs[t].get("checks", "").splitlines()
        body = "\n".join(l for l in lines if not l.strip().startswith("--")).strip()
        if not body:
            print(f"  --  {t}: aucun contrôle défini")
            continue
        for nom, ecart in con.execute(body):
            failed += ecart != 0
            print(f"  {'OK ' if ecart == 0 else 'KO '} {nom:<38} {ecart}")
    if failed:
        print(f"\n{failed} contrôle(s) en échec")
        sys.exit(1)

    for t in TABLES:
        con.executescript(secs[t].get("flags", ""))
    con.commit()
    print("\nLignes signalées (non modifiées)")
    for (v,) in con.execute("SELECT name FROM sqlite_master WHERE type='view' ORDER BY name").fetchall():
        print(f"  {v:<34} {con.execute(f'SELECT COUNT(*) FROM {v}').fetchone()[0]}")
    print("\nFK violations :", con.execute("PRAGMA foreign_key_check").fetchall())


if __name__ == "__main__":
    main()
