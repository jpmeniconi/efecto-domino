import SwiftUI

// MARK: - Cálculo

/// El nivel sube cada 7 fichas en pie: una mano de dominó (en Chile se reparten 7 por jugador).
/// Cuenta como el muro: las visitas de enero más los bloques hechos. Una falta no bota fichas, así que no baja.
struct NivelDeFichas: Equatable {
    static let fichasPorMano = 7

    let fichas: Int

    var numero: Int { fichas / Self.fichasPorMano + 1 }
    /// Fichas de la mano que se está armando: de 0 a 6.
    var enMano: Int { fichas % Self.fichasPorMano }
    var faltan: Int { Self.fichasPorMano - enMano }
    var nombre: String { Self.nombre(numero) }

    /// Nombres de cómo se siente cada etapa, sin jerga de obra.
    static func nombre(_ numero: Int) -> String {
        switch numero {
        case ...1: "De vuelta"
        case 2: "Tomando ritmo"
        case 3: "Con ritmo propio"
        case 4: "Parte de tu semana"
        case 5: "En tus manos"
        default: "Por tu cuenta"
        }
    }
}

/// Un logro sale de lo que la app ya premia y se calcula del estado: no se guarda aparte ni vence.
struct Logro: Identifiable, Equatable {
    enum Clave: String, CaseIterable {
        case enero, primeraFicha, loQueTeFunciona, tresTipos, semanaCompleta, semanaPlanificada
        case holgura, puente, regreso, ajustePlan, programaCompleto
    }

    let id: Clave
    let titulo: String
    let simbolo: String
    let conseguido: Bool
    /// Logrado: qué hizo. Por lograr: cómo se consigue, en positivo.
    let detalle: String
}

enum Logros {
    /// Los que llegan solo si algo se cae. No se proponen como lo siguiente: nadie tiene que faltar para lograrlos.
    static let siAlgoSeCae: Set<Logro.Clave> = [.holgura, .puente, .regreso, .ajustePlan]

