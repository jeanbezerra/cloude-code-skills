#!/usr/bin/env python3
"""Rehash local downloads and build the portable S3 catalog."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    records = []
    for metadata, product in [("cli-downloads.json", "claude-code"), ("desktop-downloads.json", "claude-desktop")]:
        for original in json.loads((ROOT / "artifacts" / metadata).read_text(encoding="utf-8"))["artifacts"]:
            record = dict(original, product_id=product)
            target = ROOT / record["path"]
            with target.open("rb") as source:
                checksum = hashlib.file_digest(source, "sha256").hexdigest()
            if checksum != record["sha256"] or target.stat().st_size != record["size_bytes"]:
                raise RuntimeError(f"Local download does not match metadata: {target}")
            records.append(record)
    catalog = "".join(f'{r["product_id"]}|{r["platform"]}|{r["path"]}|{r["sha256"]}\n' for r in records)
    (ROOT / "artifacts/catalog.txt").write_text(catalog, encoding="ascii", newline="")
    (ROOT / "artifacts/SHA256SUMS").write_text("".join(f'{r["sha256"]}  {r["path"]}\n' for r in records), encoding="ascii", newline="")
    (ROOT / "artifacts/manifest.json").write_text(json.dumps({"artifacts": records}, indent=2) + "\n", encoding="utf-8")
    print(f"Catalog ready: {len(records)} artifacts; {sum(r['size_bytes'] for r in records):,} bytes")


if __name__ == "__main__":
    main()
