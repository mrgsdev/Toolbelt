import SwiftUI
import AppKit

/// The update window: offers a newer release with its notes under «Что нового»,
/// or says the app is up to date when the check was started from the menu.
struct UpdateView: View {
    @State private var updater = Updater.shared
    @State private var showsNotes = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.canvas)
        .onAppear {
            if updater.state == .idle {
                Task { await updater.checkNow() }
            }
        }
        .onDisappear { updater.windowClosed() }
    }

    @ViewBuilder
    private var content: some View {
        switch updater.state {
        case .idle, .checking:
            title("Проверка обновлений")
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Ищем новую версию на GitHub…")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.secondary)
            }
            buttons {
                PillButton(title: "Отмена") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

        case .upToDate:
            title("У вас последняя версия")
            Text("Toolbelt \(AppInfo.version) уже самая новая версия.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.secondary)
            buttons {
                PillButton(title: "Все релизы", symbol: "arrow.up.right") { openURL(Updater.releasesPage) }
                PillButton(title: "Готово", style: .primary) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

        case .available(let release):
            title("Доступна новая версия Toolbelt")
            Text("Вышла версия \(release.version), у вас \(AppInfo.version). Скачайте её и перетащите Toolbelt в «Программы» с заменой, набор и настройки сохранятся.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if release.version == updater.skippedVersion {
                Label("Вы пропустили эту версию: сама она больше не предлагается.", systemImage: "forward")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
            }
            if let notes = release.body?.trimmed, !notes.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showsNotes.toggle() }
                } label: {
                    Label("Что нового", systemImage: showsNotes ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.ink)
                if showsNotes {
                    ScrollView {
                        ReleaseNotes(text: notes)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 240)
                    .background(Theme.card, in: .rect(cornerRadius: 12, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline) }
                }
            }
            HStack(spacing: 8) {
                if release.version != updater.skippedVersion {
                    PillButton(title: "Пропустить эту версию", style: .quiet) {
                        updater.skip(release)
                        dismiss()
                    }
                    .help("Не предлагать версию \(release.version). О следующей Toolbelt сообщит как обычно.")
                }
                Spacer()
                PillButton(title: "Позже") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                PillButton(title: "Скачать", symbol: "arrow.down.to.line", style: .primary) {
                    openURL(release.downloadURL)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)

        case .failed(let message):
            title("Не удалось проверить обновления")
            Text(message)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            buttons {
                PillButton(title: "Все релизы", symbol: "arrow.up.right") { openURL(Updater.releasesPage) }
                PillButton(title: "Повторить", style: .primary) { Task { await updater.checkNow() } }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.system(size: 17, weight: .semibold))
    }

    private func buttons(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 8) {
            Spacer()
            content()
        }
        .padding(.top, 4)
    }
}

/// Release notes from GitHub: headings, list items and paragraphs with inline Markdown.
private struct ReleaseNotes: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(text.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, raw in
                let line = raw.trimmed
                if line.isEmpty {
                    EmptyView()
                } else if line.hasPrefix("#") {
                    Text(TextStyler.markdown(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)))
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 4)
                } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Rectangle().fill(Theme.ink).frame(width: 4, height: 4)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                        Text(TextStyler.markdown(String(line.dropFirst(2))))
                            .font(.system(size: 12.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(TextStyler.markdown(line))
                        .font(.system(size: 12.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .textSelection(.enabled)
    }
}
