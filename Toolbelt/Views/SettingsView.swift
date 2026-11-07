import SwiftUI
import SwiftData
import WebKit
import AppKit

/// The app's Settings window (⌘,).
struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var context
    @State private var registry = ClientRegistry.shared
    @AppStorage("install.preferredClient") private var preferredClient = ""
    @State private var catalogStatus: String?
    @AppStorage(DeveloperPicks.hiddenKey) private var picksHidden = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Panel(title: "Оформление", trailing: "⇧⌘L: светлая или тёмная") {
                    AppearancePicker()
                }

                Panel(title: "Установка в клиенты") {
                    InfoRow(label: "Клиент по умолчанию") {
                        Picker("", selection: $preferredClient) {
                            Text("Первый найденный").tag("")
                            ForEach(registry.available) { status in
                                Text(status.client.title).tag(status.client.rawValue)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    Text("Его ставит главная кнопка «Установить в …». Найдено на этом Mac: \(registry.available.map(\.client.title).joined(separator: ", ")).")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Panel(title: "Каталог mcpservers.org") {
                    HStack {
                        PillButton(title: "Сбросить данные сайта", symbol: "arrow.counterclockwise") {
                            Task { await resetCatalogData() }
                        }
                        Spacer()
                    }
                    Text(catalogStatus ?? "Cookies и кэш встроенного браузера. Поможет, если каталог перестал загружаться или застрял на проверке Cloudflare.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Panel(title: "Хранилище") {
                    InfoRow(label: "Набор навыков") {
                        Text(ToolbeltApp.storeFolder.path.replacingOccurrences(of: MCPClient.home.path, with: "~"))
                            .font(.system(size: 11.5, design: .monospaced))
                    }
                    HStack(spacing: 8) {
                        PillButton(title: "Показать в Finder", symbol: "folder") {
                            NSWorkspace.shared.activateFileViewerSelecting([ToolbeltApp.storeFolder])
                        }
                        Spacer()
                    }
                    Toggle("Показывать рекомендацию разработчика на главной", isOn: Binding(get: { !picksHidden }, set: { picksHidden = !$0 }))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(.system(size: 12.5))
                }

                Panel(title: "О приложении") {
                    VStack(spacing: 6) {
                        InfoRow(label: "Версия") { Text("\(AppInfo.version) (\(AppInfo.build))") }
                        InfoRow(label: "Разработчик") {
                            Link("github.com/mrgsdev", destination: AppLinks.developer)
                        }
                        InfoRow(label: "Исходный код") {
                            Link("github.com/mrgsdev/Toolbelt", destination: AppLinks.repository)
                        }
                    }
                    .tint(Theme.ink)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        PillButton(title: "Проверить обновления…", symbol: "arrow.triangle.2.circlepath") {
                            openWindow(id: "update")
                            Task { await Updater.shared.checkNow() }
                        }
                        PillButton(title: "Знакомство с Toolbelt", symbol: "sparkles") {
                            Router.shared.showsOnboarding = true
                            openWindow(id: "main")
                        }
                        PillButton(title: "Горячие клавиши", symbol: "keyboard") { openWindow(id: "shortcuts") }
                        PillButton(title: "Отказ от ответственности и лицензии…", symbol: "info.circle") {
                            openWindow(id: "legal")
                        }
                    }
                    Text("Toolbelt не связан с mcpservers.org и разработчиками MCP-клиентов.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .padding(24)
        }
        .frame(width: 600, height: 680)
        .background(Theme.canvas)
        .task { await registry.refresh() }
    }

    /// Clears the catalog web view's cookies and caches; the next load passes the site's check again.
    private func resetCatalogData() async {
        let store = WKWebsiteDataStore.default()
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        CatalogService.shared.invalidate()
        catalogStatus = "Данные сайта сброшены. Каталог загрузится заново при следующем открытии."
    }
}
