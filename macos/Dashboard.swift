import SwiftUI
import AppKit
import ApplicationServices

struct ControlAction: Identifiable {
    let id: String
    let title: String
    let category: String
    let code: CGKeyCode?
    let flags: CGEventFlags
    init(_ id: String, _ title: String, _ category: String, _ code: CGKeyCode? = nil, _ flags: CGEventFlags = []) {
        self.id = id; self.title = title; self.category = category; self.code = code; self.flags = flags
    }
    static let all: [ControlAction] = [
        .init("none", "Sin acción", "General"),
        .init("cardUp", "Tarjeta arriba", "Tarjetas de YouTube"), .init("cardDown", "Tarjeta abajo", "Tarjetas de YouTube"),
        .init("cardLeft", "Tarjeta izquierda", "Tarjetas de YouTube"), .init("cardRight", "Tarjeta derecha", "Tarjetas de YouTube"),
        .init("cardOpen", "Abrir tarjeta / clic", "Tarjetas de YouTube"),
        .init("click", "Clic izquierdo", "Mouse"), .init("rightClick", "Clic derecho", "Mouse"), .init("doubleClick", "Doble clic", "Mouse"),
        .init("enter", "Aceptar / Enter", "Navegación", 36), .init("escape", "Cancelar / Escape", "Navegación", 53),
        .init("up", "Flecha arriba", "Navegación", 126), .init("down", "Flecha abajo", "Navegación", 125),
        .init("left", "Flecha izquierda", "Navegación", 123), .init("right", "Flecha derecha", "Navegación", 124),
        .init("tab", "Siguiente campo", "Navegación", 48), .init("backTab", "Campo anterior", "Navegación", 48, .maskShift),
        .init("back", "Atrás", "Navegador", 33, .maskCommand), .init("forward", "Adelante", "Navegador", 30, .maskCommand),
        .init("prevTab", "Pestaña anterior", "Navegador", 48, [.maskControl, .maskShift]), .init("nextTab", "Pestaña siguiente", "Navegador", 48, .maskControl),
        .init("newTab", "Nueva pestaña", "Navegador", 17, .maskCommand), .init("closeTab", "Cerrar pestaña", "Navegador", 13, .maskCommand),
        .init("reload", "Recargar", "Navegador", 15, .maskCommand), .init("address", "Barra de dirección", "Navegador", 37, .maskCommand),
        .init("copy", "Copiar", "Edición", 8, .maskCommand), .init("paste", "Pegar", "Edición", 9, .maskCommand),
        .init("cut", "Cortar", "Edición", 7, .maskCommand), .init("undo", "Deshacer", "Edición", 6, .maskCommand),
        .init("selectAll", "Seleccionar todo", "Edición", 0, .maskCommand), .init("delete", "Borrar", "Edición", 51),
        .init("play", "Reproducir / pausar", "Multimedia"), .init("volumeUp", "Subir volumen", "Multimedia"), .init("volumeDown", "Bajar volumen", "Multimedia"), .init("mute", "Silenciar", "Multimedia"),
        .init("prevApp", "Aplicación anterior", "Sistema", 48, [.maskCommand, .maskShift]), .init("nextApp", "Aplicación siguiente", "Sistema", 48, .maskCommand),
        .init("mission", "Mission Control", "Sistema", 126, .maskControl), .init("fullscreen", "Pantalla completa", "Sistema", 3, [.maskControl, .maskCommand]),
        .init("screenshot", "Captura de área", "Sistema", 21, [.maskCommand, .maskShift])
    ]
    static let buttons = ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "↑", "↓", "←", "→", "L3", "R3", "Menu", "View"]
    static let initial = ["A":"click", "B":"escape", "X":"play", "Y":"fullscreen", "LB":"prevTab", "RB":"nextTab", "LT":"prevApp", "RT":"nextApp", "↑":"up", "↓":"down", "←":"left", "→":"right", "L3":"doubleClick", "R3":"rightClick", "Menu":"enter", "View":"mission"]
}

