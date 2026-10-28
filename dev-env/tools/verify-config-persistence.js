#!/usr/bin/env node
"use strict";

// Maintainer-only tests. The WSH host, filesystem, and registry are mocked.
// No ActiveX object is constructed and the real Windows Registry is never used.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const source = fs.readFileSync(path.join(__dirname, "..", "setup-config.js"), "utf8");
const win = path.win32;
const USER = "HKCU\\Environment\\";
const MACHINE = "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment\\";
const normalize = value => String(value).toLowerCase();

function fixture(overrides = {}) {
    const environment = {
        USERPROFILE: "C:\\Fixture User !&%",
        CLAUDE_CONFIG_DIR: "C:\\Fixture User !&%\\.claude",
        CLAUDE_CODE_GIT_BASH_PATH: "C:\\Custom Git\\usr\\bin\\bash.exe",
        DEV_ENV_INSTALL_DIR: "C:\\Fixture Tools\\Claude\\bin",
        ...overrides,
    };
    const files = new Map();
    const folders = new Set([
        "C:\\", "C:\\Fixture User !&%", environment.CLAUDE_CONFIG_DIR,
        environment.DEV_ENV_INSTALL_DIR, "C:\\Custom Git\\bin", "C:\\Custom Git\\cmd",
    ].map(normalize));
    const registry = new Map();
    const writes = [];
    let failureKey = "";
    let tempCounter = 0;
    const settings = win.join(environment.CLAUDE_CONFIG_DIR, "settings.json");
    files.set(normalize(environment.CLAUDE_CODE_GIT_BASH_PATH), "fixture binary");

    function absent() { const error = new Error("Absent fixture value"); error.number = -2147024894; throw error; }
    const fso = {
        BuildPath: win.join,
        GetParentFolderName: win.dirname,
        FolderExists: value => folders.has(normalize(value)),
        FileExists: value => files.has(normalize(value)),
        CreateFolder(value) { folders.add(normalize(value)); },
        GetTempName() { return `fixture-${++tempCounter}.tmp`; },
        CopyFile(from, to, overwrite) {
            assert(files.has(normalize(from)));
            if (files.has(normalize(to)) && !overwrite) throw new Error("Destination exists");
            files.set(normalize(to), files.get(normalize(from)));
        },
        MoveFile(from, to) {
            assert(files.has(normalize(from)));
            assert(!files.has(normalize(to)));
            files.set(normalize(to), files.get(normalize(from)));
            files.delete(normalize(from));
        },
        DeleteFile(value) { if (!files.delete(normalize(value))) absent(); },
    };
    const shell = {
        Environment(scope) { assert.equal(scope, "PROCESS"); return name => environment[name] || ""; },
        ExpandEnvironmentStrings(value) {
            return value.replace(/%([^%]+)%/g, (whole, name) => environment[name.toUpperCase()] || whole);
        },
        RegRead(key) {
            if (!registry.has(normalize(key))) absent();
            return registry.get(normalize(key)).value;
        },
        RegWrite(key, value, type) {
            writes.push({ action: "write", key, value, type });
            if (normalize(key) === failureKey) {
                failureKey = "";
                throw new Error("Synthetic write failure");
            }
            registry.set(normalize(key), { value, type });
        },
        RegDelete(key) {
            writes.push({ action: "delete", key });
            if (!registry.delete(normalize(key))) absent();
        },
    };
    function stream() {
        return {
            State: 0, text: "",
            Open() { this.State = 1; }, Close() { this.State = 0; },
            LoadFromFile(value) { assert(files.has(normalize(value))); this.text = files.get(normalize(value)); },
            ReadText() { return this.text; },
            WriteText(value) { this.text += value; },
            SaveToFile(value) { files.set(normalize(value), "\uFEFF" + this.text); },
        };
    }
    function run(command) {
        const output = [];
        let code;
        const quit = {};
        const context = vm.createContext({
            ActiveXObject: function (name) {
                if (name === "Scripting.FileSystemObject") return fso;
                if (name === "WScript.Shell") return shell;
                if (name === "ADODB.Stream") return stream();
                throw new Error(`Unexpected ActiveX object: ${name}`);
            },
            WScript: {
                Arguments: { length: 1, Item: () => command },
                Echo: message => output.push(message),
                StdErr: { WriteLine: message => output.push(message) },
                Quit(value) { code = value; throw quit; },
            },
        });
        try { vm.runInContext(source, context, { timeout: 5000 }); }
        catch (error) { if (error !== quit) throw error; }
        return { code, output: output.join("\n") };
    }
    function ready() {
        assert.equal(run("prepare").code, 0);
        const data = JSON.parse(files.get(normalize(settings)).replace(/^\uFEFF/, ""));
        data.env.ANTHROPIC_AUTH_TOKEN = "fixture-only-secret-never-log";
        files.set(normalize(settings), JSON.stringify(data));
    }
    return {
        environment, files, registry, writes, run, ready, settings,
        failOnce(key) { failureKey = normalize(key); },
        put(key, value, type = "REG_SZ") { registry.set(normalize(key), { value, type }); },
        get(key) { return registry.get(normalize(key)); },
    };
}

