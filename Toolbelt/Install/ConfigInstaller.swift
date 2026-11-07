import Foundation

/// Reads and edits MCP client configs. Every file write keeps a `.toolbelt.bak` copy of the previous version.
enum ConfigInstaller {
    enum InstallError: LocalizedError {
        case emptyConfig
        case invalidConfig
        case clientFileUnreadable(String)
        case cliNotFound
        case cliFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyConfig: "У сервера нет конфига, его можно добавить в редакторе."
            case .invalidConfig: "Конфиг не похож на MCP: нужен блок mcpServers или поля command / url."
            case .clientFileUnreadable(let path): "Файл \(path) не разбирается как JSON, поэтому Toolbelt его не меняет."
            case .cliNotFound: "Не нашёл команду claude. Установи Claude Code или добавь его в PATH."
            case .cliFailed(let output): output.isEmpty ? "Команда claude завершилась с ошибкой." : output
            }
        }
    }

    // MARK: Parsing the shelf config

    /// Server entries from a config snippet: `{ "mcpServers": {...} }`, `{ "servers": {...} }` or one bare entry.
    static func entries(from config: String, fallbackName: String) throws -> [String: [String: Any]] {
        let text = config.trimmed
        guard !text.isEmpty else { throw InstallError.emptyConfig }
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InstallError.invalidConfig
        }
        for key in ["mcpServers", "servers", "mcp_servers", "context_servers"] {
            if let servers = object[key] as? [String: Any] {
                let entries = servers.compactMapValues { $0 as? [String: Any] }
                if !entries.isEmpty { return entries }
            }
        }
        if object["command"] != nil || object["url"] != nil {
            return [slug(fallbackName): object]
        }
        throw InstallError.invalidConfig
    }

    static func serverNames(for server: MCPServer) -> [String] {
        ((try? entries(from: server.configJSON, fallbackName: server.name)) ?? [:]).keys.sorted()
    }

    /// Template bits like `<YOUR_UNIQUE_ID>` or `/absolute/path/to` the user should replace first.
    static func placeholders(in config: String) -> [String] {
        var found: [String] = []
        if let regex = try? NSRegularExpression(pattern: #"<[^<>{}"\n]{2,40}>"#) {
            let range = NSRange(config.startIndex..., in: config)
            for match in regex.matches(in: config, range: range) {
                if let r = Range(match.range, in: config) { found.append(String(config[r])) }
            }
        }
        for marker in ["/absolute/path/to", "/path/to/", "your-api-key", "YOUR_API_KEY"] where config.contains(marker) {
            found.append(marker)
        }
        var seen = Set<String>()
        return found.filter { seen.insert($0).inserted }
    }

    static func slug(_ name: String) -> String {
        let lowered = name.lowercased()
            .replacingOccurrences(of: " mcp", with: "")
            .replacingOccurrences(of: "mcp ", with: "")
        let allowed = lowered.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let collapsed = String(allowed).split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "server" : collapsed
    }

    // MARK: Status

    static func status(of client: MCPClient) -> ClientStatus {
        guard client.isAvailable else {
            return ClientStatus(client: client, isAvailable: false, names: [], readError: nil)
        }
        let url = client.configURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ClientStatus(client: client, isAvailable: true, names: [], readError: nil)
        }
        switch client.format {
        case .json(let key):
            guard let root = readJSON(url) else {
                return ClientStatus(client: client, isAvailable: true, names: [], readError: "не JSON")
            }
            return ClientStatus(client: client, isAvailable: true,
                                names: Set((root[key] as? [String: Any])?.keys.map { $0 } ?? []), readError: nil)
        case .claudeCLI:
            let root = readJSON(url)
            return ClientStatus(client: client, isAvailable: true,
                                names: Set((root?["mcpServers"] as? [String: Any])?.keys.map { $0 } ?? []), readError: nil)
        case .codexTOML:
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return ClientStatus(client: client, isAvailable: true, names: CodexTOML.serverNames(in: text), readError: nil)
        }
    }

    // MARK: Install / remove

    /// Adds or replaces the server's entries in the client's config. Returns a short report.
    static func install(_ entries: [String: [String: Any]], into client: MCPClient) async throws -> String {
        switch client.format {
        case .json(let key):
            try editJSON(at: client.configURL) { root in
                var servers = root[key] as? [String: Any] ?? [:]
                for (name, entry) in entries { servers[name] = adapted(entry, for: client) }
                root[key] = servers
            }
        case .codexTOML:
            try editText(at: client.configURL) { text in
                for (name, entry) in entries.sorted(by: { $0.key < $1.key }) {
                    text = CodexTOML.removing(name, from: text)
                    text = CodexTOML.appending(name, entry: entry, to: text)
                }
            }
        case .claudeCLI:
            for (name, entry) in entries.sorted(by: { $0.key < $1.key }) {
                let json = String(data: try JSONSerialization.data(withJSONObject: adapted(entry, for: client),
                                                                   options: [.withoutEscapingSlashes]),
                                  encoding: .utf8) ?? "{}"
                _ = try? await runClaude(["mcp", "remove", "-s", "user", name])
                try await runClaude(["mcp", "add-json", "-s", "user", name, json])
            }
        }
        return "\(entries.keys.sorted().joined(separator: ", ")) → \(client.title)"
    }

    static func remove(_ names: [String], from client: MCPClient) async throws {
        switch client.format {
        case .json(let key):
            try editJSON(at: client.configURL) { root in
                var servers = root[key] as? [String: Any] ?? [:]
                names.forEach { servers.removeValue(forKey: $0) }
                root[key] = servers
            }
        case .codexTOML:
            try editText(at: client.configURL) { text in
                for name in names { text = CodexTOML.removing(name, from: text) }
            }
        case .claudeCLI:
            for name in names { try await runClaude(["mcp", "remove", "-s", "user", name]) }
        }
    }

    // MARK: Helpers

    /// VS Code and Claude Code want an explicit transport type.
    private static func adapted(_ entry: [String: Any], for client: MCPClient) -> [String: Any] {
        var entry = entry
        switch client {
        case .vscode, .claudeCode:
            if entry["type"] == nil {
                entry["type"] = entry["url"] != nil ? "http" : "stdio"
            }
        default:
            break
        }
        return entry
    }

    private static func readJSON(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if data.isEmpty { return [:] }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func backup(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backup = url.appendingPathExtension("toolbelt.bak")
        try? FileManager.default.removeItem(at: backup)
        try FileManager.default.copyItem(at: url, to: backup)
    }

    private static func editJSON(at url: URL, _ change: (inout [String: Any]) -> Void) throws {
        let display = url.path.replacingOccurrences(of: MCPClient.home.path, with: "~")
        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: url.path) {
            guard let parsed = readJSON(url) else { throw InstallError.clientFileUnreadable(display) }
            root = parsed
            try backup(url)
        } else {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        change(&root)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }

    private static func editText(at url: URL, _ change: (inout String) -> Void) throws {
        var text = ""
        if FileManager.default.fileExists(atPath: url.path) {
            text = try String(contentsOf: url, encoding: .utf8)
            try backup(url)
        } else {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        change(&text)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Runs the `claude` CLI through a login shell so it sees the user's PATH (node, Homebrew).
    @discardableResult
    private static func runClaude(_ arguments: [String]) async throws -> String {
        let script = """
        bin=$(command -v claude 2>/dev/null)
        [ -z "$bin" ] && for p in "$HOME/.claude/local/claude" "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude; do [ -x "$p" ] && bin="$p" && break; done
        [ -z "$bin" ] && exit 127
        "$bin" "$@"
        """
        let result = try await Shell.run("/bin/zsh", ["-lc", script, "toolbelt"] + arguments, timeout: .seconds(40))
        if result.status == 127 { throw InstallError.cliNotFound }
        guard result.status == 0 else { throw InstallError.cliFailed(result.output.trimmed) }
        return result.output
    }
}

// MARK: - Codex TOML

/// Minimal reader/writer for `[mcp_servers.<name>]` tables in Codex's config.toml.
enum CodexTOML {
    static func serverNames(in text: String) -> Set<String> {
        var names = Set<String>()
        for line in text.components(separatedBy: .newlines) {
            if let name = tableName(line), !name.contains(".") { names.insert(name) }
        }
        return names
    }

    static func appending(_ name: String, entry: [String: Any], to text: String) -> String {
        var lines: [String] = []
        let key = quotedKey(name)
        lines.append("[mcp_servers.\(key)]")
        if let command = entry["command"] as? String { lines.append("command = \(string(command))") }
        if let args = entry["args"] as? [Any] {
            lines.append("args = [\(args.map { string("\($0)") }.joined(separator: ", "))]")
        }
        if let url = entry["url"] as? String { lines.append("url = \(string(url))") }
        if let env = entry["env"] as? [String: Any], !env.isEmpty {
            lines.append("")
            lines.append("[mcp_servers.\(key).env]")
            for (k, v) in env.sorted(by: { $0.key < $1.key }) { lines.append("\(quotedKey(k)) = \(string("\(v)"))") }
        }
        var result = text
        if !result.isEmpty && !result.hasSuffix("\n") { result += "\n" }
        if !result.isEmpty { result += "\n" }
        return result + lines.joined(separator: "\n") + "\n"
    }

    /// Drops `[mcp_servers.<name>]` and its sub-tables.
    static func removing(_ name: String, from text: String) -> String {
        var output: [String] = []
        var skipping = false
        for line in text.components(separatedBy: "\n") {
            if let table = tableName(line) {
                skipping = table == name || table.hasPrefix(name + ".")
            } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("[") {
                skipping = false
            }
            if !skipping { output.append(line) }
        }
        var result = output.joined(separator: "\n")
        while result.contains("\n\n\n") { result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return result
    }

    /// `[mcp_servers.foo]` → `foo`, `[mcp_servers."foo bar".env]` → `foo bar.env`.
    private static func tableName(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[mcp_servers."), trimmed.hasSuffix("]"), !trimmed.hasPrefix("[[") else { return nil }
        let inner = trimmed.dropFirst("[mcp_servers.".count).dropLast()
        return inner.replacingOccurrences(of: "\"", with: "")
    }

    private static func quotedKey(_ key: String) -> String {
        let bare = key.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        return bare ? key : string(key)
    }

    private static func string(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

// MARK: - Shell

enum Shell {
    struct Result {
        let status: Int32
        let output: String
    }

    static func run(_ executable: String, _ arguments: [String], timeout: Duration) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { finished in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: Result(status: finished.terminationStatus,
                                                      output: String(data: data, encoding: .utf8) ?? ""))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }
            Task.detached {
                try? await Task.sleep(for: timeout)
                if process.isRunning { process.terminate() }
            }
        }
    }
}
