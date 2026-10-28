#!/usr/bin/env python3
"""Normalize local artifact names and metadata without changing their bytes."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def main():
    documents = []
    moves = []
    for filename, product in [("cli-downloads.json", "claude-code"), ("desktop-downloads.json", "claude-desktop")]:
        metadata = ROOT / "artifacts" / filename
        document = json.loads(metadata.read_text(encoding="utf-8"))
        for record in document["artifacts"]:
            platform, version = record["platform"], record["version"]
            if platform not in {"windows-x64", "linux-x64"} or not re.fullmatch(r"\d+(?:\.\d+){2,3}", version):
                raise RuntimeError("Unsupported platform/version in metadata")
            extension = (".exe" if platform == "windows-x64" else "") if product == "claude-code" else (".msix" if platform == "windows-x64" else ".deb")
            relative = f"artifacts/{product}/{version}/{platform}/{product}-{version}-{platform}{extension}"
            source = (ROOT / record["path"]).resolve(strict=True)
            target = (ROOT / relative).resolve()
            source.relative_to(ROOT)
            target.relative_to(ROOT)
            if source != target and target.exists():
                raise RuntimeError(f"Refusing to replace existing artifact: {target}")
            with source.open("rb") as stream:
                checksum = hashlib.file_digest(stream, "sha256").hexdigest()
            if checksum != record["sha256"] or source.stat().st_size != record["size_bytes"]:
                raise RuntimeError(f"Artifact integrity mismatch: {source}")
            moves.append((source, target))
            record.update(path=relative, product_id=product)
        documents.append((metadata, document))

    # Validate the whole set before moving any file.
    for source, target in moves:
        if source != target:
            target.parent.mkdir(parents=True, exist_ok=True)
            source.rename(target)
            try:
                source.parent.rmdir()  # Empty directory only; never recursive.
            except OSError:
                pass
        print(target.relative_to(ROOT).as_posix())
    for metadata, document in documents:
        partial = metadata.with_suffix(metadata.suffix + ".tmp")
        partial.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
        partial.replace(metadata)


if __name__ == "__main__":
    main()
