import AppKit
import ApplicationServices

struct CardTarget {
    let element: AXUIElement
    let url: String
    let title: String
    let frame: CGRect
}

enum CardDirection: String {
    case up, down, left, right
    func score(from origin: CGRect, to target: CGRect) -> Double? {
        let dx = target.midX - origin.midX, dy = target.midY - origin.midY
        let primary = self == .left ? -dx : self == .right ? dx : self == .up ? -dy : dy
        let lateral = (self == .left || self == .right) ? abs(dy) : abs(dx)
        guard primary > 8 else { return nil }
        // Prefer the same row/column over a closer diagonal card.
        let allowance = (self == .left || self == .right) ? min(origin.height, target.height) * 0.5 : min(origin.width, target.width) * 0.5
        return Double(primary + max(0, lateral - allowance) * 5)
    }
}

final class SelectionBorder: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemCyan.setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 10, yRadius: 10)
        path.lineWidth = 4
        path.stroke()
    }
}

/// Reads real video links from the frontmost browser's accessibility tree.
/// The panel never takes focus; activation is sent to the selected link.
final class CardNavigator {
    var selected: CardTarget?
    private var owner: pid_t = 0
    private var panel: NSPanel?
    private var viewport = CGRect.zero
    private var lastScan = Date.distantPast
    private var targets: [CardTarget] = []
    private let browsers: Set<String> = ["com.apple.Safari", "com.google.Chrome", "com.google.Chrome.canary", "com.microsoft.edgemac", "company.thebrowser.Browser", "org.mozilla.firefox", "com.brave.Browser"]

