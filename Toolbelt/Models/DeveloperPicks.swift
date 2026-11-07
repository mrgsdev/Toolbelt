import Foundation
import SwiftData

/// A server the developer recommends; becomes a shelf entry only when the user adds it.
struct ServerTemplate: Identifiable, Hashable {
    let name: String
    let tagline: String
    let summary: String
    let symbol: String
    let category: MCPCategory
    let pricing: Pricing
    let pricingNote: String
    var websiteURL = ""
    var repoURL = ""
    let configJSON: String
    let setupSteps: [String]
    let capabilities: [String]
    let examplePrompts: [String]
    let tags: [String]
    /// A short line from the developer, shown on the recommendation card only.
    let comment: String

    var id: String { name }

    func makeServer(createdAt: Date = .now) -> MCPServer {
        MCPServer(
            name: name,
            tagline: tagline,
            summary: summary,
            symbol: symbol,
            category: category,
            pricing: pricing,
            pricingNote: pricingNote,
            websiteURL: websiteURL,
            repoURL: repoURL,
            configJSON: configJSON,
            setupSteps: setupSteps,
            capabilities: capabilities,
            examplePrompts: examplePrompts,
            tags: tags,
            createdAt: createdAt
        )
    }
}

/// «Рекомендация разработчика»: the starter set, offered on the home screen instead of being preinstalled.
enum DeveloperPicks {
    /// The user closed the recommendation block.
    static let hiddenKey = "picks.hidden"

    /// Recommended servers that are not in the set yet.
    static func missing(from servers: [MCPServer]) -> [ServerTemplate] {
        let names = Set(servers.map { $0.name.lowercased() })
        return all.filter { !names.contains($0.name.lowercased()) }
    }

    /// Adds templates in their listed order; returns how many were added.
    @MainActor
    @discardableResult
    static func add(_ templates: [ServerTemplate], to context: ModelContext) -> Int {
        let now = Date.now
        for (index, template) in templates.enumerated() {
            context.insert(template.makeServer(createdAt: now.addingTimeInterval(-Double(index))))
        }
        try? context.save()
        return templates.count
    }

