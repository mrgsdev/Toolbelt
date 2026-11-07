import SwiftUI

struct CodeBlock: View {
    let code: String
    var title = "mcp.json"
    var onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Theme.lime).frame(width: 6, height: 6)
                Text(verbatim: title)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button(action: onCopy) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc").font(.system(size: 10.5, weight: .semibold))
                        Text("Копировать").font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .overlay { Capsule().strokeBorder(.white.opacity(0.2)) }
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)

            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(height: 1)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(JSONHighlighter.highlight(code))
                    .font(.system(size: 12, design: .monospaced))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(14)
            }
        }
        .background(Theme.codeBackground, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline)
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Tiny tokenizer that colors keys, strings, literals and punctuation of a JSON snippet.
enum JSONHighlighter {
    static let keyColor = Color(hex: 0xD4F25C)
    static let stringColor = Color(hex: 0xEDEDEF)
    static let literalColor = Color(hex: 0xA9A9AE)
    static let punctuationColor = Color(hex: 0x6B6B70)
    static let plainColor = Color(hex: 0xDADADD)

    static func highlight(_ source: String) -> AttributedString {
        let trimmed = source.trimmed
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else {
            var plain = AttributedString(source)
            plain.foregroundColor = plainColor
            return plain
        }

        let chars = Array(source)
        var output = AttributedString()
        var buffer = ""
        var bufferColor = plainColor

        func flush() {
            guard !buffer.isEmpty else { return }
            var piece = AttributedString(buffer)
            piece.foregroundColor = bufferColor
            output.append(piece)
            buffer = ""
        }

        func emit(_ text: String, _ color: Color) {
            if color != bufferColor {
                flush()
                bufferColor = color
            }
            buffer += text
        }

        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                var j = i + 1
                while j < chars.count && chars[j] != "\"" {
                    j += chars[j] == "\\" ? 2 : 1
                }
                let end = min(j, chars.count - 1)
                var k = end + 1
                while k < chars.count, chars[k].isWhitespace { k += 1 }
                let isKey = k < chars.count && chars[k] == ":"
                emit(String(chars[i...end]), isKey ? keyColor : stringColor)
                i = end + 1
            } else if "{}[],:".contains(c) {
                emit(String(c), punctuationColor)
                i += 1
            } else if c.isLetter || c.isNumber || c == "-" {
                var j = i
                while j < chars.count, chars[j].isLetter || chars[j].isNumber || ".-+".contains(chars[j]) {
                    j += 1
                }
                emit(String(chars[i..<j]), literalColor)
                i = j
            } else {
                emit(String(c), plainColor)
                i += 1
            }
        }
        flush()
        return output
    }
}
