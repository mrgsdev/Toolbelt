import SwiftUI

/// «Справка → Горячие клавиши»: every shortcut the app has, grouped like the app itself.
struct ShortcutsView: View {
    private struct Shortcut: Identifiable {
        let keys: [String]
        let action: String
        let id = UUID()
    }

    private struct ShortcutGroup: Identifiable {
        let title: String
        let shortcuts: [Shortcut]
        let id = UUID()
    }

    /// Two columns, so the whole list is in view at once.
    private static let left: [ShortcutGroup] = [
        ShortcutGroup(title: "Разделы", shortcuts: [
            Shortcut(keys: ["⌘", "1"], action: "Набор навыков"),
            Shortcut(keys: ["⌘", "2"], action: "Избранное"),
            Shortcut(keys: ["⌘", "3"], action: "Подключённые"),
            Shortcut(keys: ["⌘", "4"], action: "Каталог: Разработка"),
            Shortcut(keys: ["⌘", "5"], action: "Каталог: Официальные"),
            Shortcut(keys: ["⌘", "6"], action: "Весь каталог"),
            Shortcut(keys: ["⌘", "F"], action: "Поиск"),
            Shortcut(keys: ["↩"], action: "В разделах каталога: искать по всему mcpservers.org"),
        ]),
        ShortcutGroup(title: "Список", shortcuts: [
            Shortcut(keys: ["↑", "↓"], action: "Предыдущий или следующий сервер в наборе"),
            Shortcut(keys: ["⌘", "R"], action: "Обновить каталог и статусы клиентов"),
        ]),
    ]

    private static let right: [ShortcutGroup] = [
        ShortcutGroup(title: "Сервер", shortcuts: [
            Shortcut(keys: ["⌘", "N"], action: "Новый MCP-сервер"),
            Shortcut(keys: ["⌘", "E"], action: "Редактировать"),
            Shortcut(keys: ["⌘", "D"], action: "В избранное или из него"),
            Shortcut(keys: ["⌘", "I"], action: "Установка в клиенты"),
            Shortcut(keys: ["⇧", "⌘", "C"], action: "Скопировать конфиг"),
            Shortcut(keys: ["⇧", "⌘", "O"], action: "Открыть сайт"),
            Shortcut(keys: ["⌘", "⌫"], action: "Удалить из набора"),
        ]),
        ShortcutGroup(title: "Окна и вид", shortcuts: [
            Shortcut(keys: ["⌘", "0"], action: "Главное окно, в том числе после закрытия"),
            Shortcut(keys: ["⇧", "⌘", "L"], action: "Светлая или тёмная тема"),
            Shortcut(keys: ["⌘", ","], action: "Настройки"),
            Shortcut(keys: ["⌘", "/"], action: "Эта справка"),
            Shortcut(keys: ["⌘", "W"], action: "Закрыть окно"),
            Shortcut(keys: ["⌘", "Q"], action: "Выйти из Toolbelt"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Горячие клавиши")
                    .font(.system(size: 24, weight: .regular))
                    .tracking(-0.4)
                Text("Те же действия есть в меню «Разделы», «Сервер» и «Вид».")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
            }
            HStack(alignment: .top, spacing: 16) {
                column(Self.left)
                column(Self.right)
            }
        }
        .padding(26)
        .frame(width: 900)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.canvas)
    }

    private func column(_ groups: [ShortcutGroup]) -> some View {
        VStack(spacing: 16) {
            ForEach(groups) { group in
                Panel(title: group.title) {
                    VStack(spacing: 0) {
                        ForEach(Array(group.shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                            HStack(spacing: 12) {
                                Text(shortcut.action)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 12)
                                HStack(spacing: 4) {
                                    ForEach(shortcut.keys, id: \.self) { KeyCap(key: $0) }
                                }
                            }
                            .padding(.vertical, 7)
                            if index < group.shortcuts.count - 1 {
                                Rectangle().fill(Theme.hairline).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

/// One key drawn like a key on the keyboard.
struct KeyCap: View {
    let key: String

    var body: some View {
        Text(verbatim: key)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .frame(minWidth: 22)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.inset, in: .rect(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.hairlineStrong)
            }
    }
}
