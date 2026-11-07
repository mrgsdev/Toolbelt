import SwiftUI

/// Help → «Отказ от ответственности и лицензии», also opened from Settings: what the app is and is not,
/// what it stores and sends, and its license.
struct LegalView: View {
    /// The same points as in the README and the last page of the tour.
    static let disclaimer = [
        "Программа предоставляется «как есть», без каких-либо гарантий.",
        "Toolbelt не связан с mcpservers.org и разработчиками MCP-клиентов и серверов и не является их официальным приложением.",
        "Конфиги клиентов меняются на ваш страх и риск. Перед каждой записью приложение сохраняет копию файла рядом с ним.",
        "MCP-серверы из каталога написаны другими людьми. Проверяйте, что запускаете и какие доступы выдаёте агенту.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Отказ от ответственности и лицензии")
                    .font(.system(size: 24, weight: .regular))
                    .tracking(-0.4)

                Panel(title: "Отказ от ответственности") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Self.disclaimer, id: \.self) { bullet($0) }
                    }
                }

                Panel(title: "Данные и сеть") {
                    VStack(alignment: .leading, spacing: 8) {
                        bullet("Набор, заметки и оценки хранятся только на этом Mac: ~/Library/Application Support/Toolbelt.")
                        bullet("Каталог загружается со страниц mcpservers.org через встроенный WebKit, логотипы берутся с mcpservers.org/api/logo.")
                        bullet("Конфиги меняются только в файлах MCP-клиентов и только по вашей кнопке. Claude Code настраивается его же командой claude mcp add-json.")
                        bullet("Обновления проверяются по списку релизов на GitHub. Никакой статистики приложение не отправляет.")
                    }
                }

                Panel(title: "Лицензия") {
                    HStack(alignment: .firstTextBaseline) {
                        Link("Toolbelt", destination: AppLinks.repository)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(verbatim: "MIT License")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondary)
                    }
                    .tint(Theme.ink)
                    Text(verbatim: Self.license)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.inset, in: .rect(cornerRadius: 10, style: .continuous))
                    Text("Открытых библиотек внутри нет: только системные фреймворки Apple.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                }

                Panel(title: "Благодарности") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Каталог MCP-серверов:")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.secondary)
                        Link(destination: AppLinks.catalog) { Text(verbatim: "mcpservers.org") }
                        Text("Авторы серверов из стартового набора:")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.secondary)
                            .padding(.top, 6)
                        FlowLayout(spacing: 12, lineSpacing: 6) {
                            ForEach(Self.credits, id: \.0) { name, url in
                                Link(destination: URL(string: url)!) { Text(verbatim: name) }
                            }
                        }
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .tint(Theme.ink)
                }
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 640, height: 660)
        .background(Theme.canvas)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Rectangle()
                .fill(Theme.ink)
                .frame(width: 4, height: 4)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            Text(text)
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static let credits: [(String, String)] = [
        ("Blender MCP", "https://github.com/ahujasid/blender-mcp"),
        ("Linear", "https://linear.app/docs/mcp"),
        ("web-to-mcp", "https://web-to-mcp.com/"),
        ("ast-grep", "https://github.com/ast-grep/ast-grep-mcp"),
        ("mcp-ripgrep", "https://github.com/mcollina/mcp-ripgrep"),
        ("Composio", "https://composio.dev/mcp-gateway"),
        ("shadcn/ui", "https://ui.shadcn.com/docs/mcp"),
    ]

    /// The LICENSE file at the root of the repository.
    private static let license = """
        MIT License

        Copyright (c) 2026 mrgsdev

        Permission is hereby granted, free of charge, to any person obtaining a copy \
        of this software and associated documentation files (the "Software"), to deal \
        in the Software without restriction, including without limitation the rights \
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
        copies of the Software, and to permit persons to whom the Software is \
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all \
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
        SOFTWARE.
        """
}
