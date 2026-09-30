import Cocoa
import GameController
import ApplicationServices

final class App: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let status = NSTextField(labelWithString: "")
    let toggle = NSButton(title: "Activar mouse", target: nil, action: nil)
    let speed = NSSlider(value: 900, minValue: 200, maxValue: 2000, target: nil, action: nil)
    var enabled = false
    var pad: GCExtendedGamepad?
    var controller: GCController?
    var switchingApplications = false
    var heldLeft = false
    var heldRight = false
    var last = ProcessInfo.processInfo.systemUptime
    var scrollRemainder: Double = 0
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "ControlGame · Xbox como mouse"
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)])
        let version = ProcessInfo.processInfo.operatingSystemVersion
        stack.addArrangedSubview(NSTextField(labelWithString: "macOS detectado: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"))
        let guide = NSTextField(wrappingLabelWithString: "1. Enciende tu Xbox Series X/S y mantén pulsado el botón de emparejamiento.\n2. Conéctalo en Bluetooth.\n3. Autoriza Accesibilidad y activa el mouse.")
        stack.addArrangedSubview(guide)
        let bluetooth = NSButton(title: "Abrir Bluetooth", target: self, action: #selector(openBluetooth))
        stack.addArrangedSubview(bluetooth)
        stack.addArrangedSubview(NSButton(title: "Autorizar Accesibilidad", target: self, action: #selector(authorize)))
        stack.addArrangedSubview(status)
        toggle.target = self; toggle.action = #selector(changeActive)
        stack.addArrangedSubview(toggle)
        stack.addArrangedSubview(NSTextField(labelWithString: "Velocidad del cursor"))
        stack.addArrangedSubview(speed)
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString: "Stick izquierdo: cursor · Stick derecho: scroll\nA: clic y arrastrar · B: clic derecho · X: Enter · Y: Escape\nRT: ⌘ Tab · LT: ⌘ Shift Tab\nMenú (☰): pausar o reanudar"))
        NotificationCenter.default.addObserver(self, selector: #selector(scan), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(scan), name: .GCControllerDidDisconnect, object: nil)
        GCController.shouldMonitorBackgroundEvents = true
        scan()
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func openBluetooth() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!) }
    @objc func authorize() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func changeActive() {
        if enabled { stop() } else if AXIsProcessTrusted(), pad != nil { enabled = true } else {
            let alert = NSAlert(); alert.messageText = "Falta conectar el control o autorizar Accesibilidad"; alert.informativeText = "Usa los botones de esta ventana y después vuelve a activar el mouse."; alert.runModal()
        }
        refresh()
    }
    func refresh() {
        status.stringValue = "\(controller?.vendorName ?? "Control sin conectar") · \(AXIsProcessTrusted() ? "Permiso listo" : "Falta Accesibilidad")"
        toggle.title = enabled ? "Pausar mouse" : "Activar mouse"
    }
    @objc func scan() {
        let next = GCController.controllers().first { $0.extendedGamepad != nil }
        if controller === next { refresh(); return }
        stop()
        pad?.buttonA.pressedChangedHandler = nil; pad?.buttonB.pressedChangedHandler = nil
        pad?.buttonX.pressedChangedHandler = nil; pad?.buttonY.pressedChangedHandler = nil
        pad?.buttonMenu.pressedChangedHandler = nil
        pad?.rightTrigger.pressedChangedHandler = nil
        pad?.leftTrigger.pressedChangedHandler = nil
        controller = next; pad = next?.extendedGamepad
        next?.handlerQueue = .main
        pad?.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in self?.button(.left, pressed) }
        pad?.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in self?.button(.right, pressed) }
        pad?.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in self?.key(36, pressed) }
        pad?.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in self?.key(53, pressed) }
        pad?.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.changeActive() } }
        pad?.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.switchApplication(backward: false, pressed: pressed)
        }
        pad?.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.switchApplication(backward: true, pressed: pressed)
        }
        refresh()
    }
    func switchApplication(backward: Bool, pressed: Bool) {
        if !pressed {
            if pad?.leftTrigger.isPressed != true && pad?.rightTrigger.isPressed != true {
                finishApplicationSwitch()
            }
            return
        }
        guard enabled, AXIsProcessTrusted(), !heldLeft, !heldRight else { return }
        if !switchingApplications {
            switchingApplications = true
            postKey(55, down: true, flags: .maskCommand)
        }
        if backward { postKey(56, down: true, flags: [.maskCommand, .maskShift]) }
        let flags: CGEventFlags = backward ? [.maskCommand, .maskShift] : .maskCommand
        postKey(48, down: true, flags: flags)
        postKey(48, down: false, flags: flags)
        if backward { postKey(56, down: false, flags: .maskCommand) }
    }
    func postKey(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
    }
    func finishApplicationSwitch() {
        guard switchingApplications else { return }
        postKey(55, down: false, flags: [])
        switchingApplications = false
    }
    func mouse(_ type: CGEventType, _ button: CGMouseButton, _ point: CGPoint) {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)?.post(tap: .cghidEventTap)
    }
    func button(_ button: CGMouseButton, _ pressed: Bool) {
        guard enabled, AXIsProcessTrusted(), let point = CGEvent(source: nil)?.location else { return }
        if button == .left { heldLeft = pressed } else { heldRight = pressed }
        mouse(button == .left ? (pressed ? .leftMouseDown : .leftMouseUp) : (pressed ? .rightMouseDown : .rightMouseUp), button, point)
    }
    func key(_ code: CGKeyCode, _ pressed: Bool) {
        guard enabled, AXIsProcessTrusted() else { return }
        CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: pressed)?.post(tap: .cghidEventTap)
    }
    func stop() {
        finishApplicationSwitch()
        if let point = CGEvent(source: nil)?.location {
            if heldLeft { mouse(.leftMouseUp, .left, point) }
            if heldRight { mouse(.rightMouseUp, .right, point) }
        }
        if enabled { key(36, false); key(53, false) }
        heldLeft = false; heldRight = false; enabled = false; scrollRemainder = 0
    }
    func axis(_ value: Float) -> Double {
        let magnitude = abs(Double(value))
        guard magnitude > 0.16 else { return 0 }
        return (value < 0 ? -1 : 1) * pow((magnitude - 0.16) / 0.84, 1.7)
    }
    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - last, 0.05); last = now
        guard enabled else { return }
        guard AXIsProcessTrusted(), let pad = pad else { stop(); refresh(); return }
        let dx = axis(pad.leftThumbstick.xAxis.value) * speed.doubleValue * dt
        let dy = -axis(pad.leftThumbstick.yAxis.value) * speed.doubleValue * dt
        if (dx != 0 || dy != 0), var point = CGEvent(source: nil)?.location {
            point.x += dx; point.y += dy
            var count: UInt32 = 0
            var displays = [CGDirectDisplayID](repeating: 0, count: 32)
            if CGGetActiveDisplayList(32, &displays, &count) == .success {
                let bounds = displays.prefix(Int(count)).map { CGDisplayBounds($0) }
                if !bounds.contains(where: { $0.contains(point) }) {
                    let candidates = bounds.map { CGRect -> CGPoint in CGPoint(x: min(max(point.x, CGRect.minX), CGRect.maxX - 1), y: min(max(point.y, CGRect.minY), CGRect.maxY - 1)) }
                    point = candidates.min(by: { hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y) }) ?? point
                }
            }
            mouse(heldLeft ? .leftMouseDragged : (heldRight ? .rightMouseDragged : .mouseMoved), heldRight && !heldLeft ? .right : .left, point)
        }
        scrollRemainder += axis(pad.rightThumbstick.yAxis.value) * 600 * dt
        let pixels = Int32(scrollRemainder)
        if pixels != 0 {
            CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: pixels, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
            scrollRemainder -= Double(pixels)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { stop() }
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