function test(name, operation) {
    operation();
    process.stdout.write(`PASS ${name}\n`);
}

test("long user PATH retains unrelated entries, expands identity only, and stays idempotent", () => {
    const test = fixture();
    test.ready();
    const unrelated = Array.from({ length: 180 }, (_, i) => `C:\\Existing tools\\entry-${i}`);
    unrelated.push("%USERPROFILE%\\custom-tools");
    const previous = unrelated.join(";");
    assert(previous.length > 1024);
    test.put(USER + "Path", previous, "REG_EXPAND_SZ");
    test.put(USER + "ANTHROPIC_API_KEY", "fixture-only-old-secret");
    const result = test.run("persist");
    assert.equal(result.code, 0, result.output);
    const stored = test.get(USER + "Path");
    assert.equal(stored.type, "REG_EXPAND_SZ");
    assert(stored.value.endsWith(previous));
    assert(stored.value.startsWith(test.environment.DEV_ENV_INSTALL_DIR + ";C:\\Custom Git\\bin;C:\\Custom Git\\cmd;"));
    assert(!test.get(USER + "ANTHROPIC_API_KEY"));
    assert(!test.get(USER + "ANTHROPIC_AUTH_TOKEN"));
    assert(!result.output.includes("fixture-only-old-secret"));
    assert(!result.output.includes("fixture-only-secret-never-log"));
    assert.equal(test.run("persist").code, 0);
    assert.deepEqual(test.get(USER + "Path"), stored);
});

test("machine provider conflict fails before the first user Registry write", () => {
    const test = fixture();
    test.ready();
    test.put(MACHINE + "CLAUDE_CODE_USE_MANTLE", "1");
    const before = new Map(test.registry);
    const result = test.run("persist");
    assert.equal(result.code, 1);
    assert.equal(test.writes.length, 0);
    assert.deepEqual(test.registry, before);
    assert(result.output.includes("CLAUDE_CODE_USE_MANTLE"));
});

test("Registry failure rolls back all earlier writes and retains the former credentials", () => {
    const test = fixture();
    test.ready();
    test.put(USER + "Path", "%USERPROFILE%\\existing", "REG_EXPAND_SZ");
    test.put(USER + "CLAUDE_CONFIG_DIR", "C:\\Previous Claude");
    test.put(USER + "ANTHROPIC_API_KEY", "fixture-only-old-secret");
    const before = new Map(test.registry);
    test.failOnce(USER + "CLAUDE_CODE_USE_POWERSHELL_TOOL");
    const result = test.run("persist");
    assert.equal(result.code, 1);
    assert.deepEqual(test.registry, before);
    assert(!result.output.includes("fixture-only-old-secret"));
});

test("explicitly skipping a former certificate removes only its selected setting and user variable", () => {
    const test = fixture({ DEV_ENV_SKIP_CERTIFICATE: "1" });
    test.files.set(normalize(test.settings), JSON.stringify({ env: { NODE_EXTRA_CA_CERTS: "C:\\Missing\\old.pem" }, custom: true }));
    test.ready();
    const data = JSON.parse(test.files.get(normalize(test.settings)).replace(/^\uFEFF/, ""));
    assert(!Object.hasOwn(data.env, "NODE_EXTRA_CA_CERTS"));
    assert.equal(data.custom, true);
    test.put(USER + "NODE_EXTRA_CA_CERTS", "C:\\Missing\\old.pem");
    test.put(USER + "UNRELATED_VARIABLE", "retain-this");
    const result = test.run("persist");
    assert.equal(result.code, 0, result.output);
    assert(!test.get(USER + "NODE_EXTRA_CA_CERTS"));
    assert.equal(test.get(USER + "UNRELATED_VARIABLE").value, "retain-this");
});

process.stdout.write("4 persistence scenarios passed. Real Windows Registry untouched.\n");
