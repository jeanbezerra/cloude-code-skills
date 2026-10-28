#!/usr/bin/env python3
"""Maintainer-only: download pinned native CLI binaries, without installing."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://downloads.claude.ai/claude-code-releases"


def request(url):
    return urllib.request.urlopen(url, timeout=120)


def main():
    with request(f"{BASE}/stable") as response:
        version = response.read().decode().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise RuntimeError(f"Invalid upstream version: {version!r}")
    with request(f"{BASE}/{version}/manifest.json") as response:
        raw_manifest = response.read()
    manifest = json.loads(raw_manifest)
    upstream = ROOT / "upstream"
    upstream.mkdir(exist_ok=True)
    (upstream / f"claude-code-{version}-manifest.json").write_bytes(raw_manifest)

    def download(platform):
        upstream_platform = "win32-x64" if platform == "windows-x64" else platform
        filename = "claude.exe" if platform == "windows-x64" else "claude"
        extension = ".exe" if platform == "windows-x64" else ""
        expected = manifest["platforms"][upstream_platform]
        relative = f"artifacts/claude-code/{version}/{platform}/claude-code-{version}-{platform}{extension}"
        target = ROOT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        partial = target.with_suffix(target.suffix + ".part")
        digest = hashlib.sha256()
        size = 0
        url = f"{BASE}/{version}/{upstream_platform}/{filename}"
        with request(url) as response, partial.open("wb") as output:
            resolved = response.geturl()
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
                digest.update(chunk)
                size += len(chunk)
        checksum = digest.hexdigest()
        if checksum != expected["checksum"] or size != expected["size"]:
            partial.unlink(missing_ok=True)
            raise RuntimeError(f"Upstream checksum/size mismatch: {platform}")
        partial.replace(target)
        return dict(product="Claude Code CLI", product_id="claude-code", platform=platform,
                    version=version, channel="stable", path=relative, source_url=url,
                    resolved_url=resolved, sha256=checksum, size_bytes=size,
                    official_sha256=expected["checksum"],
                    official_manifest_url=f"{BASE}/{version}/manifest.json")

    with ThreadPoolExecutor(max_workers=2) as pool:
        records = list(pool.map(download, ["windows-x64", "linux-x64"]))
    (ROOT / "artifacts/cli-downloads.json").write_text(json.dumps(dict(
        downloaded_at_utc=datetime.now(timezone.utc).isoformat(), artifacts=records,
        official_documentation=["https://code.claude.com/docs/en/setup"]
    ), indent=2) + "\n", encoding="utf-8")
    for record in records:
        print(f'{record["platform"]}: {version}, {record["size_bytes"]} bytes, SHA256 verified', flush=True)


if __name__ == "__main__":
    main()
