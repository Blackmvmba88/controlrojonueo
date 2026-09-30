import Cocoa
import ApplicationServices

struct SpatialCandidate {
    let element: AXUIElement
    let frame: CGRect
}

final class SpatialNavigator {
    private var selected: SpatialCandidate?
    private var selectedPID: pid_t?
    private var ring: NSPanel?
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
    private func element(_ object: CFTypeRef?) -> AXUIElement? {
        guard let object, CFGetTypeID(object) == AXUIElementGetTypeID() else { return nil }
        return (object as! AXUIElement)
    }
    private func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = attribute(element, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
              let s = attribute(element, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size), size.width > 2, size.height > 2 else { return nil }
        return CGRect(origin: point, size: size)
    }
    func exitYouTubeTheater() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.03)
        guard let window = element(attribute(app, kAXFocusedWindowAttribute)) else { return false }
        var queue = [window], index = 0
        let start = ProcessInfo.processInfo.systemUptime
        while index < queue.count && index < 300 && ProcessInfo.processInfo.systemUptime - start < 0.12 {
            let item = queue[index]; index += 1
            if attribute(item, kAXRoleAttribute) as? String == kAXButtonRole {
                let text = [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute].compactMap { attribute(item, $0) as? String }.joined(separator: " ").lowercased()
                if ["modo predeterminado", "default view", "exit theater mode", "salir del modo cine"].contains(where: { text.contains($0) }) {
                    return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
                }
            }
            if let children = attribute(item, kAXChildrenAttribute) as? [AXUIElement] { queue.append(contentsOf: children) }
        }
        return false
    }
    func videoContext() -> (youtube: Bool, editing: Bool) {
        guard AXIsProcessTrusted(), let front = NSWorkspace.shared.frontmostApplication else { return (false, false) }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.03)
        let focus = element(attribute(app, kAXFocusedUIElementAttribute))
        let role = focus.flatMap { attribute($0, kAXRoleAttribute) as? String } ?? ""
        if [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) { return (false, true) }
        guard let window = element(attribute(app, kAXFocusedWindowAttribute)) else { return (false, false) }
        var queue = [window], index = 0
        let start = ProcessInfo.processInfo.systemUptime
        while index < queue.count && index < 150 && ProcessInfo.processInfo.systemUptime - start < 0.08 {
            let item = queue[index]; index += 1
            for name in ["AXDocument", "AXURL"] {
                let raw = attribute(item, name)
                let url = (raw as? URL) ?? (raw as? String).flatMap { URL(string: $0) }
                if let url, let host = url.host?.lowercased(),
                   (host == "youtube.com" || host.hasSuffix(".youtube.com")),
                   (url.path == "/watch" || url.path.hasPrefix("/shorts/")) { return (true, false) }
            }
            if let children = attribute(item, kAXChildrenAttribute) as? [AXUIElement] { queue.append(contentsOf: children) }
        }
        return (false, false)
    }
    func clear() { selected = nil; selectedPID = nil; ring?.orderOut(nil) }
    func move(dx: Double, dy: Double) -> String {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication else { clear(); return "Falta Accesibilidad" }
        if selectedPID != app.processIdentifier { clear() }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.04)
        guard let window = element(attribute(application, kAXFocusedWindowAttribute)) else { clear(); return "Esta app no expone una ventana navegable" }
        var queue = [window], visited: [AXUIElement] = [], candidates: [SpatialCandidate] = []
        let start = ProcessInfo.processInfo.systemUptime
        let windowBounds = frame(window)
        let roles: Set<String> = [kAXButtonRole, kAXTextFieldRole, kAXTextAreaRole, kAXCheckBoxRole, kAXRadioButtonRole, kAXPopUpButtonRole, kAXComboBoxRole, kAXSliderRole, "AXLink", kAXRowRole, kAXCellRole, kAXImageRole, kAXMenuItemRole]
        // Include window chrome even if it is absent from the ordinary children list.
        for name in [kAXCloseButtonAttribute, kAXMinimizeButtonAttribute, kAXZoomButtonAttribute] {
            if let child = element(attribute(window, name)) { queue.append(child) }
        }
        var index = 0
        while index < queue.count && visited.count < 600 && ProcessInfo.processInfo.systemUptime - start < 0.18 {
            let item = queue[index]; index += 1
            if visited.contains(where: { CFEqual($0, item) }) { continue }
            visited.append(item)
            let role = attribute(item, kAXRoleAttribute) as? String ?? ""
            let enabled = attribute(item, kAXEnabledAttribute) as? Bool ?? true
            if enabled, roles.contains(role), let rect = frame(item), let bounds = windowBounds, bounds.intersects(rect) {
                candidates.append(SpatialCandidate(element: item, frame: rect.intersection(bounds)))
            }
            if let children = attribute(item, kAXChildrenAttribute) as? [AXUIElement] { queue.append(contentsOf: children) }
        }
        var origin = CGEvent(source: nil)?.location ?? CGPoint.zero
        if let previous = selected, let current = candidates.first(where: { CFEqual($0.element, previous.element) }) {
            origin = CGPoint(x: current.frame.midX, y: current.frame.midY)
        } else if let focused = element(attribute(application, kAXFocusedUIElementAttribute)), let rect = frame(focused) {
            origin = CGPoint(x: rect.midX, y: rect.midY)
        }
        guard let target = directionalTarget(frames: candidates.map(\.frame), origin: origin, dx: dx, dy: dy) else {
            return candidates.isEmpty ? "Esta app no expone elementos navegables" : "No hay otro elemento en esa dirección"
        }
        let candidate = candidates[target]
        selected = candidate; selectedPID = app.processIdentifier
        var settable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(candidate.element, kAXFocusedAttribute as CFString, &settable) == .success, settable.boolValue {
            _ = AXUIElementSetAttributeValue(candidate.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
        let center = CGPoint(x: candidate.frame.midX, y: candidate.frame.midY)
        CGWarpMouseCursorPosition(center)
        showRing(candidate.frame)
        return "Cruz: elemento seleccionado · A para pulsar"
    }
    private func showRing(_ rect: CGRect) {
        if ring == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.ignoresMouseEvents = true; panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = NSView(); view.wantsLayer = true
            view.layer?.borderWidth = 3; view.layer?.borderColor = NSColor.systemYellow.cgColor
            view.layer?.cornerRadius = 5; panel.contentView = view
            ring = panel
        }
        let height = NSScreen.screens.first?.frame.maxY ?? 0
        ring?.setFrame(CGRect(x: rect.minX - 3, y: height - rect.maxY - 3, width: rect.width + 6, height: rect.height + 6), display: true)
        ring?.orderFrontRegardless()
    }
}