    func browserApplication(preferred: NSRunningApplication?) -> NSRunningApplication? {
        if let app = preferred, browsers.contains(app.bundleIdentifier ?? ""), !app.isTerminated { return app }
        return NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.Safari" }
            ?? NSWorkspace.shared.runningApplications.first { browsers.contains($0.bundleIdentifier ?? "") }
    }
    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = attribute(element, kAXPositionAttribute), let s = attribute(element, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size), size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: point, size: size)
    }
    static func isVideo(_ raw: String) -> Bool {
        guard let url = URL(string: raw), let host = url.host?.lowercased(), host == "youtube.com" || host.hasSuffix(".youtube.com") else { return false }
        return url.path == "/watch" || url.path.hasPrefix("/shorts/")
    }
    func clear() {
        selected = nil; targets = []; owner = 0; panel?.orderOut(nil)
    }
    func maintain(enabled: Bool) {
        guard enabled, let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier == owner else { clear(); return }
        // Scroll, window movement and page changes invalidate screen coordinates.
        if selected != nil && Date().timeIntervalSince(lastScan) > 0.6 {
            guard scan(), let old = selected, let updated = targets.first(where: { $0.url == old.url }), visible(updated.frame) else { clear(); return }
            selected = updated; show(updated.frame)
        }
    }
    func visible(_ rect: CGRect) -> Bool {
        let intersection = viewport.intersection(rect)
        return !intersection.isNull && intersection.width > min(20, rect.width * 0.5) && intersection.height > min(12, rect.height * 0.5)
    }
    @discardableResult func scan() -> Bool {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              browsers.contains(app.bundleIdentifier ?? "") else { clear(); return false }
        if owner != app.processIdentifier { clear(); owner = app.processIdentifier }
        let root = AXUIElementCreateApplication(owner)
        AXUIElementSetMessagingTimeout(root, 0.15)
        guard let value = attribute(root, kAXFocusedWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { clear(); return false }
        let window = value as! AXUIElement
        viewport = frame(window) ?? .zero
        var result: [CardTarget] = []
        var count = 0
        let deadline = Date().addingTimeInterval(0.4)
        func visit(_ node: AXUIElement, depth: Int) {
            guard depth < 40, count < 3500, Date() < deadline else { return }
            count += 1
            let role = attribute(node, kAXRoleAttribute) as? String ?? ""
            if role == "AXWebArea", let rect = frame(node) { viewport = rect.intersection(viewport) }
            if role == "AXLink" {
                let raw = attribute(node, kAXURLAttribute)
                let url = (raw as? URL)?.absoluteString ?? (raw as? String ?? "")
                if Self.isVideo(url), let rect = frame(node), rect.width > 30 {
                    let title = attribute(node, kAXDescriptionAttribute) as? String ?? attribute(node, kAXTitleAttribute) as? String ?? "Video"
                    result.append(CardTarget(element: node, url: url, title: title, frame: rect))
                }
            }
            for child in attribute(node, kAXChildrenAttribute) as? [AXUIElement] ?? [] { visit(child, depth: depth + 1) }
        }
        visit(window, depth: 0)
        // A thumbnail and its title can expose the same URL. Keep the larger link.
        var unique: [String: CardTarget] = [:]
        for card in result {
            if let old = unique[card.url], old.frame.width * old.frame.height >= card.frame.width * card.frame.height { continue }
            unique[card.url] = card
        }
        targets = unique.values.sorted { abs($0.frame.minY - $1.frame.minY) < 8 ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY }
        lastScan = Date()
        return !targets.isEmpty
    }
    func move(_ direction: CardDirection, completion: @escaping (String) -> Void) -> Bool {
        guard scan() else { return false }
        if let previous = selected, let current = targets.first(where: { $0.url == previous.url }) {
            let choices = targets.filter { $0.url != current.url }.compactMap { card -> (CardTarget, Double)? in
                guard let score = direction.score(from: current.frame, to: card.frame) else { return nil }
                return (card, score)
            }.sorted { $0.1 < $1.1 }
            guard let next = choices.first?.0 else { completion("No hay otra tarjeta en esa dirección"); return true }
            selected = next
        } else {
            selected = targets.first(where: { visible($0.frame) })
        }
        guard let card = selected else { completion("Usa el stick derecho para mostrar más videos"); return true }
        if visible(card.frame) { show(card.frame); completion("Seleccionado: \(card.title)") }
        else {
            // Prefer the browser's native scroll-to-visible operation.
            let result = AXUIElementPerformAction(card.element, "AXScrollToVisible" as CFString)
            if result != .success {
                let delta = card.frame.midY > viewport.midY ? -400 : 400
                CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: Int32(delta), wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
            }
            panel?.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self, self.selected?.url == card.url, self.scan(), let updated = self.targets.first(where: { $0.url == card.url }), self.visible(updated.frame) else { completion("Usa el stick derecho para mostrar la tarjeta"); return }
                self.selected = updated; self.show(updated.frame); completion("Seleccionado: \(updated.title)")
            }
        }
        return true
    }
    func activate() -> String? {
        guard let old = selected else { return nil }
        guard scan(), let card = targets.first(where: { $0.url == old.url }), visible(card.frame) else { clear(); return "La selección cambió; selecciona otra tarjeta" }
        let result = AXUIElementPerformAction(card.element, kAXPressAction as CFString)
        if result == .actionUnsupported || result == .notImplemented {
            let point = CGPoint(x: card.frame.midX, y: card.frame.midY)
            for type: CGEventType in [.leftMouseDown, .leftMouseUp] {
                CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            }
            clear()
            return "Clic: \(card.title)"
        }
        clear()
        if result == .success { return "Abrir: \(card.title)" }
        // Never click an old coordinate or retry an action whose result is uncertain.
        return "El navegador no pudo abrir la tarjeta; usa el clic del stick L3"
    }
    private func show(_ rect: CGRect) {
        if panel == nil {
            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false
            p.ignoresMouseEvents = true; p.hidesOnDeactivate = false; p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.contentView = SelectionBorder(); panel = p
        }
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let clipped = rect.intersection(viewport)
        guard !clipped.isNull else { panel?.orderOut(nil); return }
        panel?.setFrame(NSRect(x: clipped.minX - 5, y: top - clipped.maxY - 5, width: clipped.width + 10, height: clipped.height + 10), display: true)
        panel?.orderFrontRegardless()
    }
}
