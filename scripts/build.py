"""Construit build/veg.db : chargement brut -> schéma -> nettoyage -> contrôles -> vues de signalement.
Usage : python3 scripts/build.py            (CSV attendus dans data/)
Sortie : build/veg.db ; code retour 1 si un contrôle de sql/03_checks.sql n'est pas à 0."""
import pathlib
import sqlite3
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
DB = ROOT / "build" / "veg.db"
SQL = ROOT / "sql"


def run_script(con, name):
    t = time.time()
    con.executescript((SQL / name).read_text(encoding="utf-8"))
    con.commit()
    print(f"{name:<14} ok  ({time.time() - t:.1f} s)")


def main():
    subprocess.run([sys.executable, "-I", str(ROOT / "scripts" / "load_raw.py"), str(ROOT / "data"), str(DB)], check=True)
    con = sqlite3.connect(DB)
    con.execute("PRAGMA foreign_keys = ON")
    run_script(con, "01_schema.sql")
    run_script(con, "02_clean.sql")

    print("\nContrôles (écart attendu = 0)")
    failed = 0
    for name, ecart in con.execute((SQL / "03_checks.sql").read_text(encoding="utf-8")):
        flag = "OK " if ecart == 0 else "KO "
        failed += ecart != 0
        print(f"  {flag} {name:<38} {ecart}")
    if failed:
        print(f"\n{failed} contrôle(s) en échec")
        sys.exit(1)

    run_script(con, "04_flags.sql")
    print("\nLignes signalées (non modifiées)")
    views = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='view' ORDER BY name")]
    for v in views:
        print(f"  {v:<34} {con.execute(f'SELECT COUNT(*) FROM {v}').fetchone()[0]}")
    print("\nFK violations :", con.execute("PRAGMA foreign_key_check").fetchall())


if __name__ == "__main__":
    main()
