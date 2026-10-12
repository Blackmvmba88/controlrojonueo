import AppKit
import SwiftUI
import GameController
import ApplicationServices

final class ControllerApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let dashboard = DashboardState()
    let navigator = CardNavigator()
    var menuItem: NSStatusItem!
    var window: NSWindow!
    var status: NSTextField!
    var eventLabel: NSTextField!
    var pauseButton: NSButton!
    var modePicker: NSPopUpButton!
    var controller: GCController?
    var timer: Timer?
    var paused = false
    var trusted = false
    var lastMotion = ProcessInfo.processInfo.systemUptime
    var lastTrigger = Date.distantPast
    var lastStatusWrite = Date.distantPast
    let defaults = UserDefaults.standard
    var gameApps: Set<String> {
        Set(defaults.stringArray(forKey: "gameApps") ?? [])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LaunchServices usually reuses one instance. Guard direct launches too.
        let id = Bundle.main.bundleIdentifier ?? "local.blackmamba.ControlGame"
        if NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }
        // Desktop control must keep receiving the gamepad while another app is frontmost.
        GCController.shouldMonitorBackgroundEvents = true
        buildWindow()
        menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menuItem.button?.image = NSImage(systemSymbolName: "gamecontroller", accessibilityDescription: "ControlGame")
        let menu = NSMenu()
        menu.addItem(withTitle: "Abrir ControlGame", action: #selector(showWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Pausar / reanudar", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Salir de ControlGame", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        menuItem.menu = menu
        NotificationCenter.default.addObserver(self, selector: #selector(connected(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnected(_:)), name: .GCControllerDidDisconnect, object: nil)
        if let existing = GCController.controllers().first { bind(existing) }
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        refresh()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.delegate = self
        window.title = "ControlGame · BlackMamba"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(calibratedRed: 0.025, green: 0.035, blue: 0.08, alpha: 1)
        window.minSize = NSSize(width: 920, height: 690)
        window.center()
        status = NSTextField(labelWithString: "")
        eventLabel = NSTextField(labelWithString: "Esperando entrada del mando")
        pauseButton = NSButton()
        modePicker = NSPopUpButton()
        modePicker.addItems(withTitles: ["Automático", "Escritorio", "Juego"])
        modePicker.selectItem(at: min(2, max(0, defaults.integer(forKey: "mode"))))
        dashboard.mode = modePicker.indexOfSelectedItem
        let view = DashboardView(state: dashboard,
            pause: { [weak self] in self?.togglePause() },
            permissions: { [weak self] in self?.openPermissions() },
            mode: { [weak self] value in self?.modePicker.selectItem(at: value); self?.changeMode() },
            addGame: { [weak self] in self?.addGame() },
            editGames: { [weak self] in self?.editGames() },
            cards: { [weak self] in self?.startCards() })
        window.contentView = NSHostingView(rootView: view)
        let mainMenu = NSMenu()
        let item = NSMenuItem()
        let submenu = NSMenu()
        submenu.addItem(withTitle: "Salir de ControlGame", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = submenu
        mainMenu.addItem(item)
        NSApp.mainMenu = mainMenu
    }

    var lastExternal: NSRunningApplication?
    func gameActive() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let name = app.localizedName?.lowercased() ?? ""
        let id = app.bundleIdentifier ?? ""
        if gameApps.contains(id) { return true }
        return ["minecraft", "roblox", "fortnite", "league of legends", "world of warcraft", "flight simulator", "geforce now", "retroarch", "dolphin", "ryujinx"].contains(where: { name.contains($0) })
    }

    func canSend() -> Bool {
        if (dashboard.editing && NSApp.isActive) || paused || !AXIsProcessTrusted() { return false }
        if modePicker.indexOfSelectedItem == 2 { return false }
        if modePicker.indexOfSelectedItem == 0 && gameActive() { return false }
        return true
    }

    func tick() {
        if let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier != Bundle.main.bundleIdentifier,
           app.bundleIdentifier != "com.apple.systempreferences" { lastExternal = app }
        if let pad = controller?.extendedGamepad {
            dashboard.leftX = Double(pad.leftThumbstick.xAxis.value)
            dashboard.leftY = Double(pad.leftThumbstick.yAxis.value)
            dashboard.rightX = Double(pad.rightThumbstick.xAxis.value)
            dashboard.rightY = Double(pad.rightThumbstick.yAxis.value)
            dashboard.lt = Double(pad.leftTrigger.value)
            dashboard.rt = Double(pad.rightTrigger.value)
            let inputs: [(String, GCControllerButtonInput)] = [("A",pad.buttonA),("B",pad.buttonB),("X",pad.buttonX),("Y",pad.buttonY),("LB",pad.leftShoulder),("RB",pad.rightShoulder),("↑",pad.dpad.up),("↓",pad.dpad.down),("←",pad.dpad.left),("→",pad.dpad.right)]
            dashboard.buttons = Set(inputs.filter { $0.1.isPressed }.map { $0.0 })
        } else {
            dashboard.leftX = 0; dashboard.leftY = 0
            dashboard.rightX = 0; dashboard.rightY = 0
            dashboard.lt = 0; dashboard.rt = 0; dashboard.buttons = []
        }
        refresh()
        navigator.maintain(enabled: canSend())
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.05, max(0, now - lastMotion))
        lastMotion = now
        guard canSend(), let pad = controller?.extendedGamepad else { return }
        func axis(_ value: Float) -> Double {
            let v = Double(value)
            let deadzone = 0.18
            guard abs(v) > deadzone else { return 0 }
            let scaled = (abs(v) - deadzone) / (1 - deadzone)
            return (v < 0 ? -1 : 1) * scaled * scaled
        }
        let x = axis(pad.leftThumbstick.xAxis.value)
        let y = axis(pad.leftThumbstick.yAxis.value)
        if x != 0 || y != 0 { navigator.clear() }
        if x != 0 || y != 0, let event = CGEvent(source: nil) {
            let speed = defaults.double(forKey: "cursorSpeed")
            let velocity = speed > 0 ? speed : 900
            var point = event.location
            point.x += x * velocity * dt
            point.y -= y * velocity * dt
            let bounds = NSScreen.screens.reduce(CGRect.null) { result, screen in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return result }
                return result.union(CGDisplayBounds(CGDirectDisplayID(number.uint32Value)))
            }
            if !bounds.isNull {
                point.x = min(bounds.maxX - 1, max(bounds.minX, point.x))
                point.y = min(bounds.maxY - 1, max(bounds.minY, point.y))
            }
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                    mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
        let scrollX = Int32((axis(pad.rightThumbstick.xAxis.value) * 1200 * dt).rounded())
        let scrollY = Int32((axis(pad.rightThumbstick.yAxis.value) * 1200 * dt).rounded())
        if scrollX != 0 || scrollY != 0 {
            navigator.clear()
            CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                    wheel1: scrollY, wheel2: -scrollX, wheel3: 0)?.post(tap: .cghidEventTap)
        }
    }

    func refresh() {
        trusted = AXIsProcessTrusted()
        let device = controller?.vendorName ?? "Sin control conectado"
        let state: String
        if paused { state = "Pausado · no se envían atajos" }
        else if dashboard.editing && NSApp.isActive { state = "Editando botones · atajos suspendidos" }
        else if !trusted { state = "Falta permiso de Accesibilidad" }
        else if !canSend() { state = "Modo Juego · mando libre de atajos" }
        else { state = "Escritorio activo" }
        status.stringValue = "\(device)\n\(state)"
        pauseButton.title = paused ? "Reanudar" : "Pausar"
        dashboard.connected = controller != nil
        dashboard.device = device
        dashboard.trusted = trusted
        dashboard.paused = paused
        dashboard.active = canSend()
        dashboard.state = state
        dashboard.lastEvent = eventLabel.stringValue
        dashboard.mode = modePicker.indexOfSelectedItem
        if Date().timeIntervalSince(lastStatusWrite) > 1 {
            let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ControlGame")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let report: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier,
                                       "controller": device, "connected": controller != nil,
                                       "accessibility": trusted, "sendingEnabled": canSend(),
                                       "state": state, "backgroundMonitoring": GCController.shouldMonitorBackgroundEvents,
                                       "frontmostApp": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: .prettyPrinted) {
                try? data.write(to: directory.appendingPathComponent("status.json"), options: .atomic)
            }
            lastStatusWrite = Date()
        }
    }

    func key(_ code: CGKeyCode, flags: CGEventFlags = [], label: String) {
        guard canSend() else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        eventLabel.stringValue = label
    }

    func playPause() {
        guard canSend() else { return }
        // macOS NX_KEYTYPE_PLAY, key down/up as system-defined events.
        for state in [0xA, 0xB] {
            NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0,
                              windowNumber: 0, context: nil, subtype: 8,
                              data1: (16 << 16) | (state << 8), data2: -1)?.cgEvent?.post(tap: .cghidEventTap)
        }
        eventLabel.stringValue = "X → reproducir / pausar"
    }

    func bind(_ device: GCController) {
        guard let pad = device.extendedGamepad else { return }
        controller = device
        func button(_ input: GCControllerButtonInput, _ action: @escaping () -> Void) {
            input.pressedChangedHandler = { _, _, pressed in
                if pressed { DispatchQueue.main.async(execute: action) }
            }
        }
        let inputs: [(String, GCControllerButtonInput)] = [("A",pad.buttonA),("B",pad.buttonB),("X",pad.buttonX),("Y",pad.buttonY),("LB",pad.leftShoulder),("RB",pad.rightShoulder),("LT",pad.leftTrigger),("RT",pad.rightTrigger),("↑",pad.dpad.up),("↓",pad.dpad.down),("←",pad.dpad.left),("→",pad.dpad.right),("Menu",pad.buttonMenu)]
        for (name, input) in inputs { button(input) { [weak self] in self?.perform(name) } }
        if let input = pad.buttonOptions { button(input) { [weak self] in self?.perform("View") } }
        if let input = pad.leftThumbstickButton { button(input) { [weak self] in self?.perform("L3") } }
        if let input = pad.rightThumbstickButton { button(input) { [weak self] in self?.perform("R3") } }
        refresh()
    }

    func startCards() {
        guard let browser = navigator.browserApplication(preferred: lastExternal) else {
            eventLabel.stringValue = "Abre YouTube en Safari o Chrome para seleccionar tarjetas"
            return
        }
        dashboard.setCardProfile(true)
        browser.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.canSend() else { return }
            self.navigator.clear()
            if !self.navigator.move(.right, completion: { [weak self] message in self?.eventLabel.stringValue = message }) {
                self.eventLabel.stringValue = "No se encontraron tarjetas; abre la página principal de YouTube"
            }
        }
    }

    func perform(_ button: String) {
        if dashboard.editing && NSApp.isActive { dashboard.selectedButton = button; return }
        guard canSend() else { return }
        var actionID = dashboard.effectiveAction(button)
        // Outside YouTube, the profile leaves the user's ordinary mappings intact.
        if dashboard.cardProfile, ["↑", "↓", "←", "→", "A", "B"].contains(button), !navigator.scan() {
            actionID = dashboard.mappings[button]
        }
        guard let action = ControlAction.all.first(where: { $0.id == actionID }), action.id != "none" else { return }
        let direction: [String: CardDirection] = ["cardUp":.up, "cardDown":.down, "cardLeft":.left, "cardRight":.right]
        if let direction = direction[action.id] {
            if !navigator.move(direction, completion: { [weak self] message in self?.eventLabel.stringValue = message }) {
                let code: CGKeyCode = direction == .up ? 126 : direction == .down ? 125 : direction == .left ? 123 : 124
                key(code, label: "Flecha · no hay tarjetas de YouTube accesibles")
            }
            return
        }
        if action.id == "cardOpen", let message = navigator.activate() { eventLabel.stringValue = message; return }
        if action.id == "back" { navigator.clear() }
        if let code = action.code { key(code, flags: action.flags, label: action.title) }
        else if ["click", "rightClick", "doubleClick", "cardOpen"].contains(action.id) {
            guard let point = CGEvent(source: nil)?.location else { return }
            let right = action.id == "rightClick"
            for count in 1...(action.id == "doubleClick" ? 2 : 1) {
                for type: CGEventType in [right ? .rightMouseDown : .leftMouseDown, right ? .rightMouseUp : .leftMouseUp] {
                    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: right ? .right : .left)
                    event?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
                    event?.post(tap: .cghidEventTap)
                }
            }
        } else {
            let code = ["play":16, "volumeUp":0, "volumeDown":1, "mute":7][action.id] ?? 16
            for state in [0xA, 0xB] {
                NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: (code << 16) | (state << 8), data2: -1)?.cgEvent?.post(tap: .cghidEventTap)
            }
        }
        eventLabel.stringValue = "\(button) → \(action.title)"
    }

    func appSwitch(previous: Bool) {
        guard Date().timeIntervalSince(lastTrigger) > 0.3 else { return }
        lastTrigger = Date()
        key(48, flags: previous ? [.maskCommand, .maskShift] : .maskCommand, label: "Gatillo → cambiar aplicación")
    }
    @objc func connected(_ note: Notification) {
        if controller == nil, let device = note.object as? GCController { bind(device) }
    }
    @objc func disconnected(_ note: Notification) {
        if let device = note.object as? GCController, device === controller {
            controller = nil
            if let next = GCController.controllers().first { bind(next) }
            refresh()
        }
    }
    @objc func togglePause() { paused.toggle(); refresh() }
    @objc func changeMode() { defaults.set(modePicker.indexOfSelectedItem, forKey: "mode"); refresh() }
    @objc func openPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func addGame() {
        guard let app = lastExternal, let id = app.bundleIdentifier else { return }
        let alert = NSAlert()
        alert.messageText = "¿Tratar \(app.localizedName ?? id) como juego?"
        alert.informativeText = "En modo Automático no se enviarán atajos mientras esta aplicación esté al frente."
        alert.addButton(withTitle: "Añadir")
        alert.addButton(withTitle: "Cancelar")
        if alert.runModal() == .alertFirstButtonReturn {
            var apps = gameApps; apps.insert(id)
            defaults.set(Array(apps), forKey: "gameApps")
        }
    }
    @objc func editGames() {
        let alert = NSAlert()
        alert.messageText = "Aplicaciones añadidas como juegos"
        alert.informativeText = gameApps.sorted().joined(separator: "\n").isEmpty ? "No has añadido aplicaciones." : gameApps.sorted().joined(separator: "\n")
        alert.addButton(withTitle: "Cerrar")
        alert.addButton(withTitle: "Vaciar lista")
        if alert.runModal() == .alertSecondButtonReturn { defaults.set([], forKey: "gameApps") }
    }
    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dashboard.editing = false
        sender.orderOut(nil)
        return false
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationDidBecomeActive(_ notification: Notification) { if status != nil { refresh() } }
    func applicationWillTerminate(_ notification: Notification) {
        navigator.clear()
        timer?.invalidate()
        GCController.stopWirelessControllerDiscovery()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = ControllerApp()
app.delegate = delegate
app.run()