final class DashboardState: ObservableObject {
    @Published var editing = false
    @Published var selectedButton = "A"
    @Published var mappings: [String: String] = {
        let saved = UserDefaults.standard.dictionary(forKey: "buttonMappings") as? [String: String] ?? [:]
        return ControlAction.initial.merging(saved.filter { entry in ControlAction.buttons.contains(entry.key) && ControlAction.all.contains(where: { action in action.id == entry.value }) }) { _, new in new }
    }()
    func assign(_ action: String) {
        mappings[selectedButton] = action
        UserDefaults.standard.set(mappings, forKey: "buttonMappings")
    }
    @Published var cardProfile = UserDefaults.standard.object(forKey: "cardProfile") == nil ? true : UserDefaults.standard.bool(forKey: "cardProfile")
    func setCardProfile(_ enabled: Bool) {
        cardProfile = enabled
        UserDefaults.standard.set(enabled, forKey: "cardProfile")
    }
    func reset() {
        mappings = ControlAction.initial
        UserDefaults.standard.set(mappings, forKey: "buttonMappings")
    }
    func effectiveAction(_ button: String) -> String? {
        if cardProfile, let action = ["↑":"cardUp", "↓":"cardDown", "←":"cardLeft", "→":"cardRight", "A":"cardOpen", "B":"back"][button] { return action }
        return mappings[button]
    }
    func actionTitle(_ button: String) -> String {
        ControlAction.all.first { $0.id == effectiveAction(button) }?.title ?? "Sin acción"
    }
    @Published var connected = false
    @Published var trusted = false
    @Published var paused = false
    @Published var active = false
    @Published var device = "Sin mando"
    @Published var state = "Conecta tu Xbox"
    @Published var lastEvent = "Esperando entrada del mando"
    @Published var mode = 0
    @Published var leftX = 0.0
    @Published var leftY = 0.0
    @Published var rightX = 0.0
    @Published var rightY = 0.0
    @Published var lt = 0.0
    @Published var rt = 0.0
    @Published var buttons: Set<String> = []
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
    }
}

