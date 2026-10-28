#!/usr/bin/env python3
"""Verify the four public HTTPS binaries, using metadata from the local Git kit."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASE = "https://jb-static-files-177862772785-sa-east-1-an.s3.sa-east-1.amazonaws.com/dev-env"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base_url", nargs="?", default=os.environ.get("S3_BASE_URL", DEFAULT_BASE))
    args = parser.parse_args()
    base = args.base_url.rstrip("/")
    if not base.startswith("https://"):
        raise RuntimeError("Public verification requires HTTPS")
    records = json.loads((ROOT / "artifacts/manifest.json").read_text(encoding="utf-8"))["artifacts"]

    def artifact(record):
        relative = record["path"]
        checksum, size = hashlib.sha256(), 0
        with urllib.request.urlopen(f"{base}/{relative}", timeout=180) as response:
            if response.headers.get("x-amz-server-side-encryption") != "AES256":
                raise RuntimeError(f"Unexpected server-side encryption: {relative}")
            while chunk := response.read(1024 * 1024):
                checksum.update(chunk)
                size += len(chunk)
        if size != record["size_bytes"] or checksum.hexdigest() != record["sha256"]:
            raise RuntimeError(f"Public artifact SHA-256/size mismatch: {relative}")
        print(f"SHA256 OK: {relative} ({size} bytes)", flush=True)

    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(artifact, records))
    print(f"Verified {len(records)} public binaries; all SHA-256 hashes match the local Git catalog", flush=True)


if __name__ == "__main__":
    main()
