import SwiftUI
import SwiftData

// MARK: - Shelf row

struct ServerRow: View {
    let server: MCPServer
    var highlight = ""
    var isSelected = false

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: server.symbol, size: 36, inverted: isSelected)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(styled(server.name))
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if server.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? Theme.onFill.opacity(0.8) : Theme.ink)
                            .help("В избранном")
                    }
                }
                Text(styled(server.tagline))
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Theme.onFill.opacity(0.65) : Theme.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    TagPill(text: server.category.title, inverted: isSelected)
                    if server.pricing != .unknown {
                        TagPill(text: server.pricing.shortTitle, inverted: isSelected)
                    }
                    Spacer(minLength: 0)
                    if server.isInstalled {
                        LiveBadge(text: "подключён", inverted: isSelected)
                    }
                }
                .padding(.top, 3)
            }
        }
        .foregroundStyle(isSelected ? Theme.onFill : Theme.ink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RowBackground(isSelected: isSelected, isHovering: isHovering))
        .contentShape(.rect(cornerRadius: 14, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.18), value: isHovering)
        .animation(.snappy(duration: 0.18), value: isSelected)
    }

    private func styled(_ text: String) -> AttributedString {
        highlight.trimmed.isEmpty
            ? AttributedString(text)
            : TextStyler.highlight(text, query: highlight, color: isSelected ? Theme.lime : Theme.ink)
    }
}

struct RowBackground: View {
    var isSelected = false
    var isHovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        shape
            .fill(isSelected ? Theme.fill : Theme.card)
            .overlay {
                shape.strokeBorder(isSelected ? .clear : (isHovering ? Theme.hairlineStrong : Theme.hairline))
            }
            .shadow(color: .black.opacity(isSelected ? 0.1 : 0), radius: 10, y: 4)
    }
}

/// Context menu shared by shelf rows.
struct ServerContextMenu: View {
    let server: MCPServer
    var onDelete: () -> Void

    var body: some View {
        Button(server.isFavorite ? "Убрать из избранного" : "В избранное",
               systemImage: server.isFavorite ? "star.slash" : "star") {
            server.isFavorite.toggle()
        }
        Button(server.isInstalled ? "Снять отметку «подключён»" : "Отметить подключённым",
               systemImage: server.isInstalled ? "xmark.circle" : "checkmark.circle") {
            server.isInstalled.toggle()
        }
        if !server.configJSON.isEmpty {
            Button("Скопировать конфиг", systemImage: "doc.on.doc") {
                Clipboard.copy(server.configJSON)
            }
        }
        if let url = server.primaryURL {
            Link(destination: url) {
                Label("Открыть сайт", systemImage: "safari")
            }
        }
        Divider()
        Button("Удалить", systemImage: "trash", role: .destructive, action: onDelete)
    }
}

// MARK: - Catalog row

struct CatalogRow: View {
    let entry: CatalogEntry
    var isSelected = false
    var isOnShelf = false

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CatalogLogo(entry: entry, size: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    if entry.official {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(isSelected ? Theme.onFill.opacity(0.8) : Theme.ink)
                            .help("Официальный сервер")
                    }
                    Spacer(minLength: 4)
                }
                Text(entry.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Theme.onFill.opacity(0.65) : Theme.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if !entry.category.isEmpty {
                        TagPill(text: entry.category, inverted: isSelected)
                    }
                    if entry.sponsored {
                        TagPill(text: "спонсор", inverted: isSelected)
                    }
                    Spacer(minLength: 0)
                    if isOnShelf {
                        LiveBadge(text: "в наборе", inverted: isSelected)
                    }
                }
                .padding(.top, 3)
            }
        }
        .foregroundStyle(isSelected ? Theme.onFill : Theme.ink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RowBackground(isSelected: isSelected, isHovering: isHovering))
        .contentShape(.rect(cornerRadius: 14, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.18), value: isHovering)
        .animation(.snappy(duration: 0.18), value: isSelected)
    }
}

/// Server logo from mcpservers.org in grayscale, with a symbol fallback.
struct CatalogLogo: View {
    let entry: CatalogEntry
    var size: CGFloat = 36

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        AsyncImage(url: entry.logoURL, transaction: Transaction(animation: .smooth)) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .scaledToFit()
                    .grayscale(1)
                    .padding(size * 0.16)
                    .frame(width: size, height: size)
                    .background(Theme.logoPlate, in: shape)
                    .overlay { shape.strokeBorder(Theme.hairline) }
            } else {
                IconTile(symbol: entry.siteCategory?.symbol ?? "puzzlepiece.extension", size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Placeholder rows while the first page loads.
struct SkeletonRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.inset)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(Theme.inset).frame(width: 130, height: 10)
                Capsule().fill(Theme.inset).frame(height: 8)
                Capsule().fill(Theme.inset).frame(width: 180, height: 8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RowBackground())
        .phaseAnimator([0.5, 1]) { content, value in
            content.opacity(value)
        } animation: { _ in .easeInOut(duration: 0.9) }
    }
}

// MARK: - Dashboard cards

/// Dark card for favorites.
struct FeaturedCard: View {
    let server: MCPServer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                IconTile(symbol: server.symbol, size: 34, inverted: true)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.onFill)
                    .frame(width: 28, height: 28)
                    .overlay { Circle().strokeBorder(Theme.onFill.opacity(0.25)) }
            }
            Spacer(minLength: 18)
            Text(server.name)
                .font(.system(size: 17, weight: .medium))
                .lineLimit(1)
            Text(server.tagline)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.onFill.opacity(0.6))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.top, 3)
            HStack {
                Text(server.category.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.onFill.opacity(0.5))
                Spacer()
                if server.isInstalled { LiveBadge(text: "подключён", inverted: true) }
            }
            .padding(.top, 12)
        }
        .foregroundStyle(Theme.onFill)
        .padding(16)
        .frame(height: 170)
        .frame(maxWidth: .infinity)
        .background(Theme.fill, in: .rect(cornerRadius: Theme.radius, style: .continuous))
    }
}

struct CategoryTile: View {
    let title: String
    let symbol: String
    let subtitle: String

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.tertiary)
        }
        .foregroundStyle(Theme.ink)
        .padding(12)
        .background(RowBackground(isHovering: isHovering))
        .onHover { isHovering = $0 }
    }
}