struct DashboardView: View {
    @ObservedObject var state: DashboardState
    let pause: () -> Void
    let permissions: () -> Void
    let mode: (Int) -> Void
    let addGame: () -> Void
    let editGames: () -> Void
    let cards: () -> Void
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var drift = false
    @State private var guide = false
    let cyan = Color(red: 0.2, green: 0.88, blue: 1)

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.085)
            GeometryReader { geometry in
                Circle().fill(cyan.opacity(0.18)).frame(width: 510, height: 510).blur(radius: 100)
                    .offset(x: drift ? 160 : -170, y: -190)
                Circle().fill(Color.purple.opacity(0.24)).frame(width: 570, height: 570).blur(radius: 120)
                    .offset(x: geometry.size.width - (drift ? 440 : 260), y: drift ? 240 : 80)
            }.allowsHitTesting(false)
            ScrollView {
                VStack(spacing: 18) {
                    header
                    HStack(alignment: .top, spacing: 18) {
                        VStack(spacing: 18) { connection; startup }.frame(width: 235)
                        VStack(spacing: 18) { controller; modeCard }.frame(maxWidth: .infinity)
                        mapping.frame(width: 215)
                    }
                    HStack(spacing: 18) { trigger("LT", state.lt); trigger("RT", state.rt); event }
                }.padding(26).padding(.top, 32)
            }
        }
        .preferredColorScheme(.dark)
        .tint(cyan)
        .onAppear {
            if !reduceMotion { withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) { drift = true } }
        }
        .onChange(of: reduceMotion) { reduced in if reduced { drift = false } }
        .sheet(isPresented: $guide) { instructions }
        .sheet(isPresented: $state.editing) { MappingEditor(state: state) }
    }

    var header: some View {
        HStack(spacing: 14) {
            if let image = NSImage(named: NSImage.Name("AppIcon")) {
                Image(nsImage: image).resizable().scaledToFit().frame(width: 55, height: 55)
            } else { Image(systemName: "gamecontroller.fill").font(.system(size: 35)).foregroundColor(cyan) }
            VStack(alignment: .leading, spacing: 3) {
                Text("CONTROLGAME").font(.system(size: 24, weight: .bold, design: .rounded)).tracking(3)
                Text("BLACKMAMBA  /  ESCRITORIO CON MANDO").font(.system(size: 10, weight: .medium)).tracking(2).foregroundColor(.secondary)
            }
            Spacer()
            Button { guide = true } label: { Label("Cómo empezar", systemImage: "questionmark.circle") }.buttonStyle(.bordered)
            Button(action: pause) { Label(state.paused ? "Reanudar" : "Pausar", systemImage: state.paused ? "play.fill" : "pause.fill") }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    func badge(_ label: String, good: Bool, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(good ? cyan : .orange)
            Text(label).font(.system(size: 12, weight: .medium))
        }.padding(.vertical, 9).padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }

    var connection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                title("ESTADO DEL SISTEMA")
                badge(state.connected ? "Mando conectado" : "Sin mando", good: state.connected, icon: "gamecontroller")
                badge(state.trusted ? "Accesibilidad autorizada" : "Falta Accesibilidad", good: state.trusted, icon: "hand.raised")
                badge(state.paused ? "Pausado" : (state.active ? "Atajos activos" : "Atajos suspendidos"), good: state.active, icon: "bolt")
                Text(state.device).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    var startup: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                title("PARA ECHARLO A ANDAR")
                step("1", "Conecta el Xbox", "Por cable o Bluetooth.", done: state.connected)
                step("2", "Activa Accesibilidad", "Autoriza ControlGame en macOS.", done: state.trusted)
                step("3", "Activa el escritorio", "Reanuda: palanca izquierda mueve el mouse; derecha hace scroll.", done: state.active)
                if !state.trusted {
                    Button("Abrir Accesibilidad", action: permissions).buttonStyle(.borderedProminent)
                    Text("Si ya aparece activada y no funciona, quita la entrada anterior con − y añade esta app con +.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
        }
    }

    func step(_ number: String, _ name: String, _ detail: String, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(done ? "✓" : number).font(.system(size: 12, weight: .bold)).frame(width: 24, height: 24)
                .background(done ? cyan.opacity(0.2) : .white.opacity(0.08), in: Circle()).foregroundColor(done ? cyan : .white)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var controller: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack { title("ENTRADA EN VIVO"); Spacer(); Circle().fill(state.connected ? cyan : .orange).frame(width: 7, height: 7) }
                ControllerGraphic(state: state).frame(height: 220)
                Text(state.connected ? "Presiona un botón: aquí se ilumina." : "Conecta el mando para ver sus entradas.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Text(state.state).font(.system(size: 13, weight: .semibold)).foregroundColor(state.active ? cyan : .orange)
            }
        }
    }

    var modeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                title("MODO DE CONTROL")
                Picker("Modo", selection: Binding(get: { state.mode }, set: { mode($0) })) {
                    Text("Auto").tag(0); Text("Escritorio").tag(1); Text("Juego").tag(2)
                }.pickerStyle(.segmented).labelsHidden()
                Text(state.mode == 2 ? "El juego recibe el mando sin atajos del escritorio." : state.mode == 1 ? "Atajos habilitados incluso en juegos. Cambia a Juego antes de jugar." : "Suspende los atajos en juegos reconocidos. En juegos del navegador, selecciona Juego.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                HStack {
                    Button("Añadir juego", action: addGame)
                    Button("Ver lista", action: editGames)
                }.buttonStyle(.bordered)
            }
        }
    }

    var mapping: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                title("TUS CONTROLES")
                Toggle("Navegar por tarjetas", isOn: Binding(get: { state.cardProfile }, set: { state.setCardProfile($0) }))
                    .toggleStyle(.switch)
                if state.cardProfile {
                    Text("YouTube: cruceta selecciona · A abre · B vuelve. Desactiva para recuperar tus botones.").font(.caption).foregroundColor(.secondary)
                    Button("Seleccionar primera tarjeta", action: cards).buttonStyle(.bordered)
                }
                Button("Personalizar botones") { state.editing = true }.buttonStyle(.borderedProminent)
                ForEach(ControlAction.buttons, id: \.self) { button in
                    Button { state.selectedButton = button; state.editing = true } label: {
                        mappingRow(button, state.actionTitle(button), cyan)
                    }.buttonStyle(.plain)
                }
                Divider()
                mappingRow("Stick L", "Mover mouse", .white)
                mappingRow("Stick R", "Scroll", .white)
            }
        }
    }

    func mappingRow(_ key: String, _ action: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text(key).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(color).frame(width: 54, alignment: .leading).lineLimit(1)
            Text(action).font(.system(size: 11)).foregroundColor(.white.opacity(0.85))
        }
    }
    func title(_ text: String) -> some View { Text(text).font(.system(size: 10, weight: .semibold)).tracking(1.6).foregroundColor(.secondary) }
    func trigger(_ label: String, _ value: Double) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack { title(label + " · GATILLO"); Spacer(); Text(state.connected ? "\(Int(value * 100))%" : "—").font(.system(size: 17, weight: .medium, design: .monospaced)) }
                ProgressView(value: value).tint(cyan)
            }
        }.frame(maxWidth: 210)
    }
    var event: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 9) {
                title("ÚLTIMO ATAJO ENVIADO")
                Text(state.lastEvent).font(.system(size: 13, weight: .medium)).lineLimit(2)
            }
        }
    }
    var instructions: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Empieza en tres pasos").font(.title2.bold())
            Text("1. Conecta el mando Xbox por USB o Bluetooth.\n\n2. Pulsa Abrir Accesibilidad y habilita ControlGame. Si macOS muestra una autorización vieja, elimina esa entrada y añade la app instalada nuevamente.\n\n3. Selecciona Escritorio y Reanudar si está pausada. Abre Finder y prueba la cruceta.")
            Text("Para jugar, selecciona Juego. Para detener todo, cierra la app o usa Cmd+Q.").foregroundColor(cyan)
            HStack { Button("Abrir Accesibilidad", action: permissions); Spacer(); Button("Listo") { guide = false }.keyboardShortcut(.defaultAction) }
        }.padding(30).frame(width: 520).preferredColorScheme(.dark)
    }
}