    static func calcular(_ e: EstadoObra) -> [Logro] {
        let hechos = e.bloques.filter { $0.estado == .hecho }
        let mejorSemana = Dictionary(grouping: hechos) { $0.inicio.lunes }.values.map(\.count).max() ?? 0
        let regresos = e.bloques.regresos
        let registros = hechos.filter { $0.registro != nil }.count
        let tipos = Set(hechos.map(\.tipo))
        // La holgura deja el bloque en su misma semana. «Partir el lunes» también lo mueve, pero es el efecto dominó.
        let usoHolgura = e.bloques.contains { b in
            !b.esPuente && b.origen.map { $0.lunes == b.inicio.lunes } == true
        }
        // Descartar un ajuste también lo resuelve, pero el horario sigue en el patrón.
        let cambioHorario = e.ajustesResueltos.contains { clave in !e.patron.contains { $0.clave == clave } }
        let porSemana = e.proyecto.porSemana
        let meta = e.proyecto.meta

        return Logro.Clave.allCases.map { clave in
            switch clave {
            case .enero:
                Logro(
                    id: clave, titulo: "Enero cuenta", simbolo: "calendar",
                    conseguido: e.proyecto.visitasPrevias > 0,
                    detalle: "Tus \(e.proyecto.visitasPrevias) visitas de enero ya están en tu muro: no partiste de cero."
                )
            case .primeraFicha:
                Logro(
                    id: clave, titulo: "Primera ficha", simbolo: "rectangle.split.1x2.fill",
                    conseguido: !hechos.isEmpty,
                    detalle: hechos.isEmpty
                        ? "Cuando vuelvas de un bloque, toca «Fui» y queda en pie."
                        : "Tu primer bloque del plan quedó en pie."
                )
            case .loQueTeFunciona:
                Logro(
                    id: clave, titulo: "Lo que te funciona", simbolo: "chart.bar.doc.horizontal",
                    conseguido: registros >= Aprendizajes.minimo,
                    detalle: registros >= Aprendizajes.minimo
                        ? "Con \(registros) registros ya ves qué horarios y bloques te funcionan."
                        : "Con \(cantidad(Aprendizajes.minimo - registros, "registro", "registros")) más verás qué horarios y bloques te funcionan."
                )
            case .tresTipos:
                Logro(
                    id: clave, titulo: "Los tres tipos", simbolo: "figure.mixed.cardio",
                    conseguido: tipos.count == TipoBloque.allCases.count,
                    detalle: detalleTipos(tipos)
                )
            case .semanaCompleta:
                Logro(
                    id: clave, titulo: "Semana completa", simbolo: "square.grid.2x2.fill",
                    conseguido: mejorSemana >= porSemana,
                    detalle: mejorSemana >= porSemana
                        ? "Hiciste los \(porSemana) bloques de una semana."
                        : mejorSemana == 0
                            ? "Haz los \(porSemana) bloques de una misma semana. Los cortos cuentan completo."
                            : "Ya hiciste \(mejorSemana) de \(porSemana) en una semana. Los cortos cuentan completo."
                )
            case .semanaPlanificada:
                Logro(
                    id: clave, titulo: "Semana planificada", simbolo: "calendar.badge.checkmark",
                    conseguido: !e.semanasConfirmadas.isEmpty,
                    detalle: e.semanasConfirmadas.isEmpty
                        ? "El fin de semana, confirma en un toque la semana que viene."
                        : "Confirmaste tu semana antes de que empezara."
                )
            case .holgura:
                Logro(
                    id: clave, titulo: "Usaste la holgura", simbolo: "calendar.badge.plus",
                    conseguido: usoHolgura,
                    detalle: usoHolgura
                        ? "Moviste un bloque dentro de su semana y el plan siguió en pie."
                        : "Si un bloque se cae, «Ajustar» lo lleva a un espacio libre de la misma semana."
                )
            case .puente:
                Logro(
                    id: clave, titulo: "Bloque puente", simbolo: "timer",
                    conseguido: e.bloques.contains(where: \.esPuente),
                    detalle: e.bloques.contains(where: \.esPuente)
                        ? "Elegiste un bloque corto en vez de saltarte el día. Cuenta completo."
                        : "Cuando cueste ir, un bloque puente es corto y cuenta completo."
                )
            case .regreso:
                Logro(
                    id: clave, titulo: "Ficha de regreso", simbolo: "arrow.uturn.backward",
                    conseguido: regresos > 0,
                    detalle: regresos == 0
                        ? "Si un bloque se atrasa, al volver te llevas una ficha de regreso."
                        : regresos == 1 ? "Volviste después de un atraso." : "Volviste \(regresos) veces después de un atraso."
                )
            case .ajustePlan:
                Logro(
                    id: clave, titulo: "Ajuste al plan", simbolo: "clock.arrow.circlepath",
                    conseguido: cambioHorario,
                    detalle: cambioHorario
                        ? "Cambiaste un horario que se movía seguido: se cambió el horario, no tú."
                        : "Si un horario se mueve seguido, la app te propone otro: se cambia el horario, no tú."
                )
            case .programaCompleto:
                Logro(
                    id: clave, titulo: "Plan en tus manos", simbolo: "flag.fill",
                    conseguido: hechos.count >= meta,
                    detalle: hechos.count >= meta
                        ? "Hiciste las \(meta) fichas del programa. Tu manual para seguir está listo."
                        : "Llevas \(hechos.count) de \(meta) fichas. Al completarlas, el plan pasa a tus manos con tu manual."
                )
            }
        }
    }

    /// Lo próximo que se puede lograr haciendo, no faltando.
    static func siguiente(_ logros: [Logro]) -> Logro? {
        logros.first { !$0.conseguido && !siAlgoSeCae.contains($0.id) }
    }

    private static func detalleTipos(_ hechos: Set<TipoBloque>) -> String {
        let faltan = TipoBloque.allCases.filter { !hechos.contains($0) }.map { $0.nombre.lowercased() }
        switch faltan.count {
        case 0: return "Hiciste gimnasio, caminata y en casa."
        case TipoBloque.allCases.count: return "Haz un bloque de cada tipo: gimnasio, caminata y en casa."
        default: return "Con \(faltan.joined(separator: " y ")) los completas."
        }
    }

    private static func cantidad(_ n: Int, _ singular: String, _ plural: String) -> String {
        n == 1 ? "1 \(singular)" : "\(n) \(plural)"
    }
}

// MARK: - Vista

