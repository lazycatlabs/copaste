#!/usr/bin/env python3
"""Moves Raycast's clipboard history into a Copaste vault.

Raycast keeps its history in an SQLCipher-encrypted database whose key is in your Keychain
(service "Raycast", account "database_key"). This script reads the key (macOS asks you to allow it),
works on a temporary copy of the database, and never changes Raycast's files.

Needs:  brew install sqlcipher

Step 1, show the database's structure (table and column names only, no clipboard contents):
    python3 scripts/import_raycast.py --inspect
"""
import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RAYCAST = Path.home() / "Library/Application Support/com.raycast.macos"
DATABASE = "clipboard.db"


def keychain_key():
    result = subprocess.run(
        ["security", "find-generic-password", "-s", "Raycast", "-a", "database_key", "-w"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        sys.exit("Couldn't read Raycast's database key from the Keychain (was access denied?).")
    return result.stdout.strip()


def temporary_copy():
    folder = Path(tempfile.mkdtemp(prefix="copaste-raycast-"))
    for suffix in ("", "-wal", "-shm"):
        source = RAYCAST / (DATABASE + suffix)
        if source.exists():
            shutil.copy2(source, folder / source.name)
    return folder


def run_sql(database, unlock, sql):
    """Runs SQL with sqlcipher; returns stdout, or None if the database didn't open with this key setup."""
    script = f"{unlock}\n.mode list\n{sql}\n"
    result = subprocess.run(["sqlcipher", str(database)], input=script, capture_output=True, text=True)
    out = "\n".join(line for line in result.stdout.splitlines() if line != "ok")
    if result.returncode != 0 or "file is not a database" in result.stderr or not out.strip():
        return None
    return out


def unlock_statement(database, key):
    """Raycast's exact SQLCipher settings aren't documented, so try the usual ones."""
    candidates = []
    for key_form in (f"PRAGMA key = '{key}';", f"PRAGMA key = \"x'{key}'\";"):
        for compatibility in ("", "PRAGMA cipher_compatibility = 3;", "PRAGMA cipher_compatibility = 4;"):
            candidates.append(f"{key_form} {compatibility}".strip())
    for unlock in candidates:
        if run_sql(database, unlock, "SELECT count(*) FROM sqlite_master;"):
            return unlock
    sys.exit("The key didn't open the database with any known SQLCipher setting.")


def inspect(database, unlock):
    """Prints table definitions and row counts. No clipboard contents are printed."""
    tables = run_sql(database, unlock, "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name;") or ""
    print(f"Opened with: {unlock.split(';', 1)[1].strip() or 'default settings'} "
          f"({'raw hex key' if 'x' in unlock.split(';')[0] else 'passphrase'})\n")
    for table in tables.splitlines():
        schema = run_sql(database, unlock, f"SELECT sql FROM sqlite_master WHERE name = '{table}';")
        count = run_sql(database, unlock, f"SELECT count(*) FROM \"{table}\";")
        print(f"-- {table}: {count} rows\n{schema}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--inspect", action="store_true", help="show tables and columns only")
    args = parser.parse_args()
    if not shutil.which("sqlcipher"):
        sys.exit("Install SQLCipher first:  brew install sqlcipher")
    if not args.inspect:
        sys.exit("Run with --inspect first; the import step is added once the structure is known.")
    folder = temporary_copy()
    try:
        database = folder / DATABASE
        inspect(database, unlock_statement(database, keychain_key()))
    finally:
        shutil.rmtree(folder)


if __name__ == "__main__":
    main()
