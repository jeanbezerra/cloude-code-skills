#!/usr/bin/env python3
"""Exercise CMD and Git Bash workflows against an isolated HTTPS S3 fixture.

Requires Python 3 and Git for Windows. Never executes Claude: every downloaded
"binary" is a short text fixture, and the real artifacts are not copied.
"""

from contextlib import contextmanager
import argparse
import functools
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import sys
import tempfile
import threading


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = {
    ("claude-code", "windows-x64"): "artifacts/claude-code/0.0.0-fixture/windows-x64/claude-code-0.0.0-fixture-windows-x64.exe",
    ("claude-code", "linux-x64"): "artifacts/claude-code/0.0.0-fixture/linux-x64/claude-code-0.0.0-fixture-linux-x64",
    ("claude-desktop", "windows-x64"): "artifacts/claude-desktop/0.0.0-fixture/windows-x64/claude-desktop-0.0.0-fixture-windows-x64.msix",
    ("claude-desktop", "linux-x64"): "artifacts/claude-desktop/0.0.0-fixture/linux-x64/claude-desktop-0.0.0-fixture-linux-x64.deb",
}


def payload(product, platform):
    return f"test fixture only: {product}/{platform}\n".encode("ascii")


class QuietHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, request_log, **kwargs):
        self.request_log = request_log
        super().__init__(*args, **kwargs)

    def do_GET(self):
        self.request_log.append(self.path)
        super().do_GET()

    def log_message(self, *args):
        pass


def require_file(candidates, description):
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(Path(candidate).resolve())
    raise RuntimeError(f"Missing {description}; install Git for Windows to run this maintainer test")


@contextmanager
def https_server(base, openssl):
    key, cert = base / "server.key", base / "server.crt"
    subprocess.run([
        openssl, "req", "-x509", "-newkey", "rsa:2048", "-nodes",
        "-keyout", str(key), "-out", str(cert), "-days", "1",
        "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost",
    ], check=True, capture_output=True)
    site = base / "https site"
    site.mkdir()
    requests = []
    handler = functools.partial(QuietHandler, directory=str(site), request_log=requests)
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield site, f"https://localhost:{server.server_port}", cert, requests
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