struct ControllerGraphic: View {
    @ObservedObject var state: DashboardState
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let cyan = Color(red: 0.2, green: 0.88, blue: 1)
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            ZStack {
                RoundedRectangle(cornerRadius: 75).fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: w * 0.96, height: 160).rotationEffect(.degrees(-2))
                    .overlay(RoundedRectangle(cornerRadius: 75).stroke(cyan.opacity(state.connected ? 0.5 : 0.15), lineWidth: 1).frame(width: w * 0.96, height: 160).rotationEffect(.degrees(-2)))
                    .shadow(color: cyan.opacity(0.13), radius: 20)
                Text("✚").font(.system(size: 43, weight: .black)).foregroundColor(state.buttons.intersection(["↑", "↓", "←", "→"]).isEmpty ? .white.opacity(0.7) : cyan).position(x: w * 0.22, y: 87)
                stick(x: state.leftX, y: state.leftY).position(x: w * 0.37, y: 147)
                stick(x: state.rightX, y: state.rightY).position(x: w * 0.66, y: 147)
                face("Y", .yellow).position(x: w * 0.8, y: 58)
                face("X", cyan).position(x: w * 0.7, y: 87)
                face("B", .red).position(x: w * 0.9, y: 87)
                face("A", .green).position(x: w * 0.8, y: 116)
                Image(systemName: "house.fill").foregroundColor(cyan).font(.system(size: 16)).padding(12)
                    .background(cyan.opacity(0.1), in: Circle()).overlay(Circle().stroke(cyan.opacity(0.4))).position(x: w * 0.5, y: 75)
                shoulder("LB").position(x: w * 0.2, y: 22)
                shoulder("RB").position(x: w * 0.8, y: 22)
            }.opacity(state.connected ? 1 : 0.45)
        }
    }
    func face(_ name: String, _ color: Color) -> some View {
        let pressed = state.buttons.contains(name)
        return Text(name).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(pressed ? .black : color)
            .frame(width: 30, height: 30).background(pressed ? color : .black.opacity(0.45), in: Circle())
            .overlay(Circle().stroke(color.opacity(pressed ? 1 : 0.25)))
            .shadow(color: color.opacity(pressed ? 0.7 : 0), radius: 10)
            .scaleEffect(pressed ? 1.16 : 1).animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
    }
    func shoulder(_ name: String) -> some View {
        Text(name).font(.system(size: 10, weight: .bold)).frame(width: 65, height: 20)
            .background(state.buttons.contains(name) ? cyan.opacity(0.6) : .white.opacity(0.12), in: Capsule())
    }
    func stick(x: Double, y: Double) -> some View {
        ZStack {
            Circle().fill(.black.opacity(0.4)).frame(width: 57, height: 57).overlay(Circle().stroke(cyan.opacity(0.3)))
            Circle().fill(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 38, height: 38).overlay(Circle().stroke(cyan.opacity(0.7)))
                .offset(x: x * 10, y: -y * 10)
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: x)
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: y)
        }
    }
}