    static let all: [ServerTemplate] = [
        ServerTemplate(
            name: "Blender MCP",
            tagline: "Агент собирает 3D-сцены в Blender по текстовому запросу",
            summary: """
            Связывает агента с Blender через аддон и локальный сокет-сервер. По запросу агент создаёт и меняет объекты, \
            ставит свет и камеру, накидывает материалы и текстуры, собирает окружение целиком. Подходит, если 3D нужно, \
            а навыков нет, например для ассетов и сцен в своих играх.

            Проект с открытым кодом от сообщества (автор Siddharth Ahuja), не официальный продукт Blender Foundation.
            """,
            symbol: "cube.transparent.fill",
            category: .design3D,
            pricing: .free,
            pricingNote: "Open source и бесплатно. Платить нужно только за AI-клиента, если он платный.",
            websiteURL: "https://blendermcp.org/setup",
            repoURL: "https://github.com/ahujasid/blender-mcp",
            configJSON: """
            {
              "mcpServers": {
                "blender": {
                  "command": "uvx",
                  "args": ["blender-mcp"]
                }
              }
            }
            """,
            setupSteps: [
                "Поставь Blender 3.0+ и менеджер пакетов `uv` (`brew install uv`)",
                "Скачай `addon.py` из репозитория и установи: Edit → Preferences → Add-ons → Install",
                "Включи аддон, открой вкладку BlenderMCP в боковой панели (клавиша N) и подключись",
                "Добавь сервер в конфиг MCP-клиента, `uvx` сам подтянет пакет `blender-mcp`"
            ],
            capabilities: [
                "Создание и редактирование объектов сцены",
                "Материалы, текстуры и освещение",
                "Ассеты из библиотеки Poly Haven",
                "Выполнение Python-кода внутри Blender",
                "Скриншоты вьюпорта для проверки результата"
            ],
            examplePrompts: [
                "Собери low-poly сцену: домик у озера, сосны вокруг и закатный свет",
                "Сделай стол из тёмного дерева и наложи PBR-текстуры с Poly Haven",
                "Поставь камеру сверху под 45° и покажи, что получилось"
            ],
            tags: ["3D", "Blender", "геймдев", "текстуры", "сцены", "open source"],
            comment: "Одно из моих любимых: сцены, текстуры и окружение для своих игр без навыков 3D."
        ),
        ServerTemplate(
            name: "Linear MCP",
            tagline: "Таск-трекер: агент заводит задачи и раскладывает их по полочкам",
            summary: """
            Официальный удалённый MCP-сервер Linear. После аудита проекта можно самому составить список проблем или \
            поручить это агенту: он загрузит всё в Linear, где каждая задача получит идентификатор, описание и этапы решения.

            Дальше агенту проще и дешевле найти нужный узелок и закрыть задачу, а весь прогресс виден в трекере.
            """,
            symbol: "checklist",
            category: .productivity,
            pricing: .freemium,
            pricingNote: "Сам MCP бесплатный, нужен аккаунт Linear (есть бесплатный план).",
            websiteURL: "https://linear.app/docs/mcp",
            configJSON: """
            {
              "mcpServers": {
                "linear": {
                  "command": "npx",
                  "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"]
                }
              }
            }
            """,
            setupSteps: [
                "Клиент умеет Streamable HTTP: подключай напрямую `https://mcp.linear.app/mcp`",
                "Только stdio? Используй конфиг ниже через `mcp-remote`",
                "При первом подключении откроется браузер, авторизуйся через OAuth",
                "Нужен только просмотр: адрес `https://mcp.linear.app/mcp/readonly`"
            ],
            capabilities: [
                "Создание и обновление задач",
                "Поиск по задачам, проектам и циклам",
                "Комментарии, статусы и приоритеты",
                "Режим только для чтения"
            ],
            examplePrompts: [
                "Заведи в Linear задачи по списку проблем из аудита и расставь приоритеты",
                "Разбей задачу про авторизацию на подзадачи с этапами решения",
                "Покажи мои открытые задачи в текущем цикле"
            ],
            tags: ["задачи", "планирование", "трекер", "аудит", "OAuth"],
            comment: "Аудит, список проблем, агент грузит их в Linear, решаем по одной."
        ),
        ServerTemplate(
            name: "web-to-mcp",
            tagline: "Кликни по компоненту на сайте, и агент получит его DOM и CSS",
            summary: """
            Расширение для Chrome, которое передаёт агенту любой элемент чужого сайта: кликаешь по компоненту, а агент \
            получает его DOM, стили и визуальный контекст. Больше не нужно делать скриншоты и объяснять словами \
            «сделай как тут»: референс приезжает прямо в чат через MCP.
            """,
            symbol: "cursorarrow.click.2",
            category: .web,
            pricing: .freemium,
            pricingNote: "Free: ограниченное число захватов в месяц. Pro: $2.5 в месяц или $30 в год, без лимитов.",
            websiteURL: "https://web-to-mcp.com/",
            configJSON: """
            {
              "mcpServers": {
                "web-to-mcp": {
                  "url": "https://web-to-mcp.com/mcp/<YOUR_UNIQUE_ID>"
                }
              }
            }
            """,
            setupSteps: [
                "Поставь расширение из Chrome Web Store и войди через Google",
                "Скопируй свой уникальный MCP URL в дашборде",
                "Вставь его в конфиг вместо `<YOUR_UNIQUE_ID>`",
                "Кликни по элементу на сайте, скопируй его ID и упомяни в чате с агентом"
            ],
            capabilities: [
                "DOM выбранного компонента",
                "CSS-стили элемента",
                "Визуальный контекст и скриншот",
                "Работает на любом сайте"
            ],
            examplePrompts: [
                "Сверстай такую же карточку тарифа, как в элементе <ID>",
                "Возьми хедер из <ID> и адаптируй под нашу тему",
                "Сравни мою кнопку с <ID> и подтяни отступы и тени"
            ],
            tags: ["вёрстка", "CSS", "референсы", "Chrome", "UI"],
            comment: "Больше не надо скринить и объяснять «сделай как тут». Pro стоит всего $2.5."
        ),
        ServerTemplate(
            name: "ast-grep MCP",
            tagline: "Структурный поиск по коду: функции, классы и вызовы, а не строки",
            summary: """
            Ищет по синтаксическому дереву, а не по тексту: находит конкретные конструкции, например функции, импорты, \
            классы и вызовы с нужными аргументами. Агент может посмотреть AST, проверить правило на примере и только потом \
            прогнать его по всему проекту.

            Незаменим при большом рефакторинге, когда обычный grep выдаёт слишком много шума.
            """,
            symbol: "curlybraces.square.fill",
            category: .codeSearch,
            pricing: .free,
            pricingNote: "Open source, бесплатно.",
            websiteURL: "https://ast-grep.github.io",
            repoURL: "https://github.com/ast-grep/ast-grep-mcp",
            configJSON: """
            {
              "mcpServers": {
                "ast-grep": {
                  "command": "uv",
                  "args": ["--directory", "/absolute/path/to/ast-grep-mcp", "run", "main.py"],
                  "env": {}
                }
              }
            }
            """,
            setupSteps: [
                "Поставь ast-grep: `brew install ast-grep`",
                "Поставь uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`",
                "Склонируй репозиторий и выполни в нём `uv sync`",
                "В конфиге замени `/absolute/path/to/ast-grep-mcp` на путь к своему клону"
            ],
            capabilities: [
                "dump_syntax_tree: показать AST фрагмента кода",
                "test_match_code_rule: проверить YAML-правило на примере",
                "find_code: поиск по шаблону",
                "find_code_by_rule: поиск по сложным правилам"
            ],
            examplePrompts: [
                "Найди все вызовы fetch без обработки ошибок",
                "Покажи классы, которые наследуются от BaseViewController",
                "Найди все console.log и предложи замену на logger.debug"
            ],
            tags: ["рефакторинг", "AST", "поиск", "код", "open source"],
            comment: "Достаю, когда нужен рефакторинг большого проекта."
        ),
        ServerTemplate(
            name: "mcp-ripgrep",
            tagline: "Молниеносный поиск по огромным репозиториям",
            summary: """
            MCP-обёртка над ripgrep. Быстро ищет по гигантским кодовым базам, фильтрует по типам файлов, считает \
            совпадения и показывает, какие файлы вообще попадут в поиск.

            Отлично подходит, чтобы раскопать чужой open source в поисках нужного куска.
            """,
            symbol: "text.magnifyingglass",
            category: .codeSearch,
            pricing: .free,
            pricingNote: "Open source, бесплатно.",
            repoURL: "https://github.com/mcollina/mcp-ripgrep",
            configJSON: """
            {
              "mcpServers": {
                "ripgrep": {
                  "command": "npx",
                  "args": ["-y", "mcp-ripgrep@latest"]
                }
              }
            }
            """,
            setupSteps: [
                "Нужен Node.js 18+",
                "Поставь ripgrep: `brew install ripgrep`",
                "Добавь конфиг, `npx` скачает `mcp-ripgrep` при первом запуске"
            ],
            capabilities: [
                "search: базовый поиск",
                "advanced-search: поиск с дополнительными параметрами",
                "count-matches: подсчёт совпадений",
                "list-files: какие файлы попадут в поиск",
                "list-file-types: поддерживаемые типы файлов"
            ],
            examplePrompts: [
                "Найди в этом репо, где настраивается кеширование запросов",
                "Сколько раз встречается TODO в .ts файлах?",
                "Покажи все места, где читается переменная окружения API_KEY"
            ],
            tags: ["ripgrep", "поиск", "код", "CLI", "open source"],
            comment: "Чтобы перерыть чужие open-source репозитории в поисках полезного."
        ),
        ServerTemplate(
            name: "Composio",
            tagline: "Один шлюз к 1500+ сервисам: Gmail, GitHub, Notion, Slack…",
            summary: """
            Не отдельный сервер, а полноценный шлюз между агентом и 1500+ приложениями. Вместо того чтобы подключать \
            Gmail, GitHub, Notion, Slack и остальное по одному, ты один раз подключаешь Composio, и агент получает доступ \
            ко всему, что разрешено.

            Шлюз хранит креды, управляет политиками доступа и ведёт журнал действий. Командам можно выдавать отдельные \
            эндпоинты только с нужными инструментами.
            """,
            symbol: "point.3.connected.trianglepath.dotted",
            category: .integrations,
            pricing: .freemium,
            pricingNote: "Можно начать бесплатно, тарифы на сайте.",
            websiteURL: "https://composio.dev/mcp-gateway",
            configJSON: """
            {
              "mcpServers": {
                "composio": {
                  "url": "https://mcp.composio.dev/<YOUR_ENDPOINT>"
                }
              }
            }
            """,
            setupSteps: [
                "Зарегистрируйся на composio.dev, старт бесплатный",
                "Подключи нужные приложения и настрой доступы",
                "Скопируй URL своего эндпоинта и вставь в конфиг вместо `<YOUR_ENDPOINT>`"
            ],
            capabilities: [
                "1500+ приложений через один эндпоинт",
                "Хранение кредов и OAuth на стороне шлюза",
                "Политики доступа и отдельные эндпоинты для команд",
                "Журнал действий агента"
            ],
            examplePrompts: [
                "Найди в Gmail письма от заказчика за неделю и сделай саммари в Notion",
                "Создай issue в GitHub по последнему сообщению в Slack-канале #bugs",
                "Запланируй созвон в календаре и скинь ссылку команде в Slack"
            ],
            tags: ["интеграции", "gateway", "Gmail", "GitHub", "Notion", "Slack"],
            comment: "Больше не нужно подключать Gmail, GitHub, Notion и Slack по отдельности."
        ),
        ServerTemplate(
            name: "shadcn MCP",
            tagline: "Агент сам находит и ставит UI-компоненты по текстовому запросу",
            summary: """
            Официальный MCP от shadcn/ui. Агент ищет компоненты в реестрах и сразу устанавливает их в проект по обычной \
            просьбе, например «добавь кнопку регистрации» или «собери форму обратной связи».

            Можно подключить свои или приватные реестры через components.json, и агент будет искать и там.
            """,
            symbol: "square.grid.2x2.fill",
            category: .uiComponents,
            pricing: .free,
            pricingNote: "Open source, бесплатно.",
            websiteURL: "https://ui.shadcn.com/docs/mcp",
            repoURL: "https://github.com/shadcn-ui/ui",
            configJSON: """
            {
              "mcpServers": {
                "shadcn": {
                  "command": "npx",
                  "args": ["shadcn@latest", "mcp"]
                }
              }
            }
            """,
            setupSteps: [
                "В корне проекта: `npx shadcn@latest mcp init --client <твой клиент>`",
                "Или добавь конфиг вручную в `.mcp.json` проекта",
                "Свои реестры добавляются в секцию `registries` файла `components.json`"
            ],
            capabilities: [
                "Поиск компонентов по реестрам",
                "Установка компонентов в проект",
                "Свои и приватные реестры",
                "Сборка целых блоков: формы, лендинги"
            ],
            examplePrompts: [
                "Добавь кнопку регистрации и диалог входа",
                "Собери форму обратной связи на компонентах shadcn",
                "Покажи все доступные компоненты в реестре"
            ],
            tags: ["UI", "React", "компоненты", "shadcn", "фронтенд"],
            comment: "«Добавь кнопку регистрации», и компонент уже в проекте."
        )
    ]
}