/// Logros y niveles de «Tu avance», debajo de las fichas. Refuerzo positivo sin rachas ni comparaciones:
/// el nivel nunca baja y cada logro sale de algo que Camila hizo.
struct LogrosSeccion: View {
    @Environment(ObraStore.self) private var store
    @State private var viendoTodos = false
    #if DEBUG
    /// `-abrir logros` corre una sola vez: al volver de la lista no se abre de nuevo.
    @State private var depuracionHecha = false
    #endif

    var body: some View {
        let logros = Logros.calcular(store.estado)
        VStack(spacing: 16) {
            NivelTarjeta(nivel: NivelDeFichas(fichas: store.proyecto.visitasPrevias + store.hechos))
            LogrosTarjeta(logros: logros) { viendoTodos = true }
        }
        .navigationDestination(isPresented: $viendoTodos) {
            ListaDeLogros()
        }
        #if DEBUG
        .background {
            if Depuracion.foco == "logros" { BajarHastaAqui() }
        }
        .task {
            guard !depuracionHecha else { return }
            depuracionHecha = true
            if Depuracion.abrir == "logros" { viendoTodos = true }
        }
        #endif
    }
}

/// El nivel y la mano de 7 fichas que se está armando. Si subió desde la última vez, la mano se completa
/// y entra la nueva; con «Reducir movimiento», solo aparece el aviso.
private struct NivelTarjeta: View {
    let nivel: NivelDeFichas

    @AppStorage("logrosFichasVistas") private var fichasVistas = 0
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    /// Lo que se dibuja mientras corre la animación. Sin valor, el nivel actual.
    @State private var mostrado: Mostrado?
    @State private var subio = false

    private struct Mostrado: Equatable {
        var numero: Int
        var enMano: Int
    }

    var body: some View {
        let actual = mostrado ?? Mostrado(numero: nivel.numero, enMano: nivel.enMano)
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Tu nivel", systemImage: "stairs")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    if subio {
                        Label("Nivel nuevo", systemImage: "arrow.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12), in: .capsule)
                            .transition(reducirMovimiento ? .opacity : .scale.combined(with: .opacity))
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) { titulo(actual.numero) }
                    VStack(alignment: .leading, spacing: 2) { titulo(actual.numero) }
                }

                ManoDeFichas(llenas: actual.enMano)
                    .id(actual.numero)
                    .transition(reducirMovimiento ? .opacity : .push(from: .trailing))

                Text("Con \(Text(cuantas).fontWeight(.semibold)) más llegas al nivel \(nivel.numero + 1): \(NivelDeFichas.nombre(nivel.numero + 1)).")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Cada \(NivelDeFichas.fichasPorMano) fichas en pie, una mano de dominó, subes un nivel. Una falta no bota fichas, así que el nivel no baja.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nivel \(nivel.numero), \(nivel.nombre)")
        .accessibilityValue("\(nivel.enMano) de \(NivelDeFichas.fichasPorMano) fichas en esta mano. Con \(cuantas) más llegas al nivel \(nivel.numero + 1).")
        .onAppear(perform: mostrarAvance)
        .onChange(of: nivel.fichas) { mostrarAvance() }
        .onDisappear {
            mostrado = nil
            subio = false
        }
    }

    private var cuantas: String {
        nivel.faltan == 1 ? "1 ficha" : "\(nivel.faltan) fichas"
    }

    @ViewBuilder
    private func titulo(_ numero: Int) -> some View {
        Text("Nivel \(numero)")
            .font(.largeTitle.weight(.bold))
            .fontDesign(.rounded)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(numero)))
        Text(NivelDeFichas.nombre(numero))
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    /// Si hay fichas nuevas desde la última vez, las muestra entrar. La primera vez solo toma nota.
    private func mostrarAvance() {
        let antes = NivelDeFichas(fichas: fichasVistas)
        let ahora = nivel
        defer { fichasVistas = ahora.fichas }
        guard fichasVistas > 0, ahora.fichas > fichasVistas else {
            mostrado = nil
            return
        }
        let subeDeNivel = ahora.numero > antes.numero
        if reducirMovimiento {
            mostrado = nil
            withAnimation(.easeInOut(duration: 0.2)) { subio = subio || subeDeNivel }
            if subeDeNivel { anunciar(ahora) }
            return
        }
        mostrado = Mostrado(numero: antes.numero, enMano: antes.enMano)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if subeDeNivel {
                // Se completa la mano y entra la del nivel nuevo.
                withAnimation(.spring(duration: 0.45)) {
                    mostrado = Mostrado(numero: antes.numero, enMano: NivelDeFichas.fichasPorMano)
                }
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(.spring(duration: 0.55, bounce: 0.25)) {
                    mostrado = nil
                    subio = true
                }
                anunciar(ahora)
            } else {
                withAnimation(.spring(duration: 0.45)) { mostrado = nil }
            }
        }
    }

    private func anunciar(_ nivel: NivelDeFichas) {
        AccessibilityNotification.Announcement("Subiste al nivel \(nivel.numero): \(nivel.nombre)").post()
    }
}

