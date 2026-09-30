import Cocoa
import GameController
import ApplicationServices
import Security

struct DoctorSnapshot: Codable {
    let version: String
    let macOS: String
    let accessibility: Bool
    let controllers: Int
    let controllerName: String
    let extendedProfile: Bool
    let active: Bool
    let inputEvents: Int
    let lastInput: String
    let secondsSinceInput: Double?
    let adHocSignature: Bool?
    let appPath: String
    let context: String
}

func hasAdHocSignature() -> Bool? {
    var code: SecCode?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
    var information: CFDictionary?
    guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
          let dictionary = information as? [String: Any],
          let flags = dictionary[kSecCodeInfoFlags as String] as? NSNumber else { return nil }
    return flags.uint32Value & 0x2 != 0
}

final class DoctorWindow: NSObject {
    private var window: NSWindow?
    var isVisible: Bool { window?.isVisible == true }
    private let report = NSTextField(wrappingLabelWithString: "")
    private var timer: Timer?
    private var snapshot: (() -> DoctorSnapshot)?
    var openPermissions: (() -> Void)?
    var openBluetooth: (() -> Void)?
    var repairPermission: (() -> Void)?
    func show(snapshot: @escaping () -> DoctorSnapshot) {
        self.snapshot = snapshot
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 560), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = "Doctor de ControlGame"
            w.isReleasedWhenClosed = false
            let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
            stack.translatesAutoresizingMaskIntoConstraints = false
            w.contentView!.addSubview(stack)
            NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: w.contentView!.topAnchor, constant: 24)])
            stack.addArrangedSubview(NSTextField(wrappingLabelWithString: "Prueba los sticks y botones: aquí se muestra si llegan a la app. Doctor pausa el control del escritorio para que puedas probar sin hacer clic ni cambiar de ventana."))
            stack.addArrangedSubview(report)
            for (title, action) in [("Abrir Accesibilidad", #selector(permissions)), ("Abrir Bluetooth", #selector(bluetooth)), ("Restablecer permiso de esta app", #selector(repair)), ("Exportar diagnóstico…", #selector(exportReport))] {
                stack.addArrangedSubview(NSButton(title: title, target: self, action: action))
            }
            window = w
        }
        update()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.window?.isVisible == true { self.update() } else { self.timer?.invalidate() }
        }
        window?.center(); window?.makeKeyAndOrderFront(nil)
    }
    private func update() {
        guard let value = snapshot?() else { return }
        let permission = value.accessibility ? "Listo" : "Falta autorización: abre Accesibilidad y habilita ControlGame"
        let controller = value.extendedProfile ? value.controllerName : "Sin control compatible: conéctalo en Bluetooth"
        let signing = value.adHocSignature == true ? "Temporal: las actualizaciones pueden requerir autorización nueva" : (value.adHocSignature == false ? "Firma presente; continuidad entre versiones no comprobada" : "No comprobada")
        let input = value.inputEvents == 0 ? "Todavía sin eventos: mueve un stick o pulsa A" : "\(value.lastInput) · \(value.inputEvents) eventos"
        report.stringValue = "Versión \(value.version) · macOS \(value.macOS)\nPermiso: \(permission)\nControl: \(controller)\nEntrada: \(input)\nEstado: \(value.active ? "Activo" : "Pausado")\nFirma: \(signing)\nContexto: \(value.context)"
    }
    @objc private func permissions() { openPermissions?() }
    @objc private func bluetooth() { openBluetooth?() }
    @objc private func repair() { repairPermission?() }
    @objc private func exportReport() {
        guard let value = snapshot?() else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "ControlGame-diagnostico.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            let alert = NSAlert(); alert.messageText = "No se pudo guardar el diagnóstico"; alert.informativeText = error.localizedDescription; alert.runModal()
        }
    }
}
