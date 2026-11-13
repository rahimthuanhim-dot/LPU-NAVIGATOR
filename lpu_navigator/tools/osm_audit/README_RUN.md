# OSM audit

From a clean checkout, run these commands from `tools/osm_audit`:

```powershell
# Requires Python 3.10 or newer; this example uses Python 3.11.
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe audit.py
```

The command performs the live Overpass audit and must have internet access.
It prints the boundary decision and element count for every query, then writes
`REPORT.md` and `out\audit.geojson`.

The script uses only the public Overpass API and the Python standard library.
It writes timestamped raw responses under `raw/`, the complete analysis to
`REPORT.md`, and an unverified GeoJSON export to `out/audit.geojson`.

The Overpass endpoint, timeout, and retry count can be overridden for
diagnostic runs:

```powershell
.\.venv\Scripts\python.exe audit.py --endpoint https://overpass-api.de/api/interpreter --timeout 180
```

Before running the audit, verify that the interpreter has HTTPS support:

```powershell
.\.venv\Scripts\python.exe -c "import sys, ssl, urllib.request; print(sys.version); print(ssl.OPENSSL_VERSION); print(urllib.request.HTTPSHandler)"
```

The command must report Python 3.10 or newer, an OpenSSL version, and an
`HTTPSHandler` class.
