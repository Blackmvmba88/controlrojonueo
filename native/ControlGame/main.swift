import Cocoa
import GameController
import ApplicationServices

final class FlippedContentView: NSView { override var isFlipped: Bool { true } }

final class App: NSObject, NSApplicationDelegate {
    let assistedNavigation = NSButton(checkboxWithTitle: "Selección asistida (tarjetas, campos y botones)", target: nil, action: nil)
    let videoMode = NSButton(checkboxWithTitle: "Forzar modo video (YouTube se detecta automáticamente)", target: nil, action: nil)
    let doctor = DoctorWindow()
    lazy var adHocSignature = hasAdHocSignature()
    let contextQueue = DispatchQueue(label: "ControlGame.context", qos: .utility)
    var contextPending = false
    var contextGeneration = 0
    var inputEvents = 0
    var lastInput = "Sin entrada"
    var lastInputAt: Double?
    var permissionGranted = false
    var lastPermissionCheck: Double = 0
    var displayBounds: [CGRect] = []
    var heldKeys: Set<CGKeyCode> = []
    var permissionRepairRunning = false
    var inputTimer: Timer?
    var healthTimer: Timer?
    var youtubeVideo = false
    var editingText = false
    var contextPID: pid_t?
    var lastContextCheck: Double = 0
    var lastSeek: Double = 0
    let navigator = SpatialNavigator()
    let navigationStatus = NSTextField(labelWithString: "Cruz: flechas de la app · A: clic")
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ControlGame · Xbox como mouse"
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]; scroll.hasVerticalScroller = true
        let document = FlippedContentView(frame: NSRect(x: 0, y: 0, width: 520, height: 760))
        document.autoresizingMask = [.width]
        scroll.documentView = document
        window.contentView!.addSubview(scroll)
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24)])
        let version = ProcessInfo.processInfo.operatingSystemVersion
        stack.addArrangedSubview(NSTextField(labelWithString: "macOS detectado: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"))
        let guide = NSTextField(wrappingLabelWithString: "1. Enciende tu Xbox Series X/S y mantén pulsado el botón de emparejamiento.\n2. Conéctalo en Bluetooth.\n3. Autoriza Accesibilidad y activa el mouse.")
        stack.addArrangedSubview(guide)
        let bluetooth = NSButton(title: "Abrir Bluetooth", target: self, action: #selector(openBluetooth))
        stack.addArrangedSubview(bluetooth)
        stack.addArrangedSubview(NSButton(title: "Autorizar Accesibilidad", target: self, action: #selector(authorize)))
        stack.addArrangedSubview(status)
        stack.addArrangedSubview(NSButton(title: "Doctor · revisar y probar control", target: self, action: #selector(showDoctor)))
        stack.addArrangedSubview(videoMode)
        stack.addArrangedSubview(assistedNavigation)
        stack.addArrangedSubview(navigationStatus)
        toggle.target = self; toggle.action = #selector(changeActive)
        stack.addArrangedSubview(toggle)
        stack.addArrangedSubview(NSTextField(labelWithString: "Velocidad del cursor"))
        stack.addArrangedSubview(speed)
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString: "Stick izquierdo: cursor · Stick derecho: scroll\nA: clic y arrastrar · B: clic derecho · X: Enter · Y: Escape\nRT/LT: cambiar app · En video: adelantar/retroceder\nMenú (☰): pausar o reanudar"))
        NotificationCenter.default.addObserver(self, selector: #selector(scan), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(scan), name: .GCControllerDidDisconnect, object: nil)
        doctor.openPermissions = { [weak self] in self?.authorize() }
        doctor.openBluetooth = { [weak self] in self?.openBluetooth() }
        doctor.repairPermission = { [weak self] in self?.repairPermission() }
        speed.doubleValue = UserDefaults.standard.object(forKey: "cursorSpeed") as? Double ?? 900
        assistedNavigation.state = UserDefaults.standard.bool(forKey: "assistedNavigation") ? .on : .off
        videoMode.state = UserDefaults.standard.bool(forKey: "manualVideoMode") ? .on : .off
        for control in [assistedNavigation, videoMode] { control.target = self; control.action = #selector(savePreferences) }
        speed.target = self; speed.action = #selector(savePreferences)
        updateDisplays()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(frontApplicationChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateDisplays), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        GCController.shouldMonitorBackgroundEvents = true
        scan()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refresh()
            if self.enabled && !self.permissionGranted { self.stop(); self.refresh() }
        }
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationDidBecomeActive(_ notification: Notification) { refresh() }
    @objc func frontApplicationChanged() {
        navigator.clear()
        contextGeneration += 1; contextPID = nil; youtubeVideo = false; editingText = false
        lastContextCheck = 0
    }
    @objc func openBluetooth() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!) }
    @objc func authorize() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func startInputTimer() {
        inputTimer?.invalidate()
        last = ProcessInfo.processInfo.systemUptime
        inputTimer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        inputTimer?.tolerance = 0.002
        RunLoop.main.add(inputTimer!, forMode: .common)
    }
    @objc func changeActive() {
        guard !doctor.isVisible else { navigationStatus.stringValue = "Cierra Doctor antes de activar el mouse"; return }
        permissionGranted = AXIsProcessTrusted()
        if enabled { stop() } else if permissionGranted, pad != nil { enabled = true; startInputTimer() } else {
            let alert = NSAlert(); alert.messageText = "Falta conectar el control o autorizar Accesibilidad"; alert.informativeText = "Usa los botones de esta ventana y después vuelve a activar el mouse."; alert.runModal()
        }
        refresh()
    }
    @objc func savePreferences() {
        UserDefaults.standard.set(speed.doubleValue, forKey: "cursorSpeed")
        UserDefaults.standard.set(assistedNavigation.state == .on, forKey: "assistedNavigation")
        UserDefaults.standard.set(videoMode.state == .on, forKey: "manualVideoMode")
        navigator.clear()
    }
    @objc func updateDisplays() {
        var count: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 32)
        if CGGetActiveDisplayList(32, &displays, &count) == .success {
            displayBounds = displays.prefix(Int(count)).map { CGDisplayBounds($0) }
        }
    }
    func doctorSnapshot() -> DoctorSnapshot {
        DoctorSnapshot(version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?", macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            accessibility: AXIsProcessTrusted(), controllers: GCController.controllers().count,
            controllerName: controller?.vendorName ?? "Ninguno", extendedProfile: pad != nil, active: enabled,
            inputEvents: inputEvents, lastInput: lastInput, secondsSinceInput: lastInputAt.map { ProcessInfo.processInfo.systemUptime - $0 },
            adHocSignature: adHocSignature, appPath: Bundle.main.bundlePath,
            context: editingText ? "Campo de texto" : (isVideo ? "Video" : "Escritorio / no comprobado"))
    }
    @objc func showDoctor() {
        stop(); refresh()
        doctor.show { [unowned self] in self.doctorSnapshot() }
    }
    func repairPermission() {
        guard !permissionRepairRunning else { return }
        stop(); refresh(); permissionRepairRunning = true
        let identifier = Bundle.main.bundleIdentifier ?? "local.blackmamba.ControlGame"
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", "Accessibility", identifier]
            let output = Pipe(); process.standardOutput = output; process.standardError = output
            do {
                try process.run(); process.waitUntilExit()
                let success = process.terminationStatus == 0
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.permissionRepairRunning = false
                    if success { self.authorize() } else {
                        let alert = NSAlert(); alert.messageText = "No se pudo restablecer el permiso"; alert.informativeText = "En Accesibilidad, elimina la entrada anterior de ControlGame y agrega esta app de nuevo."; alert.runModal()
                    }
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async { self?.permissionRepairRunning = false; self?.navigationStatus.stringValue = "No se pudo iniciar la reparación. Abre Accesibilidad." }
            }
        }
    }
    func refresh() {
        permissionGranted = AXIsProcessTrusted()
        lastPermissionCheck = ProcessInfo.processInfo.systemUptime
        status.stringValue = "\(controller?.vendorName ?? "Control sin conectar") · \(AXIsProcessTrusted() ? "Permiso listo" : "Falta Accesibilidad")"
        toggle.title = enabled ? "Pausar mouse" : "Activar mouse"
    }
    @objc func scan() {
        let next = GCController.controllers().first { $0.extendedGamepad != nil }
        if controller === next { refresh(); return }
        stop()
        pad?.valueChangedHandler = nil
        pad?.buttonA.pressedChangedHandler = nil; pad?.buttonB.pressedChangedHandler = nil
        pad?.buttonX.pressedChangedHandler = nil; pad?.buttonY.pressedChangedHandler = nil
        pad?.buttonMenu.pressedChangedHandler = nil
        pad?.dpad.up.pressedChangedHandler = nil; pad?.dpad.down.pressedChangedHandler = nil
        pad?.dpad.left.pressedChangedHandler = nil; pad?.dpad.right.pressedChangedHandler = nil
        pad?.rightTrigger.pressedChangedHandler = nil
        pad?.leftTrigger.pressedChangedHandler = nil
        controller = next; pad = next?.extendedGamepad
        next?.handlerQueue = .main
        inputEvents = 0; lastInputAt = nil; lastInput = "Sin entrada"
        pad?.valueChangedHandler = { [weak self] profile, element in
            guard let self else { return }
            self.inputEvents += 1; self.lastInputAt = ProcessInfo.processInfo.systemUptime
            if (element === profile.leftThumbstick || element === profile.leftThumbstick.xAxis || element === profile.leftThumbstick.yAxis) { self.lastInput = "Stick izquierdo" }
            else if (element === profile.rightThumbstick || element === profile.rightThumbstick.xAxis || element === profile.rightThumbstick.yAxis) { self.lastInput = "Stick derecho" }
            else if element === profile.dpad { self.lastInput = "Cruz" }
            else if element === profile.leftTrigger { self.lastInput = "LT" }
            else if element === profile.rightTrigger { self.lastInput = "RT" }
            else { self.lastInput = "Botón del control" }
        }
        pad?.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in self?.button(.left, pressed) }
        pad?.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in self?.backButton(pressed) }
        pad?.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in self?.key(36, pressed) }
        pad?.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in self?.key(53, pressed) }
        pad?.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.changeActive() } }
        pad?.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.switchApplication(backward: false, pressed: pressed)
        }
        pad?.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.switchApplication(backward: true, pressed: pressed)
        }
        pad?.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.navigate(dx: 0, dy: -1) } }
        pad?.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.navigate(dx: 0, dy: 1) } }
        pad?.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.navigate(dx: -1, dy: 0) } }
        pad?.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.navigate(dx: 1, dy: 0) } }
        refresh()
    }
    func navigate(dx: Double, dy: Double) {
        guard enabled, AXIsProcessTrusted(), !switchingApplications, !heldLeft, !heldRight else { return }
        if assistedNavigation.state == .on {
            navigationStatus.stringValue = navigator.move(dx: dx, dy: dy)
        } else {
            navigator.clear()
            let code: CGKeyCode = dx < 0 ? 123 : (dx > 0 ? 124 : (dy < 0 ? 126 : 125))
            key(code, true); key(code, false)
            navigationStatus.stringValue = "Cruz: flechas normales · X: Enter"
        }
    }
    func updateVideoContext(force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastContextCheck > 1 else { return }
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        lastContextCheck = now
        if force {
            contextGeneration += 1
            let context = navigator.videoContext()
            youtubeVideo = context.youtube; editingText = context.editing; contextPID = pid
            return
        }
        guard !contextPending else { return }
        contextPending = true
        contextGeneration += 1
        let generation = contextGeneration
        contextQueue.async { [weak self] in
            let context = SpatialNavigator().videoContext()
            DispatchQueue.main.async {
                guard let self else { return }
                self.contextPending = false
                guard self.enabled, generation == self.contextGeneration,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
                self.youtubeVideo = context.youtube; self.editingText = context.editing; self.contextPID = pid
            }
        }
    }
    var isVideo: Bool { !editingText && (youtubeVideo || videoMode.state == .on) }
    func backButton(_ pressed: Bool) {
        guard enabled, permissionGranted, !switchingApplications else { return }
        if !pressed { if heldRight { button(.right, false) }; return }
        updateVideoContext(force: true)
        if isVideo {
            if youtubeVideo && navigator.exitYouTubeTheater() {
                navigationStatus.stringValue = "Video: salir del modo cine"
            } else {
                key(53, true); key(53, false)
                navigationStatus.stringValue = "Video: Escape para salir de pantalla completa"
            }
        } else { button(.right, true) }
    }
    func seekVideo(backward: Bool) {
        updateVideoContext(force: true)
        guard enabled, permissionGranted, isVideo, !heldLeft, !heldRight, !switchingApplications else { return }
        let code: CGKeyCode = backward ? 123 : 124
        key(code, true); key(code, false)
        navigationStatus.stringValue = backward ? "Video: retroceder" : "Video: adelantar"
    }
    func switchApplication(backward: Bool, pressed: Bool) {
        guard enabled, permissionGranted, !heldLeft, !heldRight else { return }
        if pressed && !switchingApplications {
            updateVideoContext(force: true)
            if isVideo { seekVideo(backward: backward); return }
        }
        if !pressed {
            if pad?.leftTrigger.isPressed != true && pad?.rightTrigger.isPressed != true {
                finishApplicationSwitch()
            }
            return
        }
        guard enabled, AXIsProcessTrusted(), !heldLeft, !heldRight else { return }
        navigator.clear()
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
        guard enabled, permissionGranted, !switchingApplications, let point = CGEvent(source: nil)?.location else { return }
        navigator.clear()
        if button == .left { heldLeft = pressed } else { heldRight = pressed }
        mouse(button == .left ? (pressed ? .leftMouseDown : .leftMouseUp) : (pressed ? .rightMouseDown : .rightMouseUp), button, point)
    }
    func key(_ code: CGKeyCode, _ pressed: Bool) {
        guard enabled, permissionGranted, !switchingApplications else { return }
        if pressed { heldKeys.insert(code) } else { heldKeys.remove(code) }
        CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: pressed)?.post(tap: .cghidEventTap)
    }
    func stop() {
        inputTimer?.invalidate(); inputTimer = nil
        navigator.clear()
        finishApplicationSwitch()
        if let point = CGEvent(source: nil)?.location {
            if heldLeft { mouse(.leftMouseUp, .left, point) }
            if heldRight { mouse(.rightMouseUp, .right, point) }
        }
        for code in heldKeys { CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)?.post(tap: .cghidEventTap) }
        heldKeys.removeAll()
        contextGeneration += 1; contextPID = nil; youtubeVideo = false; editingText = false
        heldLeft = false; heldRight = false; enabled = false; scrollRemainder = 0
    }
    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - last, 0.05); last = now
        if now - lastPermissionCheck > 1 {
            permissionGranted = AXIsProcessTrusted(); lastPermissionCheck = now
        }
        guard enabled else { return }
        guard permissionGranted, let pad = pad else { stop(); refresh(); return }
        updateVideoContext()
        guard !switchingApplications else { return }
        let seekAxis = pad.rightThumbstick.xAxis.value
        if isVideo && abs(seekAxis) > 0.55 && now - lastSeek > 0.35 {
            lastSeek = now
            seekVideo(backward: seekAxis < 0)
        }
        let dx = pointerAxis(pad.leftThumbstick.xAxis.value) * speed.doubleValue * dt
        let dy = -pointerAxis(pad.leftThumbstick.yAxis.value) * speed.doubleValue * dt
        if (dx != 0 || dy != 0), var point = CGEvent(source: nil)?.location {
            navigator.clear()
            point.x += dx; point.y += dy
            point = boundedPointer(point, displays: displayBounds)
            mouse(heldLeft ? .leftMouseDragged : (heldRight ? .rightMouseDragged : .mouseMoved), heldRight && !heldLeft ? .right : .left, point)
        }
        scrollRemainder += pointerAxis(pad.rightThumbstick.yAxis.value) * 600 * dt
        let pixels = Int32(scrollRemainder)
        if pixels != 0 {
            CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: pixels, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
            scrollRemainder -= Double(pixels)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { healthTimer?.invalidate(); savePreferences(); stop() }
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.regular)
if CommandLine.arguments.contains("--doctor") {
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    delegate.controller = GCController.controllers().first { $0.extendedGamepad != nil }
    delegate.pad = delegate.controller?.extendedGamepad
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(delegate.doctorSnapshot()), let json = String(data: data, encoding: .utf8) { print(json) }
} else {
    app.run()
}
