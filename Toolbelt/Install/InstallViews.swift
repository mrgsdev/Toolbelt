import SwiftUI
import AppKit

/// Live view of every client's config, refreshed after each change.
@Observable
@MainActor
final class ClientRegistry {
    static let shared = ClientRegistry()

    private(set) var statuses: [ClientStatus] = MCPClient.allCases.map {
        ClientStatus(client: $0, isAvailable: false, names: [], readError: nil)
    }

    var available: [ClientStatus] { statuses.filter(\.isAvailable) }

    func refresh() async {
        statuses = await Task.detached(priority: .userInitiated) {
            MCPClient.allCases.map { ConfigInstaller.status(of: $0) }
        }.value
    }

    func status(_ client: MCPClient) -> ClientStatus? {
        statuses.first { $0.client == client }
    }

    /// Clients that already contain one of these server names.
    func clients(containing names: [String]) -> [MCPClient] {
        guard !names.isEmpty else { return [] }
        return statuses.filter { status in names.contains { status.names.contains($0) } }.map(\.client)
    }
}

/// Install / remove flow shared by the header button and the clients panel.
@Observable
@MainActor
final class InstallController {
    var busy: MCPClient?
    var pending: MCPClient?
    var placeholders: [String] = []
    var errorText: String?
    var toast: ToastMessage?

    func install(_ server: MCPServer, to client: MCPClient, registry: ClientRegistry, force: Bool = false) async {
        errorText = nil
        let found = ConfigInstaller.placeholders(in: server.configJSON)
        if !force && !found.isEmpty {
            placeholders = found
            pending = client
            return
        }
        busy = client
        defer { busy = nil }
        do {
            let entries = try ConfigInstaller.entries(from: server.configJSON, fallbackName: server.name)
            _ = try await ConfigInstaller.install(entries, into: client)
            server.isInstalled = true
            await registry.refresh()
            UserDefaults.standard.set(client.rawValue, forKey: "install.preferredClient")
            let hint = client.restartHint.map { " " + $0 } ?? ""
            toast = ToastMessage(text: "\(server.name) добавлен в \(client.title).\(hint)")
        } catch {
            errorText = error.localizedDescription
        }
    }

