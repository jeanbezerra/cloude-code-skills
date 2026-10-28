#!/usr/bin/env python3
"""Verify the Windows setup assistant in isolated temporary directories.

Requires Python, Windows Script Host and Git for Windows on the maintainer's
machine. Never executes Claude, contacts Genial/S3, opens an editor, writes the
real user profile or changes Windows environment variables in the Registry.
The copied setup helper has its persist implementation explicitly disabled.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
URL = "https://genial-lite.plataforma-gen-ia.prd.awsporto"
SECRET = 'fixture-secret-keep-private-&>"\\!^%-ação-雪'
CONFLICT_SECRET = "fixture-conflicting-secret-never-display"
CONFLICTS = (
    "ANTHROPIC_API_KEY", "NODE_TLS_REJECT_UNAUTHORIZED",
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX",
    "CLAUDE_CODE_USE_FOUNDRY", "CLAUDE_CODE_USE_MANTLE",
    "CLAUDE_CODE_USE_ANTHROPIC_AWS",
)


def require_file(candidates, name):
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate).resolve()
    raise RuntimeError(f"Missing {name}; install Git for Windows/Windows Script Host")


def run(command, *, env, cwd, success=True, input_text=None):
    result = subprocess.run(
        [str(part) for part in command], cwd=cwd, env=env,
        input=input_text, text=True, encoding="utf-8", errors="replace",
        capture_output=True, timeout=60,
    )
    output = result.stdout + result.stderr
    assert SECRET not in output, "Credential exposed in process output"
    assert CONFLICT_SECRET not in output, "Conflicting credential exposed in process output"
    # Non-ASCII stdout can use the Windows console code page. The ASCII
    # credential prefix must also remain absent after any decoding loss.
    assert "fixture-secret-keep-private" not in output, "Credential prefix exposed"
    if (result.returncode == 0) != success:
        raise AssertionError(
            f"exit={result.returncode}; expected {'success' if success else 'failure'}\n{output}"
        )
    return result


class Harness:
    def __init__(self, base, bash, openssl, cscript, curl):
        self.base, self.bash, self.openssl = base, bash, openssl
        self.cscript, self.curl = cscript, curl
        self.passed, self.failed = 0, []

    def check(self, name, operation):
        try:
            operation()
            self.passed += 1
            print(f"PASS {name}", flush=True)
        except Exception as error:
            self.failed.append((name, str(error)))
            print(f"FAIL {name}: {error}", flush=True)

    def scenario(self, name):
        case = self.base / f"client {name}"
        case.mkdir()
        profile, config, installed = case / "user profile", case / "claude config", case / "installed tools"
        for directory in (profile, config, installed):
            directory.mkdir()
        env = os.environ.copy()
        for key in list(env):
            if key.upper().startswith(("CLAUDE_", "ANTHROPIC_", "DEV_ENV_", "S3_")) or key in CONFLICTS:
                env.pop(key)
        env.pop("NODE_EXTRA_CA_CERTS", None)
        env.update({
            "USERPROFILE": str(profile), "HOME": str(profile),
            "LOCALAPPDATA": str(profile / "AppData" / "Local"),
            "APPDATA": str(profile / "AppData" / "Roaming"),
            "CLAUDE_CONFIG_DIR": str(config),
            "CLAUDE_CODE_GIT_BASH_PATH": str(self.bash),
            "DEV_ENV_INSTALL_DIR": str(installed),
            "DEV_ENV_DOWNLOAD_DIR": str(case / "download cache"),
            "DEV_ENV_GENIAL_URL": URL,
        })
        return case, config / "settings.json", installed, env

    def helper(self, command, env, *, success=True):
        assert command in ("prepare", "validate", "check-runtime", "certificate-path")
        return run(
            [self.cscript, "//nologo", "//E:JScript", ROOT / "setup-config.js", command],
            env=env, cwd=ROOT, success=success,
        )

    @staticmethod
    def write_settings(path, data):
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    def configured(self, name):
        case, settings, installed, env = self.scenario(name)
        self.write_settings(settings, {"env": {"ANTHROPIC_AUTH_TOKEN": SECRET}})
        self.helper("prepare", env)
        return case, settings, installed, env

    def prepare_preserves_settings(self):
        case, settings, installed, env = self.scenario("prepare unicode and backup")
        original = {
            "theme": "light", "language": "pt-PT", "cleanupPeriodDays": 15,
            "availableModels": ["sonnet"],
            "custom": {"message": "Configuração com ação, 雪 e 😀", "array": [None, True, -1.25, "\\\"\n"]},
            "env": {"ANTHROPIC_AUTH_TOKEN": SECRET, "CUSTOM_ENV": "preservar opção",
                    "ANTHROPIC_API_KEY": CONFLICT_SECRET, "CLAUDE_CODE_USE_VERTEX": "1"},
        }
        self.write_settings(settings, original)
        before = settings.read_bytes()
        result = self.helper("prepare", env)
        prepared = json.loads(settings.read_text(encoding="utf-8-sig"))
        for key in ("theme", "language", "cleanupPeriodDays", "availableModels", "custom"):
            assert prepared[key] == original[key], f"Existing {key} changed"
        assert prepared["env"]["ANTHROPIC_AUTH_TOKEN"] == SECRET
        assert prepared["env"]["CUSTOM_ENV"] == "preservar opção"
        assert prepared["env"]["ANTHROPIC_BASE_URL"] == URL
        assert prepared["env"]["CLAUDE_CODE_GIT_BASH_PATH"] == str(self.bash)
        assert not any(key in prepared["env"] for key in CONFLICTS)
        assert "ANTHROPIC_API_KEY" in result.stdout and "CLAUDE_CODE_USE_VERTEX" in result.stdout
        backups = list(settings.parent.glob("settings.json.backup-*"))
        assert len(backups) == 1 and backups[0].read_bytes() == before, "Original backup missing or changed"
        assert not list(settings.parent.glob("*.tmp-*")) and not list(settings.parent.glob("*.rollback-*"))
        self.helper("validate", env)
        after = settings.read_bytes()
        self.helper("prepare", env)
        assert settings.read_bytes() == after, "Repeated preparation rewrote unchanged data"
        assert len(list(settings.parent.glob("settings.json.backup-*"))) == 1

    def invalid_settings_preserved(self, name, source):
        case, settings, installed, env = self.scenario("invalid " + name)
        settings.write_text(source, encoding="utf-8")
        before = settings.read_bytes()
        self.helper("prepare", env, success=False)
        assert settings.read_bytes() == before, "Invalid settings were changed"
        assert not list(settings.parent.glob("settings.json.backup-*")), "Invalid settings were backed up/rewritten"

    def changing_gateway_resets_token(self):
        case, settings, installed, env = self.scenario("change previous gateway")
        self.write_settings(settings, {
            "theme": "light",
            "env": {"ANTHROPIC_AUTH_TOKEN": SECRET, "ANTHROPIC_BASE_URL": "https://outro.invalid"},
        })
        before = settings.read_bytes()
        self.helper("prepare", env)
        prepared = json.loads(settings.read_text(encoding="utf-8-sig"))
        assert prepared["env"]["ANTHROPIC_BASE_URL"] == URL
        assert prepared["env"]["ANTHROPIC_AUTH_TOKEN"] == "cole-aqui-sua-APIKey-do-Genial", "Credential from another gateway was reused"
        assert prepared["theme"] == "light"
        backups = list(settings.parent.glob("settings.json.backup-*"))
        assert len(backups) == 1 and backups[0].read_bytes() == before, "Previous gateway credentials were not preserved in the local backup"
        self.helper("validate", env, success=False)

    def validate_rejects(self, name, mutate):
        case, settings, installed, env = self.configured("validate " + name)
        data = json.loads(settings.read_text(encoding="utf-8-sig"))
        mutate(data, case)
        self.write_settings(settings, data)
        before = settings.read_bytes()
        self.helper("validate", env, success=False)
        assert settings.read_bytes() == before, "Validation changed settings"

    def certificate_path_only(self):
        case, settings, installed, env = self.configured("certificate path")
        certificate = case / "corporate certificate.pem"
        certificate.write_text("fixture file; helper checks existence only\n", encoding="ascii")
        env["NODE_EXTRA_CA_CERTS"] = str(certificate)
        self.helper("prepare", env)
        result = self.helper("certificate-path", env)
        assert result.stdout.strip() == str(certificate), "certificate-path emitted additional settings"
        self.helper("validate", env)

    def fixture_certificate(self, case, env, filename="corporate test root.pem"):
        certificate = case / filename
        run([
            self.openssl, "req", "-x509", "-newkey", "rsa:2048", "-nodes",
            "-keyout", case / "test only root.key", "-out", certificate,
            "-days", "1", "-subj", "/CN=Setup fixture only",
            "-addext", "basicConstraints=critical,CA:TRUE",
        ], env=env, cwd=case)
        return certificate

    def wizard(self, name, install_success, *, usr_bin=False, certificate_mode="existing"):
        case, settings, installed, env = self.scenario("wizard " + name)
        if usr_bin:
            git_root = self.bash.parent.parent
            env["CLAUDE_CODE_GIT_BASH_PATH"] = str(git_root / "usr/bin/bash.exe")
            env["PATH"] = os.pathsep.join(
                entry for entry in env.get("PATH", "").split(os.pathsep)
                if str(git_root).casefold() not in entry.casefold()
            )
        scripts = case / "copied kit with spaces"
        scripts.mkdir()
        for filename in ("setup.cmd", "env.cmd", "find-git-bash.cmd"):
            shutil.copy2(ROOT / filename, scripts / filename)
        # Likewise prevent editor launches in every failure path of the copy.
        wizard = (scripts / "setup.cmd").read_text(encoding="utf-8-sig")
        editor = 'start "" /wait notepad.exe "%CLAUDE_CONFIG_DIR%\\settings.json"'
        assert wizard.count(editor) == 1, "Cannot disable fixture UI safely"
        wizard = wizard.replace(editor, "echo UI_FORBIDDEN_IN_TEST\nexit /b 91", 1)
        (scripts / "setup.cmd").write_text(wizard, encoding="utf-8")
        # Defense in depth: no wizard test can write to the real Registry even
        # if its session-only routing regresses. Only this copied helper changes.
        helper = (ROOT / "setup-config.js").read_text(encoding="utf-8-sig")
        needle = "function persist() {"
        assert helper.count(needle) == 1, "Cannot disable fixture persistence safely"
        helper = helper.replace(needle, needle + '\n        fail("PERSIST_FORBIDDEN_IN_TEST");', 1)
        (scripts / "setup-config.js").write_text(helper, encoding="utf-8")
        install = "@echo off\r\n"
        if install_success:
            install += (
                f'copy /b /y "{self.curl}" "%DEV_ENV_INSTALL_DIR%\\claude.exe" >nul\r\n'
                'if errorlevel 1 exit /b 1\r\n'
                'echo FIXTURE_INSTALL_OK\r\nexit /b 0\r\n'
            )
        else:
            install += "echo FIXTURE_INSTALL_FAILED\r\nexit /b 1\r\n"
        (scripts / "install-cli.cmd").write_text(install, encoding="ascii")
        (scripts / "download-s3.cmd").write_text(
            "@echo off\r\necho FIXTURE_DOWNLOAD_FORBIDDEN\r\nexit /b 1\r\n", encoding="ascii"
        )
        assert certificate_mode in ("existing", "prompt", "skip stale")
        if certificate_mode == "skip stale":
            certificate = case / "missing old corporate certificate.pem"
        else:
            filename = "corporate test root.pem" if certificate_mode == "existing" else "corporate root with spaces & !.pem"
            certificate = self.fixture_certificate(case, env, filename)
        if certificate_mode == "existing":
            env["NODE_EXTRA_CA_CERTS"] = str(certificate)
        env["ANTHROPIC_API_KEY"] = CONFLICT_SECRET
        data = {"theme": "light", "env": {"ANTHROPIC_AUTH_TOKEN": SECRET}}
        if certificate_mode == "skip stale":
            data["env"]["NODE_EXTRA_CA_CERTS"] = str(certificate)
        self.write_settings(settings, data)
        before = settings.read_bytes()
        driver = scripts / "exercise setup.cmd"
        certificate_assertion = (
            'if defined NODE_EXTRA_CA_CERTS exit /b 54\r\n' if certificate_mode == "skip stale"
            else 'if not exist "%NODE_EXTRA_CA_CERTS%" exit /b 54\r\n'
        )
        driver.write_text(
            '@echo off\r\ncall "%~dp0setup.cmd" --session-only\r\n'
            'if errorlevel 1 exit /b %errorlevel%\r\n'
            'if defined ANTHROPIC_API_KEY exit /b 51\r\n'
            'if not "%DEV_ENV_PATH_ENTRY%"=="%DEV_ENV_INSTALL_DIR%" exit /b 52\r\n'
            'if not exist "%CLAUDE_CONFIG_DIR%\\settings.json" exit /b 53\r\n'
            + certificate_assertion +
            'echo FIXTURE_SESSION_READY\r\nexit /b 0\r\n', encoding="ascii"
        )
        # If a regression reaches the editor prompt, C cancels before Notepad
        # can open. EOF also cancels any unexpected certificate path prompt.
        answers = "C\n"
        if certificate_mode == "prompt":
            answers = f'"{certificate}"\nC\n'
        elif certificate_mode == "skip stale":
            answers = "S\nC\n"
        result = run(
            [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "call", driver],
            env=env, cwd=scripts, success=install_success, input_text=answers,
        )
        output = result.stdout + result.stderr
        assert "PERSIST_FORBIDDEN_IN_TEST" not in output, "Wizard attempted Registry persistence"
        assert "UI_FORBIDDEN_IN_TEST" not in output, "Wizard attempted editor launch"
        assert "Vou abrir o Bloco de Notas" not in output, "Wizard attempted editor despite existing token"
        if install_success:
            positions = [output.index(f"[{index}/6]") for index in range(1, 7)]
            assert positions == sorted(positions), "Six wizard stages were out of order"
            assert positions[1] < output.index("FIXTURE_INSTALL_OK") < positions[2]
            assert "FIXTURE_DOWNLOAD_FORBIDDEN" not in output, "Wizard downloaded despite installed fixture"
            assert "FIXTURE_SESSION_READY" in output, "Wizard did not export current session environment"
            assert "curl " in output, "CLI --version fixture did not execute"
            prepared = json.loads(settings.read_text(encoding="utf-8-sig"))
            assert prepared["theme"] == "light" and prepared["env"]["ANTHROPIC_AUTH_TOKEN"] == SECRET
            if certificate_mode == "skip stale":
                assert "NODE_EXTRA_CA_CERTS" not in prepared["env"], "Skipped stale certificate remained configured"
                assert "Nao encontrei o arquivo indicado" in output, "Old missing certificate was not detected"
                assert "Vamos continuar sem certificado adicional" in output
            else:
                assert prepared["env"]["NODE_EXTRA_CA_CERTS"] == str(certificate)
                if certificate_mode == "prompt":
                    assert "Caminho do certificado ou S:" in output, "Certificate path was not entered through prompt"
            assert list(settings.parent.glob("settings.json.backup-*")), "Wizard failed to back up settings"
        else:
            assert "FIXTURE_INSTALL_FAILED" in output and "FIXTURE_DOWNLOAD_FORBIDDEN" in output
            assert "[3/6]" not in output and "[4/6]" not in output, "Wizard continued after failed install/download"
            assert settings.read_bytes() == before, "Failed installation changed settings"
            assert not list(settings.parent.glob("settings.json.backup-*"))


def main():
    sys.stdout.reconfigure(errors="replace")
    if os.name != "nt":
        raise RuntimeError("This integration harness targets Windows CMD and Windows Script Host")
    git = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git"
    bash = require_file([git / "bin/bash.exe", git / "usr/bin/bash.exe"], "Git Bash")
    openssl = require_file([git / "usr/bin/openssl.exe", shutil.which("openssl.exe")], "Git OpenSSL")
    cscript = require_file([shutil.which("cscript.exe")], "cscript.exe")
    curl = require_file([Path(os.environ.get("SystemRoot", "C:/Windows")) / "System32/curl.exe"], "Windows curl.exe")
    with tempfile.TemporaryDirectory(prefix="dev-env setup tests ") as temporary:
        harness = Harness(Path(temporary), bash, openssl, cscript, curl)
        harness.check("prepare preserves token, preferences and Unicode; exact backup and idempotence", harness.prepare_preserves_settings)
        harness.check("changing gateway resets credential and preserves the original backup", harness.changing_gateway_resets_token)
        for name, source in (
            ("malformed", '{"env":{"ANTHROPIC_AUTH_TOKEN":"' + CONFLICT_SECRET + '",}}'),
            ("array root", "[]"), ("array env", '{"env":[]}'),
            ("empty", ""), ("trailing code", '{}; WScript.Echo("should never execute")'),
        ):
            harness.check(f"prepare preserves invalid {name}", lambda n=name, s=source: harness.invalid_settings_preserved(n, s))
        mutations = (
            ("placeholder", lambda d, p: d["env"].update(ANTHROPIC_AUTH_TOKEN="cole-aqui-sua-APIKey-do-Genial")),
            ("empty token", lambda d, p: d["env"].update(ANTHROPIC_AUTH_TOKEN="  ")),
            ("conflicting credential", lambda d, p: d["env"].update(ANTHROPIC_API_KEY=CONFLICT_SECRET)),
            ("missing bash", lambda d, p: d["env"].update(CLAUDE_CODE_GIT_BASH_PATH=str(p / "missing bash.exe"))),
            ("missing certificate", lambda d, p: d["env"].update(NODE_EXTRA_CA_CERTS=str(p / "missing cert.pem"))),
            ("HTTP gateway", lambda d, p: d["env"].update(ANTHROPIC_BASE_URL="http://example.invalid")),
            ("different gateway", lambda d, p: d["env"].update(ANTHROPIC_BASE_URL="https://example.invalid")),
            ("PowerShell enabled", lambda d, p: d["env"].update(CLAUDE_CODE_USE_POWERSHELL_TOOL="1")),
        )
        for name, mutation in mutations:
            harness.check(f"validate rejects {name} without changing data or exposing token",
                          lambda n=name, m=mutation: harness.validate_rejects(n, m))
        harness.check("certificate lookup emits only its path", harness.certificate_path_only)
        harness.check("wizard session-only completes six stages with isolated CLI fixture", lambda: harness.wizard("success", True))
        harness.check("wizard validates certificate using usr/bin Bash without Git in PATH",
                      lambda: harness.wizard("usr bin bash", True, usr_bin=True))
        harness.check("wizard accepts a quoted certificate path containing spaces, ampersand and bang",
                      lambda: harness.wizard("quoted certificate", True, certificate_mode="prompt"))
        harness.check("wizard skipping an old missing certificate clears settings and current session",
                      lambda: harness.wizard("skip missing certificate", True, certificate_mode="skip stale"))
        harness.check("wizard stops before settings when install/download fail", lambda: harness.wizard("failed install", False))
        print(f"\n{harness.passed} scenarios passed; {len(harness.failed)} failed. No Claude, UI, network or Registry writes.")
        return 1 if harness.failed else 0


if __name__ == "__main__":
    sys.exit(main())
