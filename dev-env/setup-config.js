// Windows Script Host JScript (ES3). Run with cscript.exe //nologo.
// No eval, shell interpolation, network calls, or credential output.
(function () {
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    var shell = new ActiveXObject("WScript.Shell");
    var processEnv = shell.Environment("PROCESS");
    var own = Object.prototype.hasOwnProperty;
    var conflicts = ["ANTHROPIC_API_KEY", "NODE_TLS_REJECT_UNAUTHORIZED",
        "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
        "CLAUDE_CODE_USE_MANTLE", "CLAUDE_CODE_USE_ANTHROPIC_AWS"];
    var placeholder = "cole-aqui-sua-APIKey-do-Genial";
    var configDir = processEnv("CLAUDE_CONFIG_DIR") || fso.BuildPath(processEnv("USERPROFILE"), ".claude");
    var settingsPath = fso.BuildPath(configDir, "settings.json");
    var expectedUrl = processEnv("DEV_ENV_GENIAL_URL") || "https://genial-lite.plataforma-gen-ia.prd.awsporto";

    function has(object, key) { return own.call(object, key); }
    function isObject(value) { return value !== null && typeof value === "object" && !(value instanceof Array); }
    function fail(message) { throw new Error(message); }
    function say(message) { WScript.Echo(message); }
    function trim(value) { return value.replace(/^\s+|\s+$/g, ""); }

    // WSH's JScript engine has no reliable built-in JSON implementation.
    // This recursive-descent parser accepts JSON only, including escaped Unicode.
    function parseJson(source) {
        var cursor = 0;
        source = source.replace(/^\uFEFF/, "");
        function invalid() { fail("O settings.json nao contem JSON valido. Revise o arquivo; ele foi preservado."); }
        function whitespace() { while (/[\x20\t\r\n]/.test(source.charAt(cursor)) && cursor < source.length) { cursor++; } }
        function string() {
            var result = "", character, escape, hex;
            if (source.charAt(cursor++) !== '"') { invalid(); }
            while (cursor < source.length) {
                character = source.charAt(cursor++);
                if (character === '"') { return result; }
                if (character === "\\") {
                    escape = source.charAt(cursor++);
                    if (escape === "u") {
                        hex = source.substr(cursor, 4);
                        if (!/^[0-9a-fA-F]{4}$/.test(hex)) { invalid(); }
                        result += String.fromCharCode(parseInt(hex, 16));
                        cursor += 4;
                    } else {
                        var escapes = {'"': '"', "\\": "\\", "/": "/", b: "\b", f: "\f", n: "\n", r: "\r", t: "\t"};
                        if (!has(escapes, escape)) { invalid(); }
                        result += escapes[escape];
                    }
                } else {
                    if (character.charCodeAt(0) < 32) { invalid(); }
                    result += character;
                }
            }
            invalid();
        }
        function value(depth) {
            if (depth > 100) { invalid(); }
            whitespace();
            var character = source.charAt(cursor), result, key, match;
            if (character === '"') { return string(); }
            if (character === "{" || character === "[") {
                var array = character === "[", end = array ? "]" : "}";
                result = array ? [] : {};
                cursor++;
                whitespace();
                if (source.charAt(cursor) === end) { cursor++; return result; }
                while (cursor < source.length) {
                    whitespace();
                    if (array) {
                        result.push(value(depth + 1));
                    } else {
                        if (source.charAt(cursor) !== '"') { invalid(); }
                        key = string();
                        whitespace();
                        if (source.charAt(cursor++) !== ":") { invalid(); }
                        result[key] = value(depth + 1);
                    }
                    whitespace();
                    character = source.charAt(cursor++);
                    if (character === end) { return result; }
                    if (character !== ",") { invalid(); }
                }
                invalid();
            }
            match = /^(true|false|null|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)/.exec(source.substr(cursor));
            if (!match) { invalid(); }
            cursor += match[0].length;
            if (match[0] === "true") { return true; }
            if (match[0] === "false") { return false; }
            if (match[0] === "null") { return null; }
            result = Number(match[0]);
            if (!isFinite(result)) { invalid(); }
            return result;
        }
        var result = value(0);
        whitespace();
        if (cursor !== source.length) { invalid(); }
        return result;
    }

    function quote(value) {
        return '"' + value.replace(/[\\"\x00-\x1f\u2028\u2029]/g, function (character) {
            var code = character.charCodeAt(0).toString(16);
            if (character === "\\" || character === '"') { return "\\" + character; }
            return "\\u" + ("0000" + code).slice(-4);
        }) + '"';
    }
    function stringify(value, indent) {
        if (value === null) { return "null"; }
        if (typeof value === "string") { return quote(value); }
        if (typeof value === "number" || typeof value === "boolean") { return String(value); }
        var parts = [], array = value instanceof Array, key, next = indent + "  ";
        if (array) {
            for (key = 0; key < value.length; key++) { parts.push(next + stringify(value[key], next)); }
        } else {
            for (key in value) {
                if (has(value, key)) { parts.push(next + quote(key) + ": " + stringify(value[key], next)); }
            }
        }
        return (array ? "[" : "{") + (parts.length ? "\r\n" + parts.join(",\r\n") + "\r\n" + indent : "") + (array ? "]" : "}");
    }

    function readUtf8(path) {
        var stream = new ActiveXObject("ADODB.Stream");
        try {
            stream.Type = 2;
            stream.Charset = "utf-8";
            stream.Open();
            stream.LoadFromFile(path);
            return stream.ReadText();
        } finally { if (stream.State) { stream.Close(); } }
    }
    function writeUtf8(path, text) {
        var stream = new ActiveXObject("ADODB.Stream");
        try {
            stream.Type = 2;
            stream.Charset = "utf-8";
            stream.Open();
            stream.WriteText(text);
            stream.SaveToFile(path, 2);
        } finally { if (stream.State) { stream.Close(); } }
    }
    function ensureDirectory(path) {
        if (fso.FolderExists(path)) { return; }
        var parent = fso.GetParentFolderName(path);
        if (!parent || parent === path) { fail("Nao foi possivel criar o diretorio de configuracao."); }
        ensureDirectory(parent);
        fso.CreateFolder(path);
    }
    function loadSettings(allowMissing) {
        var result;
        if (!fso.FileExists(settingsPath)) {
            if (!allowMissing) { fail("settings.json ainda nao existe. Execute a preparacao primeiro."); }
            return {};
        }
        result = parseJson(readUtf8(settingsPath));
        if (!isObject(result) || (has(result, "env") && !isObject(result.env))) {
            fail("settings.json e env precisam ser objetos JSON. O arquivo foi preservado.");
        }
        return result;
    }
    function saveSettings(data) {
        ensureDirectory(configDir);
        var text = stringify(data, "") + "\r\n";
        var exists = fso.FileExists(settingsPath);
        if (exists && readUtf8(settingsPath).replace(/^\uFEFF/, "") === text) {
            say("[OK] As configuracoes ja estavam preparadas.");
            return;
        }
        var unique = String(new Date().getTime()) + "-" + fso.GetTempName();
        var temporary = settingsPath + ".tmp-" + unique;
        var rollback = settingsPath + ".rollback-" + unique;
        var backup = settingsPath + ".backup-" + unique;
        var moved = false;
        try {
            writeUtf8(temporary, text);
            // Verify the complete candidate before touching an existing file.
            parseJson(readUtf8(temporary));
            if (exists) {
                fso.CopyFile(settingsPath, backup, false);
                fso.MoveFile(settingsPath, rollback);
                moved = true;
            }
            fso.MoveFile(temporary, settingsPath);
            if (moved) {
                // The new file is complete; failure to remove the extra old
                // copy must not turn a successful update into a partial error.
                try { fso.DeleteFile(rollback); } catch (cleanupError) {}
            }
        } catch (error) {
            if (moved && !fso.FileExists(settingsPath) && fso.FileExists(rollback)) {
                fso.MoveFile(rollback, settingsPath);
            }
            if (fso.FileExists(temporary)) { fso.DeleteFile(temporary); }
            fail("Nao foi possivel salvar settings.json. Confira as permissoes da pasta.");
        }
        if (exists) { say("[OK] Backup salvo em: " + backup); }
        say("[OK] Configuracoes preparadas em: " + settingsPath);
    }
    function requireHttps(url) {
        if (typeof url !== "string" || !/^https:\/\/[^\s\/]+(?:\/[^\s]*)?$/.test(url) || /[\r\n]/.test(url)) {
            fail("O endereco do Genial deve ser uma URL HTTPS valida.");
        }
    }
    function prepare() {
        var data = loadSettings(true), key, index;
        var env = data.env || {};
        requireHttps(expectedUrl);
        if (!processEnv("CLAUDE_CODE_GIT_BASH_PATH") || !fso.FileExists(processEnv("CLAUDE_CODE_GIT_BASH_PATH"))) {
            fail("O Git Bash precisa ser identificado antes de preparar as configuracoes.");
        }
        if (has(env, "ANTHROPIC_BASE_URL") && env.ANTHROPIC_BASE_URL !== expectedUrl) {
            env.ANTHROPIC_AUTH_TOKEN = placeholder;
            say("[AJUSTE] O gateway mudou. Informe uma API Key do Genial para esse endereco.");
        }
        if (!has(env, "ANTHROPIC_AUTH_TOKEN") || typeof env.ANTHROPIC_AUTH_TOKEN !== "string" || !trim(env.ANTHROPIC_AUTH_TOKEN)) {
            env.ANTHROPIC_AUTH_TOKEN = placeholder;
        }
        env.ANTHROPIC_BASE_URL = expectedUrl;
        var fixed = {
            CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS: "1", CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY: "1",
            CLAUDE_CODE_USE_POWERSHELL_TOOL: "0", CLAUDE_CODE_GIT_BASH_PATH: processEnv("CLAUDE_CODE_GIT_BASH_PATH"),
            DISABLE_ERROR_REPORTING: "1", DISABLE_FEEDBACK_COMMAND: "1", DISABLE_LOGIN_COMMAND: "1",
            DISABLE_TELEMETRY: "1", DISABLE_AUTOUPDATER: "1", DISABLE_UPDATES: "1"
        };
        for (key in fixed) { if (has(fixed, key)) { env[key] = fixed[key]; } }
        if (processEnv("DEV_ENV_SKIP_CERTIFICATE") === "1") { delete env.NODE_EXTRA_CA_CERTS; }
        else if (processEnv("NODE_EXTRA_CA_CERTS")) { env.NODE_EXTRA_CA_CERTS = processEnv("NODE_EXTRA_CA_CERTS"); }
        for (index = 0; index < conflicts.length; index++) {
            key = conflicts[index];
            if (has(env, key)) {
                delete env[key];
                say("[AJUSTE] Variavel conflitante removida de settings.json: " + key);
            }
        }
        data.env = env;
        var defaults = {
            "$schema": "https://json.schemastore.org/claude-code-settings.json",
            cleanupPeriodDays: 30, availableModels: ["opus", "sonnet", "haiku"], autoUpdatesChannel: "stable",
            autoCompactEnabled: true, feedbackSurveyRate: 0, language: "pt-BR", skipWebFetchPreflight: true, theme: "dark"
        };
        for (key in defaults) { if (has(defaults, key) && !has(data, key)) { data[key] = defaults[key]; } }
        saveSettings(data);
    }
    function validate(silent) {
        var data = loadSettings(false), env = data.env || {}, index;
        var token = env.ANTHROPIC_AUTH_TOKEN;
        if (typeof token !== "string" || !trim(token) || /cole[- ]?aqui|sua[- ]?apikey|sua[- ]?api[- ]?key|<[^>]*>/i.test(token)) {
            fail("Falta informar sua API Key do Genial em ANTHROPIC_AUTH_TOKEN. Salve o arquivo e tente novamente.");
        }
        requireHttps(env.ANTHROPIC_BASE_URL);
        if (env.ANTHROPIC_BASE_URL !== expectedUrl) {
            fail("O endereco ANTHROPIC_BASE_URL difere do Genial configurado para este assistente.");
        }
        if (typeof env.CLAUDE_CODE_GIT_BASH_PATH !== "string" || !fso.FileExists(env.CLAUDE_CODE_GIT_BASH_PATH)) {
            fail("O caminho CLAUDE_CODE_GIT_BASH_PATH nao aponta para um arquivo existente.");
        }
        if (env.CLAUDE_CODE_GIT_BASH_PATH.toLowerCase() !== processEnv("CLAUDE_CODE_GIT_BASH_PATH").toLowerCase()) {
            fail("O caminho do Git Bash em settings.json difere do caminho detectado. Execute novamente a preparacao.");
        }
        if (env.CLAUDE_CODE_USE_POWERSHELL_TOOL !== "0" || env.DISABLE_AUTOUPDATER !== "1" || env.DISABLE_UPDATES !== "1") {
            fail("Revise as opcoes de PowerShell e atualizacao automatica em settings.json.");
        }
        for (index = 0; index < conflicts.length; index++) {
            if (has(env, conflicts[index])) { fail("Remova a variavel conflitante de settings.json: " + conflicts[index]); }
        }
        if (has(env, "NODE_EXTRA_CA_CERTS") && (typeof env.NODE_EXTRA_CA_CERTS !== "string" || !fso.FileExists(env.NODE_EXTRA_CA_CERTS))) {
            fail("O arquivo NODE_EXTRA_CA_CERTS configurado nao foi encontrado.");
        }
        if (!silent) {
            say("[OK] JSON valido e API Key cadastrada. O valor da chave nao sera exibido.");
            say("[OK] Endereco do Genial, Git Bash e variaveis sem conflito conferidos.");
            if (env.NODE_EXTRA_CA_CERTS) { say("[OK] Arquivo de certificado encontrado."); }
        }
        return data;
    }
    function readRegistry(path) {
        try { return {exists: true, value: shell.RegRead(path)}; }
        catch (error) {
            // ERROR_FILE_NOT_FOUND and ERROR_PATH_NOT_FOUND mean absent values.
            if ((error.number & 65535) === 2 || (error.number & 65535) === 3) { return {exists: false, value: ""}; }
            fail("Nao foi possivel ler as variaveis de ambiente do Windows. Confira as permissoes.");
        }
    }
    function pathIdentity(value) {
        return shell.ExpandEnvironmentStrings(value.replace(/^"|"$/g, "")).replace(/[\\\/]$/, "").toLowerCase();
    }
    function persist() {
        var data = validate(true), index, key;
        var removals = conflicts.slice(0);
        if (processEnv("DEV_ENV_SKIP_CERTIFICATE") === "1") { removals.push("NODE_EXTRA_CA_CERTS"); }
        var userRoot = "HKCU\\Environment\\";
        var machineRoot = "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment\\";
        // Inspect machine policy before making any changes to user variables.
        var machineConflicts = [];
        for (index = 0; index < conflicts.length; index++) {
            if (readRegistry(machineRoot + conflicts[index]).exists) { machineConflicts.push(conflicts[index]); }
        }
        if (machineConflicts.length) {
            fail("Variaveis conflitantes no ambiente da maquina: " + machineConflicts.join(", ") + ". Solicite o ajuste a TI e execute novamente. Nenhuma variavel de usuario foi alterada.");
        }
        var installation = processEnv("DEV_ENV_INSTALL_DIR");
        if (!installation || !fso.FolderExists(installation)) { fail("O diretorio de instalacao da CLI nao foi encontrado."); }
        var bash = processEnv("CLAUDE_CODE_GIT_BASH_PATH");
        var gitRoot = fso.GetParentFolderName(fso.GetParentFolderName(bash));
        if (/\\usr$/i.test(gitRoot)) { gitRoot = fso.GetParentFolderName(gitRoot); }
        var additions = [installation], candidate;
        for (index = 0; index < 2; index++) {
            candidate = fso.BuildPath(gitRoot, index ? "cmd" : "bin");
            if (fso.FolderExists(candidate)) { additions.push(candidate); }
        }
        var current = readRegistry(userRoot + "Path");
        if (current.exists && typeof current.value !== "string") { fail("O PATH de usuario tem um formato inesperado; ele foi preservado."); }
        var entries = current.value ? current.value.split(";") : [];
        var newEntries = [], seen = {}, identity;
        // Put the intended CLI first, retaining every unrelated PATH entry.
        for (index = 0; index < additions.length; index++) {
            identity = "$" + pathIdentity(additions[index]);
            if (!has(seen, identity)) { newEntries.push(additions[index]); seen[identity] = true; }
        }
        for (index = 0; index < entries.length; index++) {
            identity = "$" + pathIdentity(entries[index]);
            if (!has(seen, identity)) { newEntries.push(entries[index]); seen[identity] = true; }
        }
        var values = {
            Path: newEntries.join(";"), CLAUDE_CONFIG_DIR: configDir,
            CLAUDE_CODE_GIT_BASH_PATH: bash, CLAUDE_CODE_USE_POWERSHELL_TOOL: "0",
            DISABLE_AUTOUPDATER: "1", DISABLE_UPDATES: "1"
        };
        if (data.env.NODE_EXTRA_CA_CERTS) { values.NODE_EXTRA_CA_CERTS = data.env.NODE_EXTRA_CA_CERTS; }
        // Snapshot all affected values so a write failure can roll back this run.
        var snapshots = {}, touched = [];
        for (key in values) { if (has(values, key)) { snapshots[key] = readRegistry(userRoot + key); } }
        for (index = 0; index < removals.length; index++) { snapshots[removals[index]] = readRegistry(userRoot + removals[index]); }
        try {
            for (key in values) {
                if (has(values, key)) {
                    touched.push(key);
                    shell.RegWrite(userRoot + key, values[key], key === "Path" ? "REG_EXPAND_SZ" : "REG_SZ");
                }
            }
            for (index = 0; index < removals.length; index++) {
                key = removals[index];
                if (snapshots[key].exists) { touched.push(key); shell.RegDelete(userRoot + key); }
            }
        } catch (error) {
            var rollbackFailed = false;
            for (index = touched.length - 1; index >= 0; index--) {
                key = touched[index];
                try {
                    if (snapshots[key].exists) { shell.RegWrite(userRoot + key, snapshots[key].value, key === "Path" ? "REG_EXPAND_SZ" : "REG_SZ"); }
                    else { shell.RegDelete(userRoot + key); }
                } catch (rollbackError) { rollbackFailed = true; }
            }
            fail("Nao foi possivel salvar as variaveis de usuario." + (rollbackFailed ? " Confira as variaveis da conta com a TI; parte da restauracao falhou." : " Os valores anteriores foram restaurados."));
        }
        for (index = 0; index < conflicts.length; index++) {
            if (snapshots[conflicts[index]].exists) { say("[AJUSTE] Variavel conflitante removida do usuario: " + conflicts[index]); }
        }
        say("[OK] Variaveis de usuario e PATH salvos sem truncamento. A API Key nao foi gravada no ambiente.");
        say("Se novos terminais ou a IDE nao receberem as variaveis, encerre a sessao do Windows e entre novamente.");
    }

    function certificatePath() {
        var data = loadSettings(true);
        if (data.env && typeof data.env.NODE_EXTRA_CA_CERTS === "string" && data.env.NODE_EXTRA_CA_CERTS) {
            if (/["\x00-\x1f]/.test(data.env.NODE_EXTRA_CA_CERTS)) {
                fail("O caminho do certificado no settings.json tem caracteres invalidos. Revise NODE_EXTRA_CA_CERTS.");
            }
            // This command deliberately emits only the path, never the settings.
            say(data.env.NODE_EXTRA_CA_CERTS);
        }
    }
    function checkRuntime() {
        var stream = new ActiveXObject("ADODB.Stream");
        stream.Type = 2;
        stream.Charset = "utf-8";
        stream.Open();
        stream.Close();
        say("[OK] Windows Script Host e suporte a JSON/UTF-8 disponiveis.");
    }

    try {
        if (WScript.Arguments.length !== 1) { fail("Uso: cscript //nologo setup-config.js prepare|validate|persist|check-runtime|certificate-path"); }
        var command = WScript.Arguments.Item(0);
        if (command === "prepare") { prepare(); }
        else if (command === "validate") { validate(false); }
        else if (command === "persist") { persist(); }
        else if (command === "check-runtime") { checkRuntime(); }
        else if (command === "certificate-path") { certificatePath(); }
        else { fail("Comando de configuracao desconhecido. Use prepare, validate, persist, check-runtime ou certificate-path."); }
    } catch (error) {
        // Report only controlled messages; COM exceptions can contain file data.
        var description = error.message;
        if (!(error instanceof Error)) { description = "Nao foi possivel concluir a configuracao. Confira acesso aos arquivos e ao Windows Script Host."; }
        WScript.StdErr.WriteLine("ERRO: " + description);
        WScript.Quit(1);
    }
    WScript.Quit(0);
})();