class Harness:
    def __init__(self, base, site, endpoint, cert, bash, git_curl, requests):
        self.base, self.site, self.endpoint, self.cert = base, site, endpoint, cert
        self.bash, self.git_curl = bash, git_curl
        self.requests = requests
        self.passed = 0
        self.failed = []

    def check(self, name, operation):
        try:
            operation()
            self.passed += 1
            print(f"PASS {name}", flush=True)
        except Exception as error:
            self.failed.append((name, str(error)))
            print(f"FAIL {name}: {error}", flush=True)

    def scenario(self, name, corrupt=False, missing=False):
        # Spaces deliberately cover the enterprise path quoting requirement.
        case = self.base / f"client {name}"
        scripts = case / "dev env"
        shutil.copytree(ROOT, scripts, ignore=shutil.ignore_patterns(
            "artifacts", "tools", "upstream", "downloads", "node_modules", ".git",
            "env.local.cmd", "env.local.sh",
        ))
        # cmd.exe searches the Windows system directory before PATH. A local
        # Git curl copy ensures this self-signed test uses CURL_CA_BUNDLE.
        shutil.copy2(self.git_curl, scripts / "curl.exe")
        remote = self.site / name
        rows = []
        for (product, platform), relative in FIXTURES.items():
            data = payload(product, platform)
            path = remote / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            if not (missing and product == "claude-code"):
                path.write_bytes(data + b"CORRUPTED" if corrupt and product == "claude-code" else data)
            rows.append(f"{product}|{platform}|{relative}|{hashlib.sha256(data).hexdigest()}\n")
        remote_catalog = remote / "artifacts/catalog.txt"
        remote_catalog.write_text("".join(rows), encoding="ascii")
        local_catalog = scripts / "artifacts/catalog.txt"
        local_catalog.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(remote_catalog, local_catalog)
        downloads, installed = case / "download cache", case / "installed tools"
        downloads.mkdir()
        installed.mkdir()
        env = os.environ.copy()
        env.update({
            "S3_BASE_URL": f"{self.endpoint}/{name}",
            "DEV_ENV_DOWNLOAD_DIR": str(downloads),
            "DEV_ENV_INSTALL_DIR": str(installed),
            "DEV_ENV_CATALOG": str(local_catalog),
            "CURL_CA_BUNDLE": str(self.cert),
            "CURL_HOME": str(self.cert.parent),
            "SSL_CERT_FILE": str(self.cert),
            "PATH": str(Path(self.git_curl).parent) + os.pathsep + env.get("PATH", ""),
        })
        return scripts, downloads, installed, env

    def run(self, backend, scripts, env, script, *args, expect_success=True):
        filename = scripts / (script + (".cmd" if backend == "cmd" else ".sh"))
        if not filename.is_file():
            raise AssertionError(f"Missing script: {filename.name}")
        if backend == "cmd":
            command = [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "call", str(filename), *args]
        else:
            command = [self.bash, "--noprofile", "--norc", filename.as_posix(), *args]
        result = subprocess.run(command, cwd=scripts, env=env, text=True,
                                encoding="utf-8", errors="replace", capture_output=True,
                                timeout=45)
        if (result.returncode == 0) != expect_success:
            combined = (result.stdout + result.stderr).strip()
            raise AssertionError(f"exit={result.returncode}; expected {'success' if expect_success else 'failure'}\n{combined}")
        if script == "download-s3":
            assert not any(path.endswith("/artifacts/catalog.txt") for path in self.requests), "Downloader fetched the local-only catalog from S3"
        return result

    def downloads_success(self, backend, platform):
        scripts, downloads, installed, env = self.scenario(f"{backend}-{platform}-ok")
        self.run(backend, scripts, env, "download-s3", platform, "all")
        for product in ("claude-code", "claude-desktop"):
            path = downloads / FIXTURES[(product, platform)]
            assert path.is_file(), f"Downloaded file missing: {path}"
            assert path.read_bytes() == payload(product, platform), f"Wrong bytes at {path}"
        if platform == "windows-x64":
            install_args = () if backend == "cmd" else ("windows-x64",)
            self.run(backend, scripts, env, "install-cli", *install_args)
            targets = list(installed.rglob("claude.exe"))
            assert len(targets) == 1, f"Expected one installed claude.exe, found {targets}"
            target = targets[0]
            assert target.read_bytes() == payload("claude-code", platform), "Installed bytes differ"
            # The installer must not destroy a previous working executable if
            # the cached replacement does not match the catalog hash.
            previous = b"previous working binary fixture\n"
            target.write_bytes(previous)
            (downloads / FIXTURES[("claude-code", platform)]).write_bytes(b"tampered replacement\n")
            self.run(backend, scripts, env, "install-cli", *install_args, expect_success=False)
            assert target.read_bytes() == previous, "Failed install changed the previous executable"

    def download_failure_preserves_file(self, backend, platform, kind):
        scripts, downloads, installed, env = self.scenario(
            f"{backend}-{kind}", corrupt=kind == "bad-hash", missing=kind == "404")
        target = downloads / FIXTURES[("claude-code", platform)]
        target.parent.mkdir(parents=True, exist_ok=True)
        previous = b"previous trusted cached binary fixture\n"
        target.write_bytes(previous)
        self.run(backend, scripts, env, "download-s3", platform, "claude-code", expect_success=False)
        expected_request = f"/{backend}-{kind}/" + FIXTURES[("claude-code", platform)]
        assert expected_request in self.requests, f"Failure happened before artifact GET: {expected_request}"
        assert target.read_bytes() == previous, "Failed download changed the existing file"

    def invalid_selector(self, backend, platform, selector):
        scripts, downloads, installed, env = self.scenario(f"{backend}-invalid-{selector}")
        args = ("invalid-platform", "all") if selector == "platform" else (platform, "invalid-product")
        self.run(backend, scripts, env, "download-s3", *args, expect_success=False)
        assert not list(installed.rglob("claude*")), "Invalid selector installed a file"

    def missing_git_bash_preserves_bin(self, backend):
        scripts, downloads, installed, env = self.scenario(f"{backend}-missing-git-bash")
        self.run(backend, scripts, env, "download-s3", "windows-x64", "claude-code")
        target = installed / "claude.exe"
        previous = b"previous installed binary fixture\n"
        target.write_bytes(previous)
        env["CLAUDE_CODE_GIT_BASH_PATH"] = str(self.base / "missing bash.exe")
        args = () if backend == "cmd" else ("windows-x64",)
        self.run(backend, scripts, env, "install-cli", *args, expect_success=False)
        assert target.read_bytes() == previous, "Missing Git Bash changed installed executable"

    def cmd_bundled_fallback(self):
        scripts, downloads, installed, env = self.scenario("cmd-bundled-fallback")
        # The local catalog contains both products, but only Desktop has been
        # downloaded. The CLI file remains available only in the bundled kit.
        self.run("cmd", scripts, env, "download-s3", "windows-x64", "claude-desktop")
        relative = FIXTURES[("claude-code", "windows-x64")]
        assert (scripts / "artifacts/catalog.txt").is_file(), "Local catalog missing"
        assert not (downloads / relative).exists(), "CLI unexpectedly present in downloads"
        bundled = scripts / relative
        bundled.parent.mkdir(parents=True, exist_ok=True)
        expected = payload("claude-code", "windows-x64")
        bundled.write_bytes(expected)
        self.run("cmd", scripts, env, "install-cli")
        target = installed / "claude.exe"
        assert target.is_file(), "Bundled CLI fallback was not installed"
        assert hashlib.sha256(target.read_bytes()).digest() == hashlib.sha256(expected).digest(), "Bundled fallback hash differs"