struct MappingEditor: View {
    @ObservedObject var state: DashboardState
    @State private var search = ""
    @State private var category = "Todas"
    @State private var confirmReset = false
    var results: [ControlAction] {
        ControlAction.all.filter { (category == "Todas" || $0.category == category) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Personaliza tu mando").font(.title2.bold()); Spacer(); Button("Listo") { state.editing = false }.keyboardShortcut(.defaultAction) }
            if state.cardProfile {
                Text("El modo Tarjetas está activo: usa sus controles o desactívalo para usar tus asignaciones.").foregroundColor(.orange)
                Button("Usar mis asignaciones") { state.setCardProfile(false) }
            }
            Text("1. Elige un botón o presiónalo en el mando.  2. Selecciona una acción.").foregroundColor(.secondary)
            Text("Mientras editas, el mando no envía clics ni atajos. Los cambios se guardan automáticamente.").font(.caption).foregroundColor(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8)) {
                ForEach(ControlAction.buttons, id: \.self) { button in
                    Button(button) { state.selectedButton = button }
                        .buttonStyle(.bordered).tint(state.selectedButton == button ? .cyan : .gray)
                        .background(state.selectedButton == button ? Color.cyan.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 6))
                }
            }
            Text("\(state.selectedButton) → \(state.actionTitle(state.selectedButton))").font(.headline)
            HStack {
                TextField("Buscar una acción…", text: $search)
                Picker("Categoría", selection: $category) {
                    ForEach(["Todas"] + Set(ControlAction.all.map { $0.category }).sorted(), id: \.self) { Text($0).tag($0) }
                }.frame(width: 240)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(results) { action in
                        Button { state.assign(action.id) } label: {
                            HStack {
                                VStack(alignment: .leading) { Text(action.title).font(.headline); Text(action.category).font(.caption).foregroundColor(.secondary) }
                                Spacer()
                                if state.mappings[state.selectedButton] == action.id { Image(systemName: "checkmark.circle.fill").foregroundColor(.cyan) }
                                else { Text("Asignar").foregroundColor(.cyan) }
                            }.padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                    }
                    if results.isEmpty { Text("No hay acciones que coincidan con tu búsqueda.").padding() }
                }
            }
            HStack { Button("Restaurar controles iniciales") { confirmReset = true }; Spacer(); Text("Los atajos actúan sobre la aplicación al frente.").font(.caption).foregroundColor(.secondary) }
        }.padding(24).frame(width: 720, height: 620).preferredColorScheme(.dark)
        .alert("¿Restaurar todos los botones?", isPresented: $confirmReset) {
            Button("Cancelar", role: .cancel) {}
            Button("Restaurar", role: .destructive) { state.reset() }
        } message: { Text("Se reemplazarán tus asignaciones por los controles iniciales.") }
    }
}