    func remove(_ server: MCPServer, from client: MCPClient, registry: ClientRegistry) async {
        errorText = nil
        busy = client
        defer { busy = nil }
        do {
            let names = ConfigInstaller.serverNames(for: server)
            try await ConfigInstaller.remove(names, from: client)
            await registry.refresh()
            server.isInstalled = !registry.clients(containing: names).isEmpty
            toast = ToastMessage(text: "\(server.name) убран из \(client.title)", symbol: "minus")
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// Black split pill: installs into the preferred client, the menu picks another one.
struct InstallButton: View {
    let server: MCPServer
    let installer: InstallController

    @Environment(ClientRegistry.self) private var registry
    @AppStorage("install.preferredClient") private var preferredRaw = ""

    private var names: [String] { ConfigInstaller.serverNames(for: server) }

    private var target: MCPClient? {
        let available = registry.available.map(\.client)
        if let preferred = MCPClient(rawValue: preferredRaw), available.contains(preferred) { return preferred }
        return available.first
    }

    var body: some View {
        let installedIn = registry.clients(containing: names)
        HStack(spacing: 0) {
            Button {
                if let target { Task { await installer.install(server, to: target, registry: registry) } }
            } label: {
                HStack(spacing: 6) {
                    if installer.busy != nil {
                        ProgressView().controlSize(.mini).tint(Theme.onFill)
                    } else {
                        Image(systemName: "arrow.down.to.line").font(.system(size: 11.5, weight: .semibold))
                    }
                    Text(label(installedIn: installedIn)).font(.system(size: 12.5, weight: .medium))
                }
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .frame(height: 30)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(target == nil || names.isEmpty || installer.busy != nil)

            Rectangle().fill(Theme.onFill.opacity(0.2)).frame(width: 1, height: 16)

            Menu {
                ForEach(registry.available) { status in
                    Button {
                        Task { await installer.install(server, to: status.client, registry: registry) }
                    } label: {
                        let isIn = installedIn.contains(status.client)
                        Label(isIn ? "Обновить в \(status.client.title)" : "Установить в \(status.client.title)",
                              systemImage: isIn ? "checkmark" : status.client.symbol)
                    }
                }
                if !installedIn.isEmpty {
                    Divider()
                    ForEach(installedIn) { client in
                        Button("Убрать из \(client.title)", systemImage: "minus.circle") {
                            Task { await installer.remove(server, from: client, registry: registry) }
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 28, height: 30)
                    .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(names.isEmpty || registry.available.isEmpty)
        }
        .foregroundStyle(Theme.onFill)
        .background(Theme.fill, in: .capsule)
        .opacity(names.isEmpty ? 0.4 : 1)
        .help(names.isEmpty ? "Сначала добавь JSON-конфиг" : "Записать конфиг в MCP-клиент")
    }

    private func label(installedIn: [MCPClient]) -> String {
        guard let target else { return "Нет клиентов" }
        return installedIn.contains(target) ? "Обновить в \(target.title)" : "Установить в \(target.title)"
    }
}

/// Every known client with its status and one-click actions.
struct ClientsPanel: View {
    let server: MCPServer
    let installer: InstallController

    @Environment(ClientRegistry.self) private var registry

    private var names: [String] { ConfigInstaller.serverNames(for: server) }

    var body: some View {
        Panel(title: "Клиенты", trailing: names.isEmpty ? nil : "имя в конфиге: " + names.joined(separator: ", ")) {
            if names.isEmpty {
                Text("Чтобы ставить в один клик, добавь серверу JSON-конфиг с блоком mcpServers.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.secondary)
            } else {
                VStack(spacing: 0) {
                    let ordered = registry.statuses.sorted { $0.isAvailable && !$1.isAvailable }
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, status in
                        ClientRowView(status: status, names: names, isBusy: installer.busy == status.client) {
                            Task { await installer.install(server, to: status.client, registry: registry) }
                        } onRemove: {
                            Task { await installer.remove(server, from: status.client, registry: registry) }
                        }
                        if index < ordered.count - 1 {
                            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 46)
                        }
                    }
                }
            }
            if let error = installer.errorText {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Перед записью рядом с файлом сохраняется копия *.toolbelt.bak. Claude Code настраивается через claude mcp add-json.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task {
            await registry.refresh()
            if !registry.clients(containing: names).isEmpty { server.isInstalled = true }
        }
    }
}

private struct ClientRowView: View {
    let status: ClientStatus
    let names: [String]
    let isBusy: Bool
    let onInstall: () -> Void
    let onRemove: () -> Void

    private var isInstalled: Bool { names.contains { status.names.contains($0) } }

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: status.client.symbol, size: 34)
                .opacity(status.isAvailable ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.client.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(status.isAvailable ? Theme.ink : Theme.tertiary)
                Text(status.isAvailable ? status.client.displayPath : "не найден на этом Mac")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            if isBusy {
                ProgressView().controlSize(.small)
            } else if status.isAvailable {
                if let error = status.readError {
                    Text(error).font(.system(size: 11)).foregroundStyle(Theme.danger)
                }
                if isInstalled {
                    LiveBadge(text: "установлен")
                    PillButton(title: "Обновить", style: .quiet, action: onInstall)
                    PillButton(title: "Убрать", style: .secondary, action: onRemove)
                } else {
                    PillButton(title: "Установить", symbol: "arrow.down.to.line", style: .primary, action: onInstall)
                }
                Button {
                    let url = status.client.configURL
                    if FileManager.default.fileExists(atPath: url.path) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } else {
                        NSWorkspace.shared.open(url.deletingLastPathComponent())
                    }
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 26, height: 26)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Показать файл в Finder")
            }
        }
        .padding(.vertical, 9)
    }
}

/// Alert shown when the config still contains template placeholders.
struct PlaceholderAlert: ViewModifier {
    let server: MCPServer?
    let installer: InstallController
    let registry: ClientRegistry
    var onEdit: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            "В конфиге остались заглушки",
            isPresented: Binding(get: { installer.pending != nil }, set: { if !$0 { installer.pending = nil } })
        ) {
            Button("Отредактировать") {
                installer.pending = nil
                onEdit()
            }
            Button("Установить как есть") {
                if let client = installer.pending, let server {
                    installer.pending = nil
                    Task { await installer.install(server, to: client, registry: registry, force: true) }
                }
            }
            Button("Отмена", role: .cancel) { installer.pending = nil }
        } message: {
            Text("Замени \(installer.placeholders.joined(separator: ", ")) на свои значения, иначе клиент не сможет запустить сервер.")
        }
    }
}
