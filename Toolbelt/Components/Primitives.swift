import SwiftUI

// MARK: - Icon tile

/// Monochrome square with an SF Symbol; inverted on selected rows.
struct IconTile: View {
    let symbol: String
    var size: CGFloat = 36
    var inverted = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundStyle(inverted ? Theme.onFill : Theme.ink)
            .frame(width: size, height: size)
            .background(inverted ? Theme.onFill.opacity(0.12) : Theme.inset, in: shape)
            .overlay { shape.strokeBorder(inverted ? Theme.onFill.opacity(0.14) : Theme.hairline) }
    }
}

// MARK: - Pills

enum PillStyle {
    case primary, secondary, quiet
}

/// Rounded capsule button: black primary, outlined secondary.
struct PillButton: View {
    let title: String
    var symbol: String?
    var style: PillStyle = .secondary
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 11.5, weight: .semibold)) }
                Text(title).font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(background, in: .capsule)
            .overlay { Capsule().strokeBorder(style == .secondary ? Theme.hairlineStrong : .clear) }
            .contentShape(.capsule)
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        style == .primary ? Theme.onFill : Theme.ink
    }

    private var background: Color {
        switch style {
        case .primary: isHovering ? Theme.fillHover : Theme.fill
        case .secondary: isHovering ? Theme.inset : Theme.card
        case .quiet: isHovering ? Theme.inset : .clear
        }
    }
}

/// Segmented pill tabs; the selected tab is filled black.
struct PillTabs<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(values, id: \.self) { value in
                let isSelected = value == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = value }
                } label: {
                    Text(title(value))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.onFill : Theme.secondary)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(isSelected ? Theme.fill : .clear, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.card, in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.hairline) }
    }
}

/// Small outlined capsule for tags and meta.
struct TagPill: View {
    let text: String
    var inverted = false

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 10.5, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(inverted ? Theme.onFill.opacity(0.75) : Theme.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .overlay { Capsule().strokeBorder(inverted ? Theme.onFill.opacity(0.25) : Theme.hairlineStrong) }
    }
}

/// Lime dot + label, the only colored state in the UI.
struct LiveBadge: View {
    let text: String
    var inverted = false

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(Theme.lime).frame(width: 6, height: 6)
            Text(text).font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(inverted ? Theme.onFill.opacity(0.8) : Theme.ink)
    }
}

// MARK: - Cards & sections

/// White card with a small uppercase-free title.
struct Panel<Content: View>: View {
    var title: String?
    var trailing: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                HStack {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if let trailing {
                        Text(trailing).font(.system(size: 11.5)).foregroundStyle(Theme.secondary)
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.card, in: .rect(cornerRadius: Theme.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline)
        }
    }
}

/// Label on the left, value on the right, like a spec sheet.
struct InfoRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 16)
            value
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}

/// Large thin number with a caption, inspired by dashboard metrics.
struct MetricCard: View {
    let value: String
    let title: String
    var note: String?
    var dark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(dark ? Theme.onFill.opacity(0.65) : Theme.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 38, weight: .light))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(dark ? Theme.onFill : Theme.ink)
                .contentTransition(.numericText())
            Text(note ?? " ")
                .font(.system(size: 11))
                .foregroundStyle(dark ? Theme.onFill.opacity(0.55) : Theme.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(dark ? Theme.fill : Theme.card, in: .rect(cornerRadius: Theme.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(dark ? .clear : Theme.hairline)
        }
    }
}

/// Row of metric cards that share one height.
struct MetricRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) { content }
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Rating

struct RatingView: View {
    @Binding var rating: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    withAnimation(.snappy) { rating = rating == value ? 0 : value }
                } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.system(size: size))
                        .foregroundStyle(value <= rating ? Theme.ink : Theme.tertiary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value) из 5")
            }
        }
    }
}

// MARK: - Button style

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Flow layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let candidate = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if candidate > maxWidth, !current.indices.isEmpty {
                let nextY = current.y + current.height + lineSpacing
                rows.append(current)
                current = Row(indices: [index], y: nextY, width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = candidate
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Toast

struct ToastMessage: Equatable {
    let id = UUID()
    let text: String
    var symbol = "checkmark"
}

private struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let current = message {
                    HStack(spacing: 8) {
                        Image(systemName: current.symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.limeInk)
                            .frame(width: 18, height: 18)
                            .background(Theme.lime, in: .circle)
                        Text(current.text)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.onFill)
                            .lineLimit(2)
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 16)
                    .padding(.vertical, 8)
                    .background(Theme.fill, in: .capsule)
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: current.id) {
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation(.smooth) { message = nil }
                    }
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.2), value: message)
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