/// Siete fichas en pie, una mano de dominó. Las de esta mano van en naranja.
private struct ManoDeFichas: View {
    let llenas: Int
    @ScaledMetric(relativeTo: .body) private var alto: CGFloat = 38

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<NivelDeFichas.fichasPorMano, id: \.self) { i in
                ficha(llena: i < llenas)
            }
        }
        .frame(height: min(alto, 56))
        .accessibilityHidden(true)
    }

    private func ficha(llena: Bool) -> some View {
        let forma = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return ZStack {
            if llena {
                forma.fill(Color.accentColor.gradient)
                VStack(spacing: 0) {
                    Circle().fill(.white.opacity(0.9)).frame(width: 4, height: 4).frame(maxHeight: .infinity)
                    Rectangle().fill(.white.opacity(0.45)).frame(height: 1).padding(.horizontal, 5)
                    Circle().fill(.white.opacity(0.9)).frame(width: 4, height: 4).frame(maxHeight: .infinity)
                }
            } else {
                forma.fill(Color.primary.opacity(0.06))
            }
        }
        .frame(maxWidth: 40)
        .frame(maxWidth: .infinity)
    }
}

/// Las medallas, como los premios de Fitness: logradas con color, por lograr atenuadas.
/// Las nuevas desde la última visita dan un salto (sin él con «Reducir movimiento»).
private struct LogrosTarjeta: View {
    let logros: [Logro]
    var alVerTodos: () -> Void

    @AppStorage("logrosVistos") private var vistos = ""
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @Environment(\.dynamicTypeSize) private var tamanoTexto
    @ScaledMetric(relativeTo: .body) private var diametro: CGFloat = 54
    @State private var nuevos: Set<Logro.Clave> = []
    @State private var salto = 0
    @State private var elegido: Logro.Clave?

