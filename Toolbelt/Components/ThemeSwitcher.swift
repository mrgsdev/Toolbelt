import SwiftUI

/// Compact three-way switch: light, dark, follow the system.
struct ThemeSwitcher: View {
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .light

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Appearance.allCases) { option in
                let isSelected = option == appearance
                Button {
                    Appearance.select(option)
                } label: {
                    Image(systemName: option.symbol)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.onFill : Theme.secondary)
                        .frame(width: 32, height: 24)
                        .background(isSelected ? Theme.fill : .clear, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .help(option.title)
                .accessibilityLabel(option.title)
            }
        }
        .padding(2)
        .background(Theme.card, in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.hairline) }
    }
}

/// Three preview cards, used in Settings.
struct AppearancePicker: View {
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .light

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Appearance.allCases) { option in
                let isSelected = option == appearance
                Button {
                    Appearance.select(option)
                } label: {
                    VStack(spacing: 10) {
                        ThemePreview(option: option)
                            .frame(width: 150, height: 96)
                            .clipShape(.rect(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(isSelected ? Theme.fill : Theme.hairline, lineWidth: isSelected ? 2 : 1)
                            }
                        HStack(spacing: 6) {
                            Image(systemName: option.symbol).font(.system(size: 11))
                            Text(option.title).font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        }
                        .foregroundStyle(isSelected ? Theme.ink : Theme.secondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Miniature window drawn with fixed colors of each theme.
private struct ThemePreview: View {
    let option: Appearance

    var body: some View {
        switch option {
        case .light: MiniWindow(dark: false)
        case .dark: MiniWindow(dark: true)
        case .system:
            MiniWindow(dark: false)
                .overlay {
                    MiniWindow(dark: true)
                        .mask(alignment: .trailing) {
                            Rectangle().frame(width: 78)
                        }
                }
        }
    }
}

private struct MiniWindow: View {
    let dark: Bool

    private func c(_ light: UInt32, _ dark: UInt32) -> Color { Color(hex: self.dark ? dark : light) }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 3) {
                    ForEach([0xED6A5E, 0xF4BF4F, 0x61C554] as [UInt32], id: \.self) { Circle().fill(Color(hex: $0)).frame(width: 5, height: 5) }
                }
                .padding(.bottom, 4)
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index == 0 ? c(0xD9DADF, 0x3A3C43) : c(0xE4E5E9, 0x2E2F35))
                        .frame(width: index == 0 ? 30 : 24, height: 5)
                }
                Spacer()
            }
            .padding(8)
            .frame(width: 46)
            .frame(maxHeight: .infinity)
            .background(c(0xEBEBEE, 0x202125))

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(c(0x2E3037, 0x363941))
                    .frame(height: 22)
                    .overlay(alignment: .leading) {
                        Capsule().fill(c(0xF5F5F7, 0xF0F1F3).opacity(0.85)).frame(width: 40, height: 4).padding(.leading, 7)
                    }
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(c(0xFFFFFF, 0x232428))
                        .frame(height: 22)
                        .overlay(alignment: .leading) {
                            Capsule().fill(c(0xD5D6DB, 0x45474E)).frame(width: 52, height: 4).padding(.leading, 7)
                        }
                }
                HStack {
                    Spacer()
                    Circle().fill(Color(hex: 0xC9E36F)).frame(width: 6, height: 6)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(c(0xF2F2F4, 0x1A1B1F))
        }
    }
}