def main():
    sys.stdout.reconfigure(errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", choices=["cmd-bundled-fallback"], help="Run just the named scenario")
    args = parser.parse_args()
    if os.name != "nt":
        raise RuntimeError("This integration harness targets Windows CMD and Git Bash")
    git = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git"
    bash = require_file([git / "bin/bash.exe", shutil.which("bash.exe")], "Git Bash")
    openssl = require_file([git / "usr/bin/openssl.exe", shutil.which("openssl.exe")], "OpenSSL")
    git_curl = require_file([git / "ucrt64/bin/curl.exe", git / "mingw64/bin/curl.exe", git / "usr/bin/curl.exe"], "Git curl")
    with tempfile.TemporaryDirectory(prefix="dev-env workflow ") as temporary:
        base = Path(temporary)
        with https_server(base, openssl) as (site, endpoint, cert, requests):
            # Git curl can be built exclusively with Schannel, which ignores
            # CURL_CA_BUNDLE. Its documented --cacert equivalent in a temporary
            # curl config keeps certificate verification enabled in that case.
            for filename in (".curlrc", "_curlrc"):
                (base / filename).write_text(f'cacert = "{cert.as_posix()}"\n', encoding="ascii")
            harness = Harness(base, site, endpoint, cert, bash, git_curl, requests)
            if not args.only:
                for backend, platform in (("cmd", "windows-x64"), ("bash", "linux-x64")):
                    harness.check(f"{backend}: download {platform}, integrity and preserved relative paths",
                                  lambda b=backend, p=platform: harness.downloads_success(b, p))
                    for kind in ("bad-hash", "404"):
                        harness.check(f"{backend}: {kind} rejects replacement and preserves cached file",
                                      lambda b=backend, p=platform, k=kind: harness.download_failure_preserves_file(b, p, k))
                    for selector in ("platform", "product"):
                        harness.check(f"{backend}: invalid {selector} returns failure",
                                      lambda b=backend, p=platform, s=selector: harness.invalid_selector(b, p, s))
                    harness.check(f"{backend}: missing Git Bash rejects install and preserves installed binary",
                                  lambda b=backend: harness.missing_git_bash_preserves_bin(b))
                harness.check("bash: Windows install and invalid replacement preserves installed binary",
                              lambda: harness.downloads_success("bash", "windows-x64"))
            if not args.only or args.only == "cmd-bundled-fallback":
                harness.check("cmd: Desktop-only download installs verified CLI from bundled fallback",
                              harness.cmd_bundled_fallback)
            print(f"\n{harness.passed} scenarios passed; {len(harness.failed)} failed. No Claude executable ran.")
            if harness.failed:
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
