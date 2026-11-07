import SwiftUI
import AppKit

/// Calm graphite palette (no pure black or white text) with a single soft lime accent.
enum Theme {
    static let canvas = Color.dynamic(light: 0xF2F2F4, dark: 0x1A1B1F)
    static let card = Color.dynamic(light: 0xFFFFFF, dark: 0x232428)
    static let inset = Color.dynamic(light: 0xF4F4F6, dark: 0x2B2C31)
    /// Primary text.
    static let ink = Color.dynamic(light: 0x25272C, dark: 0xE2E3E7)
    /// Fill of selected rows, primary buttons and accent cards.
    static let fill = Color.dynamic(light: 0x2E3037, dark: 0x363941)
    static let fillHover = Color.dynamic(light: 0x3B3E46, dark: 0x41444D)
    /// Text drawn on top of `fill`.
    static let onFill = Color.dynamic(light: 0xF5F5F7, dark: 0xF0F1F3)
    static let secondary = Color.dynamic(light: 0x7C7E86, dark: 0x9C9EA6)
    static let tertiary = Color.dynamic(light: 0xACAEB5, dark: 0x6D6F77)
    static let hairline = Color.dynamic(light: 0xE3E4E8, dark: 0x303137)
    static let hairlineStrong = Color.dynamic(light: 0xCDCFD5, dark: 0x42444B)
    static let lime = Color(hex: 0xC9E36F)
    static let limeInk = Color(hex: 0x262B10)
    static let danger = Color(hex: 0xD9585C)
    /// Code blocks: graphite in light mode, a step below the card in dark mode.
    static let codeBackground = Color.dynamic(light: 0x25272D, dark: 0x16171A)
    /// Plate behind third-party logos, slightly dimmed in dark mode.
    static let logoPlate = Color.dynamic(light: 0xFFFFFF, dark: 0xDCDDE1)

    static let radius: CGFloat = 16
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Window appearance chosen in the View menu.
enum Appearance: String, CaseIterable, Identifiable {
    case light, dark, system

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .light: "sun.max"
        case .dark: "moon"
        case .system: "circle.lefthalf.filled"
        }
    }

    var title: String {
        switch self {
        case .light: "Светлое"
        case .dark: "Тёмное"
        case .system: "Как в системе"
        }
    }

    static let storageKey = "appearance"

    /// The saved choice; light until changed.
    @MainActor
    static var current: Appearance {
        UserDefaults.standard.string(forKey: storageKey).flatMap(Self.init) ?? .light
    }

    /// Saves the choice and applies it right away.
    @MainActor
    static func select(_ value: Appearance) {
        UserDefaults.standard.set(value.rawValue, forKey: storageKey)
        value.apply()
    }

    /// Applied to the whole app, so every window, sheet, alert and menu follows. `nil` hands the choice
    /// back to the system; SwiftUI's `preferredColorScheme(nil)` doesn't, and leaves the window half switched.
    @MainActor
    func apply() {
        NSApplication.shared.appearance = switch self {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .system: nil
        }
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    var searchTokens: [String] {
        split(whereSeparator: \.isWhitespace).map(String.init)
    }

    var nonEmptyLines: [String] {
        split(whereSeparator: \.isNewline).map { String($0).trimmed }.filter { !$0.isEmpty }
    }
}

enum TextStyler {
    /// Marks every occurrence of the query tokens inside `text`.
    static func highlight(_ text: String, query: String, color: Color) -> AttributedString {
        var result = AttributedString(text)
        for token in query.searchTokens {
            var lower = result.startIndex
            while lower < result.endIndex,
                  let range = result[lower...].range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) {
                result[range].foregroundColor = color
                result[range].inlinePresentationIntent = .stronglyEmphasized
                lower = range.upperBound
            }
        }
        return result
    }

    /// Inline Markdown (`code`, **bold**) for user-written steps.
    static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

/// Russian plural form: 1 сервер, 2 сервера, 5 серверов.
func pluralRu(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
    let mod10 = count % 10
    let mod100 = count % 100
    if mod10 == 1 && mod100 != 11 { return one }
    if (2...4).contains(mod10) && !(12...14).contains(mod100) { return few }
    return many
}

func serversCount(_ count: Int) -> String {
    "\(count.formatted(.number.locale(Locale(identifier: "ru_RU")))) \(pluralRu(count, "сервер", "сервера", "серверов"))"
}

let russianDate = Date.FormatStyle.dateTime.day().month(.wide).year().locale(Locale(identifier: "ru_RU"))
