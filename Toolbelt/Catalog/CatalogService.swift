import SwiftUI
import WebKit

/// Talks to mcpservers.org through a WebKit view.
///
/// The site sits behind Cloudflare's browser check, which plain URLSession requests do not pass.
/// The web view passes it like a normal browser, then every page is fetched with `fetch()` from
/// inside that page and parsed with `DOMParser`, so only small JSON results cross into Swift.
@MainActor
final class CatalogService {
    static let shared = CatalogService()
    static let origin = URL(string: "https://mcpservers.org")!

    let webView: WKWebView
    private var isReady = false
    private var warming: Task<Void, Error>?

    private init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 700), configuration: configuration)
    }

    func fetchList(path: String) async throws -> CatalogListResponse {
        try await call(Self.listScript, path: path, as: CatalogListResponse.self) { $0.challenge }
    }

    func fetchDetail(path: String) async throws -> CatalogDetail {
        try await call(Self.detailScript, path: path, as: CatalogDetail.self) { $0.challenge }
    }

    /// Forget the warmed-up state, e.g. after the user passed a check in the verification sheet.
    func invalidate() {
        isReady = false
    }

    // MARK: Internals

    private func call<T: Decodable>(_ script: String, path: String, as type: T.Type,
                                    isChallenge: (T) -> Bool) async throws -> T {
        for attempt in 0..<2 {
            try await ensureReady(force: attempt > 0)
            let raw: Any?
            do {
                raw = try await webView.callAsyncJavaScript(script, arguments: ["path": path], in: nil, contentWorld: .page)
            } catch {
                throw CatalogError.network("Сеть недоступна или mcpservers.org не ответил.")
            }
            guard let json = raw as? String, let data = json.data(using: .utf8) else {
                throw CatalogError.badResponse
            }
            let value: T
            do {
                value = try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw CatalogError.badResponse
            }
            if !isChallenge(value) { return value }
            isReady = false
        }
        throw CatalogError.verificationRequired
    }

    private func ensureReady(force: Bool) async throws {
        if isReady && !force { return }
        if let warming {
            try await warming.value
            return
        }
        let task = Task { @MainActor [webView] in
            webView.load(URLRequest(url: Self.origin.appending(path: "ru/all")))
            let clock = ContinuousClock()
            let deadline = clock.now + .seconds(25)
            while clock.now < deadline {
                try await Task.sleep(for: .milliseconds(400))
                let state = try? await webView.evaluateJavaScript(Self.readyProbe, in: nil, contentWorld: .page) as? String
                if state == "ready" { return }
            }
            throw CatalogError.verificationRequired
        }
        warming = task
        defer { warming = nil }
        try await task.value
        isReady = true
    }

    private static let readyProbe = """
    (document.readyState === 'complete'
      && location.hostname.endsWith('mcpservers.org')
      && !/Just a moment/i.test(document.title)
      && document.querySelector('main') !== null) ? 'ready' : 'wait'
    """

    /// Body of an async JS function; `path` is passed as an argument.
    private static let listScript = #"""
    const res = await fetch(path, { credentials: 'include' });
    const html = await res.text();
    const doc = new DOMParser().parseFromString(html, 'text/html');
    if (res.status === 403 || /Just a moment/i.test(doc.title)) {
      return JSON.stringify({ challenge: true, entries: [] });
    }
    const main = doc.querySelector('main') || doc.body;
    const entries = [...main.querySelectorAll('a[href*="/servers/"]')].map((a) => {
      const title = a.querySelector('[data-slot="card-title"]');
      if (!title) { return null; }
      const desc = a.querySelector('[data-slot="card-description"]');
      const label = title.nextElementSibling ? title.nextElementSibling.textContent.trim() : '';
      const img = a.querySelector('img');
      let source = '';
      if (img) {
        try { source = new URL(img.getAttribute('src'), location.origin).searchParams.get('url') || ''; } catch (e) {}
      }
      const leaves = [...a.querySelectorAll('*')]
        .filter((e) => e.children.length === 0)
        .map((e) => e.textContent.trim().toLowerCase());
      return {
        path: a.getAttribute('href'),
        name: title.textContent.trim(),
        category: label,
        summary: desc ? desc.textContent.trim() : '',
        source,
        official: leaves.some((t) => t === 'официальный' || t === 'official'),
        sponsored: leaves.some((t) => t === 'спонсор' || t === 'sponsor')
      };
    }).filter(Boolean);
    const info = (main.textContent.match(/из\s+([\d\s  ]+?)\s*сервер/) || [])[1];
    const pages = [...doc.querySelectorAll('a[href*="page="]')]
      .map((a) => { try { return parseInt(new URL(a.getAttribute('href'), location.origin).searchParams.get('page'), 10); } catch (e) { return NaN; } })
      .filter((n) => !isNaN(n));
    return JSON.stringify({
      challenge: false,
      entries,
      total: info ? parseInt(info.replace(/\D/g, ''), 10) : null,
      pageCount: pages.length ? Math.max(...pages) : null
    });
    """#

    private static let detailScript = #"""
    const res = await fetch(path, { credentials: 'include' });
    const html = await res.text();
    const doc = new DOMParser().parseFromString(html, 'text/html');
    if (res.status === 403 || /Just a moment/i.test(doc.title)) {
      return JSON.stringify({ challenge: true });
    }
    const main = doc.querySelector('main') || doc.body;
    const md = main.querySelector('.markdown-body');
    const isSponsor = (a) => /[?&]utm_medium=sponsor|detail_sidebar/i.test(a.href) || /sponsored/i.test(a.getAttribute('rel') || '');
    const inReadme = (a) => md && md.contains(a);
    const outside = [...main.querySelectorAll('a[href^="http"]')].filter((a) => !inReadme(a) && !isSponsor(a));
    const gh = outside.find((a) => /github\.com\//.test(a.href));
    let site = null;
    if (gh) {
      let box = gh.parentElement;
      for (let i = 0; i < 3 && box && box.querySelectorAll('a[href^="http"]').length < 2; i++) { box = box.parentElement; }
      if (box) {
        site = [...box.querySelectorAll('a[href^="http"]')]
          .find((a) => !/github\.com|mcpservers\.org/.test(a.href) && !isSponsor(a) && !inReadme(a)) || null;
      }
    }
    const stars = gh ? ((gh.textContent.match(/(\d[\d.,]*\s*[kKкК]?)\s*$/) || [])[1] || null) : null;
    const scope = md || main;
    const codes = [...new Set([...scope.querySelectorAll('pre')].map((p) => p.textContent.trim()))]
      .filter((t) => t.length > 0)
      .slice(0, 24);
    const blocks = [];
    let budget = 14000;
    if (md) {
      for (const el of md.querySelectorAll('h1,h2,h3,h4,p,li,pre')) {
        if (el.tagName !== 'PRE' && el.closest('pre')) { continue; }
        if (el.tagName === 'P' && el.closest('li')) { continue; }
        const raw = el.tagName === 'PRE' ? el.textContent : el.textContent.replace(/\s+/g, ' ');
        const text = raw.trim().slice(0, 1600);
        if (!text) { continue; }
        const kind = /^H\d$/.test(el.tagName) ? 'heading' : el.tagName === 'LI' ? 'item' : el.tagName === 'PRE' ? 'code' : 'text';
        blocks.push({ kind, text });
        budget -= text.length;
        if (blocks.length >= 90 || budget <= 0) { break; }
      }
    }
    const h1 = main.querySelector('h1');
    return JSON.stringify({
      challenge: false,
      title: h1 ? h1.textContent.trim() : null,
      github: gh ? gh.href : null,
      website: site ? site.href : null,
      stars,
      codes,
      blocks
    });
    """#
}

/// Keeps the catalog web view inside the window so WebKit treats it as visible and runs the check at full speed.
struct CatalogWebHost: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { CatalogService.shared.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

/// A visible browser for passing the site's check by hand; shares cookies with the hidden one.
struct VerificationWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