    private var conseguidos: Int { logros.filter(\.conseguido).count }

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Logros", systemImage: "rosette")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text("\(conseguidos) de \(logros.count)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: Double(conseguidos)))
                }

                if !tamanoTexto.isAccessibilitySize {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: min(diametro, 72) + 22), spacing: 8, alignment: .top)], spacing: 16) {
                        ForEach(logros) { logro in
                            medalla(logro)
                        }
                    }
                }

                if let siguiente = Logros.siguiente(logros) {
                    Divider()
                    HStack(alignment: .top, spacing: 12) {
                        MedallaLogro(logro: siguiente, diametro: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lo siguiente: \(siguiente.titulo)")
                                .font(.subheadline.weight(.semibold))
                            Text(siguiente.detalle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                Divider()
                Button(action: alVerTodos) {
                    HStack {
                        Label("Ver todos los logros", systemImage: "list.bullet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear(perform: notarNuevos)
        .onChange(of: logros.filter(\.conseguido).map(\.id)) { notarNuevos() }
        .onDisappear { nuevos = [] }
        #if DEBUG
        // `-logro <clave>` abre el detalle de esa medalla, para las capturas.
        .task {
            elegido = UserDefaults.standard.string(forKey: "logro").flatMap(Logro.Clave.init(rawValue:))
        }
        #endif
    }

    private func medalla(_ logro: Logro) -> some View {
        let esNuevo = nuevos.contains(logro.id)
        return Button {
            elegido = logro.id
        } label: {
            VStack(spacing: 6) {
                MedallaLogro(logro: logro, diametro: min(diametro, 72))
                    .symbolEffect(.bounce, options: .nonRepeating, value: esNuevo ? salto : 0)
                Text(logro.titulo)
                    .font(.caption2.weight(logro.conseguido ? .semibold : .regular))
                    .foregroundStyle(logro.conseguido ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if esNuevo {
                    Text("Nuevo")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(get: { elegido == logro.id }, set: { if !$0 { elegido = nil } })) {
            DetalleLogro(logro: logro)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel(logro.titulo)
        .accessibilityValue(logro.conseguido ? (esNuevo ? "Logrado, nuevo" : "Logrado") : "Por lograr")
        .accessibilityHint(logro.detalle)
    }

    /// Compara con lo que ya vio: lo nuevo salta una vez. Si el plan partió de nuevo, solo actualiza.
    private func notarNuevos() {
        let ahora = Set(logros.filter(\.conseguido).map(\.id))
        let antes = Set(vistos.split(separator: ",").compactMap { Logro.Clave(rawValue: String($0)) })
        vistos = ahora.map(\.rawValue).sorted().joined(separator: ",")
        guard !antes.isEmpty else { return }
        let recientes = ahora.subtracting(antes)
        guard !recientes.isEmpty else { return }
        nuevos.formUnion(recientes)
        let titulos = logros.filter { recientes.contains($0.id) }.map(\.titulo)
        AccessibilityNotification.Announcement(
            titulos.count == 1 ? "Nuevo logro: \(titulos[0])" : "Nuevos logros: \(titulos.joined(separator: ", "))"
        ).post()
        guard !reducirMovimiento else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            salto += 1
        }
    }
}

private struct MedallaLogro: View {
    let logro: Logro
    let diametro: CGFloat

    var body: some View {
        ZStack {
            if logro.conseguido {
                Circle().fill(Color.accentColor.gradient)
            } else {
                Circle().fill(Color.primary.opacity(0.06))
                Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            Image(systemName: logro.simbolo)
                .font(.system(size: diametro * 0.38, weight: .semibold))
                .foregroundStyle(logro.conseguido ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
        }
        .frame(width: diametro, height: diametro)
        .accessibilityHidden(true)
    }
}

private struct DetalleLogro: View {
    let logro: Logro

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(logro.conseguido ? "Logrado" : "Por lograr")
                .font(.caption.weight(.semibold))
                .foregroundStyle(logro.conseguido ? Color.accentColor : .secondary)
            Text(logro.titulo)
                .font(.headline)
            Text(logro.detalle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }
}

/// Todos los logros con su detalle: lo logrado arriba y, abajo, cómo se consigue lo que viene.
private struct ListaDeLogros: View {
    @Environment(ObraStore.self) private var store

    var body: some View {
        let logros = Logros.calcular(store.estado)
        let logrados = logros.filter(\.conseguido)
        let porLograr = logros.filter { !$0.conseguido }
        List {
            Section {
                ForEach(logrados) { fila($0) }
            } header: {
                Text("Logrados").textCase(nil)
            }
            if !porLograr.isEmpty {
                Section {
                    ForEach(porLograr) { fila($0) }
                } header: {
                    Text("Por lograr").textCase(nil)
                } footer: {
                    Text("Los logros no vencen ni se comparan con los de nadie más.")
                }
            }
        }
        .navigationTitle("Logros")
        .navigationBarTitleDisplayMode(.large)
    }

    private func fila(_ logro: Logro) -> some View {
        HStack(alignment: .top, spacing: 14) {
            MedallaLogro(logro: logro, diametro: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(logro.titulo)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(logro.conseguido ? .primary : .secondary)
                Text(logro.detalle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(logro.conseguido ? "Logrado" : "Por lograr")
    }
}

#if DEBUG
/// `-foco logros` baja «Tu avance» hasta esta sección, para las capturas. Solo en Debug.
private struct BajarHastaAqui: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let vista = UIView()
        vista.isUserInteractionEnabled = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            var padre = vista.superview
            while let actual = padre, !(actual is UIScrollView) { padre = actual.superview }
            guard let scroll = padre as? UIScrollView else { return }
            let marco = vista.convert(vista.bounds, to: scroll)
            let maximo = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            let y = min(maximo, marco.minY - scroll.adjustedContentInset.top - 12)
            scroll.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }
        return vista
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
