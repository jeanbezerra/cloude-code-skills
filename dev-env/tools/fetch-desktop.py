#!/usr/bin/env python3
"""Refresh official Claude Desktop x64 packages (maintainer tool; Python 3 only)."""

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
import zipfile


ROOT = Path(__file__).resolve().parents[1]
APT_BASE = "https://downloads.claude.ai/claude-desktop/apt/stable/"
APT_INDEX = APT_BASE + "dists/stable/main/binary-amd64/Packages"
WINDOWS_URL = "https://claude.ai/api/desktop/win32/x64/msix/latest/redirect"


def request(url):
    return urllib.request.urlopen(
        urllib.request.Request(url, headers={"User-Agent": "Claude-Desktop-Mirror/1.0"}),
        timeout=90,
    )


def download(url, relative_path, expected_sha256=None, expected_size=None):
    target = ROOT / relative_path
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(target.suffix + ".part")
    digest = hashlib.sha256()
    size = 0
    with request(url) as source, partial.open("wb") as destination:
        resolved = source.geturl()
        while chunk := source.read(1024 * 1024):
            destination.write(chunk)
            digest.update(chunk)
            size += len(chunk)
    actual_sha256 = digest.hexdigest()
    if expected_size is not None and size != expected_size:
        raise RuntimeError(f"Size mismatch for {relative_path}: {size} != {expected_size}")
    if expected_sha256 and actual_sha256 != expected_sha256:
        raise RuntimeError(f"SHA-256 mismatch for {relative_path}")
    partial.replace(target)
    return {
        "product": "Claude Desktop (includes Claude Code)",
        "product_id": "claude-desktop",
        "path": relative_path,
        "source_url": url,
        "resolved_url": resolved,
        "size_bytes": size,
        "sha256": actual_sha256,
    }


def windows():
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(parents=True, exist_ok=True)
    # The exact Windows package version is available in its signed manifest.
    # Stage on the same filesystem, then publish only the normalized filename.
    with tempfile.TemporaryDirectory(prefix=".claude-desktop-", dir=artifacts) as temporary:
        staging_path = (Path(temporary) / "package.msix").relative_to(ROOT).as_posix()
        record = download(WINDOWS_URL, staging_path)
        with zipfile.ZipFile(ROOT / staging_path) as package:
            manifest = ET.fromstring(package.read("AppxManifest.xml"))
        identity = manifest.find("{http://schemas.microsoft.com/appx/manifest/foundation/windows10}Identity")
        version = identity.attrib["Version"]
        if not re.fullmatch(r"\d+(?:\.\d+){3}", version):
            raise RuntimeError(f"Invalid Windows package version: {version!r}")
        relative_path = f"artifacts/claude-desktop/{version}/windows-x64/claude-desktop-{version}-windows-x64.msix"
        target = ROOT / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        (ROOT / staging_path).replace(target)
        record["path"] = relative_path
    record.update({
        "platform": "windows-x64",
        "version": version,
        "notes": "Official full MSIX package, rather than the online ClaudeSetup.exe bootstrapper. Installation is subject to Windows administrator and application deployment policies; use App Installer or the organization's software deployment tooling. Downloading does not install or disable updates.",
    })
    return record


def linux():
    with request(APT_INDEX) as source:
        index = source.read().decode("utf-8")
    entries = []
    for paragraph in re.split(r"\n\s*\n", index.strip()):
        fields = dict(line.split(": ", 1) for line in paragraph.splitlines() if ": " in line and not line.startswith(" "))
        if fields.get("Package") == "claude-desktop" and fields.get("Architecture") == "amd64":
            entries.append(fields)
    # Official package versions use numeric dot-separated components.
    entry = max(entries, key=lambda item: tuple(int(part) for part in item["Version"].split(".")))
    version = entry["Version"]
    record = download(
        APT_BASE + entry["Filename"],
        f"artifacts/claude-desktop/{version}/linux-x64/claude-desktop-{version}-linux-x64.deb",
        entry["SHA256"],
        int(entry["Size"]),
    )
    record.update({
        "platform": "linux-x64",
        "version": version,
        "official_sha256": entry["SHA256"],
        "official_index_url": APT_INDEX,
        "notes": "Official beta for Ubuntu 22.04+ or Debian 12+, amd64. File size and SHA-256 matched Anthropic's APT Packages index. Package installation may need distribution dependencies. To avoid registering Anthropic's APT repository, set CLAUDE_DESKTOP_ADD_REPO=\"false\" in /etc/default/claude-desktop before installation, per official documentation.",
    })
    return record


def main():
    with ThreadPoolExecutor(max_workers=2) as pool:
        records = list(pool.map(lambda fn: fn(), [windows, linux]))
    output = ROOT / "artifacts/desktop-downloads.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({
        "downloaded_at_utc": datetime.now(timezone.utc).isoformat(),
        "official_documentation": [
            "https://claude.com/download",
            "https://support.claude.com/en/articles/12622703-deploy-claude-desktop-for-windows",
            "https://code.claude.com/docs/en/desktop-linux",
        ],
        "artifacts": records,
    }, indent=2) + "\n", encoding="utf-8")
    for record in records:
        print(f'{record["platform"]}: {record["version"]}, {record["size_bytes"]} bytes, SHA256 {record["sha256"]}', flush=True)


if __name__ == "__main__":
    main()
