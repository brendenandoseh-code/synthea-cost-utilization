"""
build.py — end-to-end pipeline for the Synthea cost & utilization analysis.

Loads the raw Synthea CSVs (data/) into SQLite, builds the cleaning views
(sql/01_create_and_load.sql), runs the analysis queries (sql/02_analysis.sql),
and writes one Tableau-ready CSV per query into outputs/. Standard library only.

Usage:  py build.py     (run from this folder, with data/ populated — see README)
"""
import csv, os, re, sqlite3, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
OUT  = os.path.join(HERE, "outputs")
DB   = os.path.join(HERE, "synthea.db")

# Only the tables the analysis needs (the full Synthea export has ~18 files).
TABLES = ["patients", "encounters", "conditions", "payers", "claims_transactions"]


def load_csv(con, table):
    path = os.path.join(DATA, table + ".csv")
    if not os.path.exists(path):
        sys.exit(f"Missing {path} — download the Synthea sample data into data/ (see README).")
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        cols = [re.sub(r"\W", "_", c) for c in header]
        con.execute(f"DROP TABLE IF EXISTS {table}")
        con.execute(f"CREATE TABLE {table} ({', '.join(c + ' TEXT' for c in cols)})")
        con.executemany(
            f"INSERT INTO {table} VALUES ({', '.join('?' * len(cols))})", reader
        )
    con.commit()
    n = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    print(f"  loaded {table:<20} {n:>7,} rows")


def run_analysis(con):
    os.makedirs(OUT, exist_ok=True)
    sql = open(os.path.join(HERE, "sql", "02_analysis.sql"), encoding="utf-8").read()
    # Split on "-- >>> <filename>" marker lines; capture the filename.
    parts = re.split(r"(?m)^[ \t]*--\s*>>>\s*(\S+)[ \t]*$", sql)
    for name, block in zip(parts[1::2], parts[2::2]):
        query = block.split(";", 1)[0].strip()   # the SELECT, up to its semicolon
        if not query:
            continue
        cur = con.execute(query)
        headers = [d[0] for d in cur.description]
        rows = cur.fetchall()
        with open(os.path.join(OUT, name), "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(headers)
            w.writerows(rows)
        print(f"  outputs/{name:<28} {len(rows):>4} rows")


def findings(con):
    q = lambda s: con.execute(s).fetchone()
    total, covered = q("SELECT ROUND(SUM(total_cost)), ROUND(SUM(payer_coverage)) FROM enc")
    print("\n================ KEY FINDINGS ================\n")
    print(f"Patients: {q('SELECT COUNT(*) FROM patients')[0]}  |  "
          f"Encounters: {q('SELECT COUNT(*) FROM encounters')[0]:,}  |  "
          f"Claim transactions: {q('SELECT COUNT(*) FROM claims_transactions')[0]:,}")
    print(f"Total billed (encounter cost): ${total:,.0f}  |  Payer-covered: "
          f"{100*covered/total:.0f}%  |  Patient responsibility: {100*(total-covered)/total:.0f}%")

    print("\nSpend by site of care (top 3):")
    for cls, cost, pct in con.execute(
        "SELECT encounter_class, ROUND(SUM(total_cost)), "
        "ROUND(100.0*SUM(total_cost)/(SELECT SUM(total_cost) FROM enc),1) "
        "FROM enc GROUP BY encounter_class ORDER BY 2 DESC LIMIT 3"):
        print(f"  {cls:<12} ${cost:>12,.0f}  ({pct}% of spend)")

    # High-cost concentration: share of total cost held by the costliest 10% of patients.
    n = q("SELECT COUNT(*) FROM patient_cost")[0]
    top = max(1, round(n * 0.10))
    share = q(f"SELECT ROUND(100.0*SUM(total_cost)/(SELECT SUM(total_cost) FROM patient_cost),1) "
              f"FROM (SELECT total_cost FROM patient_cost ORDER BY total_cost DESC LIMIT {top})")[0]
    print(f"\nCost concentration: the costliest {top} patients ({100*top//n}%) account for {share}% of total cost.")

    charged, paid, lines = q("SELECT "
        "SUM(CASE WHEN TYPE='CHARGE' THEN CAST(NULLIF(AMOUNT,'') AS REAL) ELSE 0 END), "
        "SUM(CAST(NULLIF(PAYMENTS,'') AS REAL)), "
        "SUM(CASE WHEN TYPE='CHARGE' THEN 1 ELSE 0 END) FROM claims_transactions")
    print(f"Claim lines: {lines:,} charge transactions totaling ${charged:,.0f}; in this synthetic "
          f"data charges fully reconcile to payments ({100*paid/charged:.0f}%, split payer + patient).")
    print("\nDone. Connect Tableau to the files in outputs/.")


def main():
    if os.path.exists(DB):
        os.remove(DB)
    con = sqlite3.connect(DB)
    print("Loading Synthea CSVs into SQLite...")
    for t in TABLES:
        load_csv(con, t)
    con.executescript(open(os.path.join(HERE, "sql", "01_create_and_load.sql"), encoding="utf-8").read())
    print("Writing analysis outputs...")
    run_analysis(con)
    findings(con)
    con.close()


if __name__ == "__main__":
    main()
