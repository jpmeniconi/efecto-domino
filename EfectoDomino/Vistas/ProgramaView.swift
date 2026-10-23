import SwiftUI

// MARK: - Pantalla

/// Programa completo: la carta Gantt de todo el plan, de la semana 1 a la meta estimada.
/// Con más zoom aparece más detalle; con menos, solo las pastillas.
struct ProgramaView: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var elegido: BloqueElegido?
    @State private var despuesDelDetalle: AccionDelDetalle?
    @State private var ajustando: Bloque?
    @State private var registrando: Bloque?
    @State private var propuestaPendiente: Propuesta?
    @State private var registroPendiente: RegistroPendiente?
    @State private var foco: FocoPrograma?
    @State private var viendoLeyenda = false
    @State private var detente: PresentationDetent = .medium

    private struct BloqueElegido: Identifiable {
        let id: UUID
    }

    private enum AccionDelDetalle {
        case registrar(Bloque)
        case ajustar(Bloque)
    }

    private struct RegistroPendiente {
        let id: UUID
        let registro: Registro
        let prepararSiguiente: [String]
    }

    var body: some View {
        NavigationStack {
            // La carta es densa: su texto crece hasta XXXL. El detalle de cada bloque crece sin tope.
            CartaPrograma(foco: foco) { elegido = BloqueElegido(id: $0) }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .background(Color(.systemBackground))
                .navigationTitle("Programa completo")
                .navigationBarTitleDisplayMode(.inline)
                .navigationSubtitle(subtitulo)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cerrar", systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Leyenda", systemImage: "info.circle") { viendoLeyenda = true }
                            .popover(isPresented: $viendoLeyenda) {
                                LeyendaPrograma()
                                    .padding(20)
                                    .presentationCompactAdaptation(.popover)
                            }
                    }
                }
                .sheet(item: $elegido, onDismiss: seguirDespuesDelDetalle) { elegido in
                    DetalleBloqueSheet(
                        id: elegido.id,
                        alRegistrar: { despuesDelDetalle = .registrar($0) },
                        alAjustar: { despuesDelDetalle = .ajustar($0) }
                    )
                    .presentationDetents([.medium, .large], selection: $detente)
                }
                .sheet(item: $ajustando, onDismiss: aplicarPropuesta) { bloque in
                    AjustarSheet(bloque: bloque) { propuestaPendiente = $0 }
                }
                .sheet(item: $registrando, onDismiss: aplicarRegistro) { bloque in
                    RegistroSheet(bloque: bloque) { registro, preparar in
                        registroPendiente = RegistroPendiente(id: bloque.id, registro: registro, prepararSiguiente: preparar)
                    }
                }
                .overlay(alignment: .bottom) { AvisoFlotante() }
                .animation(.spring(duration: 0.4), value: store.aviso)
                #if DEBUG
                .task { await abrirDesdeDepuracion() }
                #endif
        }
        // Juntar los dedos aleja la carta: no debe cerrar la pantalla. Se cierra con la X.
        .interactiveDismissDisabled()
    }

    private var subtitulo: String {
        let semana = max(0, store.estado.inicioObra.dias(hasta: store.ahora) / 7) + 1
        let meta = store.recepcion.map { "Meta estimada \(Formato.fechaConDia($0))" } ?? "Sin bloques por delante"
        return "Semana \(semana) de \(store.proyecto.semanas) · \(meta)"
    }

    /// Fui y Ajustar se abren al cerrar el detalle, para no apilar hojas.
    private func seguirDespuesDelDetalle() {
        detente = .medium
        guard let accion = despuesDelDetalle else { return }
        despuesDelDetalle = nil
        switch accion {
        case let .registrar(bloque): registrando = bloque
        case let .ajustar(bloque): ajustando = bloque
        }
    }

    /// Se aplica después de cerrar el panel, para que Camila vea moverse el programa.
    private func aplicarPropuesta() {
        guard let propuesta = propuestaPendiente else { return }
        propuestaPendiente = nil
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            store.aplicar(propuesta)
            if let id = propuesta.accion.bloque { foco = FocoPrograma(bloque: id) }
        }
    }

    private func aplicarRegistro() {
        guard let pendiente = registroPendiente else { return }
        registroPendiente = nil
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            store.registrar(pendiente.id, registro: pendiente.registro, prepararSiguiente: pendiente.prepararSiguiente)
        }
    }

    #if DEBUG
    private func abrirDesdeDepuracion() async {
        guard let fila = DepuracionPrograma.detalle else { return }
        let ordenados = store.estado.bloques.sorted { $0.inicio < $1.inicio }
        guard ordenados.indices.contains(fila) else { return }
        try? await Task.sleep(for: .seconds(1))
        if DepuracionPrograma.detenteGrande { detente = .large }
        elegido = BloqueElegido(id: ordenados[fila].id)
        guard let accion = DepuracionPrograma.accion else { return }
        try? await Task.sleep(for: .seconds(1.5))
        despuesDelDetalle = accion == "ajustar" ? .ajustar(ordenados[fila]) : .registrar(ordenados[fila])
        elegido = nil
    }
    #endif
}

/// Pide a la carta que muestre un bloque, por ejemplo después de moverlo.
struct FocoPrograma: Equatable {
    var bloque: UUID
    var vez = UUID()
}

// MARK: - Zoom

/// Cuántos días caben en la pantalla. Los presets son los del control segmentado.
enum ZoomPrograma: Equatable {
    enum Preset: String, CaseIterable, Identifiable {
        case semana, dosSemanas, todo

        var id: String { rawValue }

        var nombre: String {
            switch self {
            case .semana: "Semana"
            case .dosSemanas: "2 semanas"
            case .todo: "Todo"
            }
        }

        func dias(total: Int) -> Double {
            switch self {
            case .semana: 7
            case .dosSemanas: 14
            case .todo: Double(total)
            }
        }

        /// El preset al que se acerca un pellizco, para soltarlo justo ahí.
        static func cercano(a dias: Double, total: Int) -> Preset? {
            allCases.first { abs(log(dias / $0.dias(total: total))) < 0.1 }
        }
    }

    case preset(Preset)
    case libre(Double)

    func dias(total: Int) -> Double {
        switch self {
        case let .preset(preset): preset.dias(total: total)
        case let .libre(dias): dias
        }
    }

    var preset: Preset? {
        switch self {
        case let .preset(preset): preset
        case .libre: nil
        }
    }
}

/// Qué se dibuja según el ancho de cada día.
enum NivelDeDetalle: Int, Comparable {
    case pastillas, iconos, horas, completo

    static func < (a: NivelDeDetalle, b: NivelDeDetalle) -> Bool { a.rawValue < b.rawValue }
}

// MARK: - Carta

/// La carta Gantt de todo el plan. Todos los días tienen el mismo ancho y el zoom lo cambia;
/// el alto de las filas acompaña para que en Todo quepa el plan entero.
/// El encabezado queda fijo arriba; las filas se desplazan en vertical y todo junto en horizontal.
struct CartaPrograma: View {
    @Environment(ObraStore.self) private var store
    var foco: FocoPrograma?
    var alTocar: (UUID) -> Void

    @ScaledMetric(relativeTo: .caption) private var altoFila: CGFloat = 32
    @ScaledMetric(relativeTo: .caption2) private var altoSemanas: CGFloat = 26
    @ScaledMetric(relativeTo: .caption2) private var altoDias: CGFloat = 40
    @ScaledMetric(relativeTo: .caption2) private var altoPega: CGFloat = 26
    @ScaledMetric(relativeTo: .caption2) private var circuloHoy: CGFloat = 24
    @ScaledMetric(relativeTo: .caption2) private var umbralIconos: CGFloat = 15
    @ScaledMetric(relativeTo: .caption2) private var umbralHoras: CGFloat = 44
    @ScaledMetric(relativeTo: .caption2) private var umbralCompleto: CGFloat = 100

    @State private var zoom: ZoomPrograma = .preset(.dosSemanas)
    @State private var posicionH = ScrollPosition()
    @State private var posicionV = ScrollPosition()
    @State private var desplazamientoX: CGFloat = 0
    @State private var desplazamientoY: CGFloat = 0
    @State private var pellizco: Pellizco?
    @State private var centrada = false

    private let margen: CGFloat = 16
    private let diasMinimos = 2.5
    /// Ancho de un día en «2 semanas» en un iPhone grande: ahí las filas miden su alto base.
    private let anchoReferencia: CGFloat = 29
    private static let abreviaturas = ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]

    private struct Pellizco {
        let dias: Double
        let dedos: CGPoint
        let diaAncla: Double
        /// La fila de la escalera de ese día y dónde se ve: así sus bloques no se van de la pantalla.
        let filaAncla: Int
        let yFilaAncla: CGFloat
    }

    private var altoEncabezado: CGFloat { altoSemanas + altoDias + altoPega }

    var body: some View {
        let plan = PlanPrograma(store.estado)
        GeometryReader { geo in
            let m = medidas(plan, geo.size, zoom)
            carta(plan, m)
                .toolbar { controles(plan, m) }
                .onChange(of: geo.size.width, initial: true) { _, ancho in
                    if ancho > 0 { abrir(plan, geo.size) }
                }
                .onChange(of: foco) { _, nuevo in
                    if let nuevo { mostrar(nuevo.bloque, m) }
                }
        }
        .sensoryFeedback(.selection, trigger: zoom.preset) { _, nuevo in nuevo != nil }
    }

    // MARK: Medidas

    private func medidas(_ plan: PlanPrograma, _ tamano: CGSize, _ zoom: ZoomPrograma) -> MedidasPrograma {
        let util = max(tamano.width - margen * 2, 100)
        let dias = min(max(zoom.dias(total: plan.dias), diasMinimos), Double(plan.dias))
        let anchoDia = util / CGFloat(dias)
        let nivel: NivelDeDetalle = anchoDia >= umbralCompleto ? .completo
            : anchoDia >= umbralHoras ? .horas
            : anchoDia >= umbralIconos ? .iconos
            : .pastillas
        let factor = min(max(pow(Double(anchoDia / anchoReferencia), 0.5), 0.72), 1.7)
        return MedidasPrograma(
            dias: plan.dias,
            filas: plan.filas.count + (plan.diaMeta == nil ? 0 : 1),
            anchoVisible: tamano.width,
            altoVisible: max(0, tamano.height - altoEncabezado),
            anchoDia: anchoDia,
            altoFila: altoFila * CGFloat(factor),
            margen: margen,
            nivel: nivel
        )
    }

    // MARK: Estructura

    private func carta(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some View {
        ScrollView(.horizontal) {
            ZStack(alignment: .topLeading) {
                columnas(plan, m)
                // Detrás de las pastillas, para no tapar su texto.
                if m.nivel >= .iconos, plan.diaHoy >= 0, plan.diaHoy < Double(m.dias) {
                    lineaHoy(plan, m)
                }
                VStack(spacing: 0) {
                    encabezado(plan, m)
                    ScrollView(.vertical) {
                        filas(plan, m)
                    }
                    .scrollPosition($posicionV)
                    .scrollIndicators(.hidden)
                    .scrollDisabled(pellizco != nil)
                    .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, y in
                        desplazamientoY = y
                    }
                }
            }
            .frame(width: m.anchoContenido)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .scrollPosition($posicionH)
        .scrollIndicators(.hidden)
        .scrollDisabled(pellizco != nil)
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.x }) { _, x in
            desplazamientoX = x
        }
        .onScrollPhaseChange { anterior, nueva in
            if nueva == .idle, anterior == .decelerating || anterior == .interacting {
                seguirEscalera(plan, m)
            }
        }
        .simultaneousGesture(pellizcar(plan, m))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Programa completo")
        .accessibilityZoomAction { accion in
            let orden = ZoomPrograma.Preset.allCases
            guard let i = orden.firstIndex(of: zoom.preset ?? .dosSemanas) else { return }
            let j = accion.direction == .zoomIn ? max(0, i - 1) : min(orden.count - 1, i + 1)
            cambiarZoom(a: orden[j], plan, m)
        }
    }

    // MARK: Fondo

    /// Fines de semana y separadores de semana. No se desplazan en vertical: son franjas.
    private func columnas(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some View {
        ZStack(alignment: .topLeading) {
            if m.nivel == .pastillas, plan.semanaHoy >= 0, plan.semanaHoy < m.semanas {
                Color.accentColor.opacity(0.06)
                    .frame(width: m.anchoDia * 7)
                    .offset(x: m.x(dia: plan.semanaHoy * 7))
            }
            ForEach(0..<m.semanas, id: \.self) { semana in
                Color.primary.opacity(0.035)
                    .frame(width: m.anchoDia * 2)
                    .padding(.top, altoSemanas + altoDias)
                    .offset(x: m.x(dia: semana * 7 + 5))
                if semana > 0 {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1)
                        .padding(.top, 6)
                        .offset(x: m.x(dia: semana * 7) - 0.5)
                }
            }
        }
        .frame(width: m.anchoContenido, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func lineaHoy(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 1.5)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
                .offset(y: -3)
        }
        .frame(width: 7)
        .padding(.top, altoSemanas + altoDias + 3)
        .offset(x: m.x(dia: plan.diaHoy) - 3.5)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.smooth(duration: 0.5), value: plan.diaHoy)
    }

    // MARK: Encabezado

    private func encabezado(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some View {
        ZStack(alignment: .topLeading) {
            etiquetasDeSemana(plan, m)
            etiquetasDeDia(plan, m)
                .offset(y: altoSemanas)
            filaPega(plan, m)
                .offset(y: altoSemanas + altoDias)
        }
        .frame(width: m.anchoContenido, height: altoEncabezado, alignment: .topLeading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        }
    }

    private func etiquetasDeSemana(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<m.semanas, id: \.self) { semana in
                let actual = semana == plan.semanaHoy
                let anchoSemana = m.anchoDia * 7
                ViewThatFits(in: .horizontal) {
                    Text("Semana \(semana + 1) · \(plan.rango(semana: semana))")
                    Text("Semana \(semana + 1)")
                    Text("S\(semana + 1)")
                }
                .font(.caption.weight(actual ? .bold : .semibold))
                .foregroundStyle(actual ? Color.accentColor : Color.secondary)
                .lineLimit(1)
                // Mientras se ve algo de la semana, su nombre queda pegado al borde izquierdo.
                .visualEffect { contenido, geometria in
                    let marco = geometria.frame(in: .scrollView(axis: .horizontal))
                    return contenido.offset(x: min(max(0, 6 - marco.minX), max(0, anchoSemana - marco.width - 12)))
                }
                .padding(.horizontal, 6)
                .frame(width: anchoSemana, height: altoSemanas, alignment: .leading)
                .offset(x: m.x(dia: semana * 7))
                .accessibilityAddTraits(.isHeader)
            }
        }
    }

    @ViewBuilder
    private func etiquetasDeDia(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some View {
        if m.nivel == .pastillas {
            // A esta escala no caben los días: solo la fecha del lunes.
            ZStack(alignment: .topLeading) {
                ForEach(0..<m.semanas, id: \.self) { semana in
                    ViewThatFits(in: .horizontal) {
                        Text(plan.fechaCorta(dia: semana * 7))
                        Text("\(plan.numeros[semana * 7])")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .frame(width: m.anchoDia * 7, height: altoDias / 2, alignment: .leading)
                    .offset(x: m.x(dia: semana * 7))
                }
            }
            .accessibilityHidden(true)
        } else {
            let hoy = plan.diaHoy >= 0 ? Int(plan.diaHoy) : -1
            let circulo = min(circuloHoy, m.anchoDia - 2)
            ZStack(alignment: .topLeading) {
                ForEach(0..<m.dias, id: \.self) { dia in
                    let esHoy = dia == hoy
                    VStack(spacing: 3) {
                        Text(m.nivel >= .horas ? Self.abreviaturas[dia % 7] : Formato.iniciales[dia % 7])
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(plan.numeros[dia])")
                            .font(.footnote.weight(esHoy ? .bold : .medium))
                            .monospacedDigit()
                            .foregroundStyle(esHoy ? Color.white : Color.primary)
                            .frame(width: circulo, height: circulo)
                            .background {
                                if esHoy { Circle().fill(Color.accentColor) }
                            }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: m.anchoDia, height: altoDias)
                    .offset(x: m.x(dia: dia))
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func filaPega(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some View {
        let alto: CGFloat = m.nivel == .pastillas ? 6 : altoPega - 8
        let ancho = max(m.anchoDia - min(6, m.anchoDia * 0.25), 3)
        return ZStack(alignment: .topLeading) {
            ForEach(plan.pega) { item in
                CapsulaPega(evento: item.evento, nivel: m.nivel)
                    .frame(width: ancho, height: alto)
                    .offset(x: m.x(dia: item.dia) + (m.anchoDia - ancho) / 2, y: (altoPega - alto) / 2)
            }
        }
    }

    // MARK: Filas

    private func filas(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some View {
        ZStack(alignment: .topLeading) {
            if m.nivel >= .iconos {
                bandasDeHolgura(plan, m)
            }
            ForEach(plan.filas) { fila in
                filaBloque(fila, anterior: fila.indice > 0 ? plan.filas[fila.indice - 1] : nil, plan, m)
            }
            if let diaMeta = plan.diaMeta, let meta = plan.meta {
                hito(plan, dia: diaMeta, meta: meta, m)
            }
        }
        .frame(width: m.anchoContenido, height: m.altoContenido, alignment: .topLeading)
    }

    /// La meta estimada cierra la escalera como un hito. Si el plan se corrió, su fantasma queda donde estaba.
    private func hito(_ plan: PlanPrograma, dia: Int, meta: Date, _ m: MedidasPrograma) -> some View {
        let lado = min(m.altoPastilla * 0.55, 13)
        let centro = CGPoint(x: m.x(dia: dia + 1), y: m.y(fila: plan.filas.count) + m.altoFila / 2)
        let xOriginal = plan.diaMetaOriginal.map { m.x(dia: $0 + 1) }
        let xEtiqueta = min(centro.x, xOriginal ?? centro.x) - lado - 4
        let corrida = plan.corrimiento > 0 ? " · se corrió \(Formato.dias(plan.corrimiento))" : ""
        let rombo = RoundedRectangle(cornerRadius: 2, style: .continuous).rotation(.degrees(45))

        return ZStack(alignment: .topLeading) {
            if let ultima = plan.filas.last {
                let xFin = m.x(dia: ultima.dia) + (m.anchoDia + m.anchoPastilla(ultima.bloque)) / 2
                Conector(x0: xFin, x1: centro.x - lado / 2, alto: m.altoFila)
                    .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    .frame(height: m.altoFila)
                    .offset(y: centro.y - m.altoFila)
            }
            if let xOriginal {
                rombo
                    .stroke(Color.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: lado, height: lado)
                    .offset(x: xOriginal - lado / 2, y: centro.y - lado / 2)
                Arco(desde: xOriginal, hasta: centro.x - lado / 2)
                    .stroke(Color.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 2]))
                    .frame(height: lado)
                    .offset(y: centro.y - lado)
            }
            rombo
                .fill(Color.accentColor)
                .frame(width: lado, height: lado)
                .offset(x: centro.x - lado / 2, y: centro.y - lado / 2)
            Text("Meta estimada · \(Formato.fechaConDia(meta))\(corrida)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 320, height: m.altoFila, alignment: .trailing)
                .offset(x: xEtiqueta - 320, y: centro.y - m.altoFila / 2)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Meta estimada: \(Formato.fechaLarga(meta))\(corrida)")
        .animation(.spring(duration: 0.6, bounce: 0.25).delay(Double(max(0, plan.filas.count - plan.filaDeHoy)) * 0.04), value: dia)
    }

    /// La holgura se raya en los días libres de cada semana, a la altura de sus bloques.
    private func bandasDeHolgura(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(plan.holguras) { holgura in
                let y = m.y(fila: holgura.filaDesde) + 2
                let alto = CGFloat(holgura.filaHasta - holgura.filaDesde + 1) * m.altoFila - 4
                let forma = RoundedRectangle(cornerRadius: 6, style: .continuous)
                forma
                    .fill(Color.accentColor.opacity(0.04))
                    .overlay {
                        Rayado(separacion: 6)
                            .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
                    }
                    .clipShape(forma)
                    .frame(width: m.anchoDia - 2, height: alto)
                    .offset(x: m.x(dia: holgura.dia) + 1, y: y)
                if m.nivel == .completo {
                    VStack(spacing: 1) {
                        Text("Holgura")
                            .font(.caption2.weight(.semibold))
                        Text("\(Formato.hora(holgura.slot.fecha)) · \(holgura.slot.tipo.nombre)")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.systemBackground).opacity(0.9), in: .rect(cornerRadius: 6))
                    .frame(width: m.anchoDia - 2, height: alto)
                    .offset(x: m.x(dia: holgura.dia) + 1, y: y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func filaBloque(_ fila: FilaPrograma, anterior: FilaPrograma?, _ plan: PlanPrograma, _ m: MedidasPrograma) -> some View {
        let bloque = fila.bloque
        let altoP = m.altoPastilla
        let anchoP = m.anchoPastilla(bloque)
        let xP = m.x(dia: fila.dia) + (m.anchoDia - anchoP) / 2
        let yP = m.y(fila: fila.indice) + (m.altoFila - altoP) / 2
        let anchoToque = max(anchoP, 28)
        // Cascada: los bloques se corren uno tras otro, como fichas de dominó.
        let retraso = Double(max(0, fila.indice - plan.filaDeHoy)) * 0.04
        let animacion = Animation.spring(duration: 0.6, bounce: 0.25).delay(retraso)

        return ZStack(alignment: .topLeading) {
            if let anterior {
                let anchoA = m.anchoPastilla(anterior.bloque)
                let xFinAnterior = m.x(dia: anterior.dia) + (m.anchoDia + anchoA) / 2
                Conector(x0: xFinAnterior, x1: xP, alto: m.altoFila)
                    .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    .frame(height: m.altoFila)
                    .offset(y: yP - m.altoFila + altoP / 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            if let diaOrigen = fila.diaOrigen, let origen = bloque.origen {
                let anchoBase = m.anchoBase
                let xOrigen = m.x(dia: diaOrigen) + (m.anchoDia - anchoBase) / 2
                Capsule()
                    .strokeBorder(Color.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .overlay {
                        if m.nivel >= .horas {
                            Text(Formato.hora(origen))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(width: anchoBase, height: altoP)
                    .offset(x: xOrigen, y: yP)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Arco(desde: xOrigen + anchoBase / 2, hasta: fila.dia >= diaOrigen ? xP : xP + anchoP)
                    .stroke(Color.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 2]))
                    .frame(height: altoP)
                    .offset(y: yP - altoP / 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            Button {
                alTocar(bloque.id)
            } label: {
                PastillaPrograma(bloque: bloque, nivel: m.nivel)
                    .frame(width: anchoP, height: altoP)
                    .frame(width: anchoToque, height: m.altoFila)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .offset(x: xP - (anchoToque - anchoP) / 2, y: m.y(fila: fila.indice))
            .accessibilityLabel(PastillaPrograma.descripcion(bloque, ahora: store.ahora))
            .accessibilityHint("Abre el detalle del bloque")
            // La hora va al lado cuando no cabe dentro (el bloque puente es más corto).
            if m.nivel == .iconos || (m.nivel == .horas && bloque.esPuente) {
                Text(Formato.hora(bloque.inicio))
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .frame(height: altoP)
                    .offset(x: xP + anchoP + 3, y: yP)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(animacion, value: bloque.inicio)
        .animation(animacion, value: fila.indice)
    }

    // MARK: Controles

    @ToolbarContentBuilder
    private func controles(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button("Hoy") { centrarEnHoy(plan, m, animado: true) }
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Picker("Zoom", selection: Binding(
                get: { zoom.preset },
                set: { nuevo in if let nuevo { cambiarZoom(a: nuevo, plan, m) } }
            )) {
                ForEach(ZoomPrograma.Preset.allCases) { preset in
                    Text(preset.nombre).tag(Optional(preset))
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }

    // MARK: Desplazamiento y zoom

    private func abrir(_ plan: PlanPrograma, _ tamano: CGSize) {
        guard !centrada else { return }
        centrada = true
        #if DEBUG
        if let texto = DepuracionPrograma.zoom { zoom = ZoomPrograma(depuracion: texto) ?? zoom }
        if let preset = DepuracionPrograma.luego.flatMap(ZoomPrograma.init(depuracion:))?.preset {
            Task {
                // Como si Camila tocara el control segmentado.
                try? await Task.sleep(for: .seconds(2))
                let actual = PlanPrograma(store.estado)
                cambiarZoom(a: preset, actual, medidas(actual, tamano, zoom))
            }
        }
        #endif
        centrarEnHoy(plan, medidas(plan, tamano, zoom), animado: false)
    }

    /// Hoy al centro, y las filas de esta semana a la vista.
    private func centrarEnHoy(_ plan: PlanPrograma, _ m: MedidasPrograma, animado: Bool) {
        let x = m.limitarX(m.x(dia: plan.diaHoy) - m.anchoVisible / 2)
        let y = m.limitarY(m.y(fila: plan.filaDeHoy) - m.altoFila)
        withAnimation(animado ? .smooth(duration: 0.4) : nil) {
            posicionH.scrollTo(x: x)
            posicionV.scrollTo(y: y)
        }
    }

    /// Semana y 2 semanas parten en el lunes de hoy (o del centro, si hoy no se ve). Todo muestra el plan entero.
    private func cambiarZoom(a preset: ZoomPrograma.Preset, _ plan: PlanPrograma, _ m: MedidasPrograma) {
        let xHoy = m.x(dia: plan.diaHoy)
        let hoyVisible = xHoy >= desplazamientoX && xHoy <= desplazamientoX + m.anchoVisible
        let diaAncla = hoyVisible ? plan.diaHoy : Double((desplazamientoX + m.anchoVisible / 2 - margen) / m.anchoDia)
        let semana = min(max(0, Int(diaAncla) / 7), m.semanas - 1)
        let nueva = medidas(plan, m.tamano(encabezado: altoEncabezado), .preset(preset))
        let fila = plan.filas.first { $0.dia / 7 == semana }?.indice ?? 0
        withAnimation(.smooth(duration: 0.35)) {
            zoom = .preset(preset)
            posicionH.scrollTo(x: preset == .todo ? 0 : nueva.limitarX(nueva.x(dia: semana * 7) - margen))
            posicionV.scrollTo(y: preset == .todo ? 0 : nueva.limitarY(nueva.y(fila: fila) - nueva.altoFila))
        }
    }

    /// Pellizco: cambia el ancho de cada día y deja quieto lo que está bajo los dedos.
    private func pellizcar(_ plan: PlanPrograma, _ m: MedidasPrograma) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { valor in
                let inicial = pellizco ?? {
                    let dia = Double((desplazamientoX + valor.startLocation.x - margen) / m.anchoDia)
                    let fila = plan.fila(paraDia: dia)
                    // Si la fila no se veía, queda en el primer cuarto de la pantalla.
                    let y = m.y(fila: fila) - desplazamientoY
                    let visible = y >= 0 && y + m.altoFila <= m.altoVisible
                    return Pellizco(
                        dias: zoom.dias(total: plan.dias),
                        dedos: valor.startLocation,
                        diaAncla: dia,
                        filaAncla: fila,
                        yFilaAncla: visible ? y : m.altoVisible / 4
                    )
                }()
                pellizco = inicial
                let dias = min(max(inicial.dias / Double(valor.magnification), diasMinimos), Double(plan.dias))
                aplicarZoom(.libre(dias), ancla: inicial, plan, m)
            }
            .onEnded { _ in
                if let inicial = pellizco, case let .libre(dias) = zoom,
                   let preset = ZoomPrograma.Preset.cercano(a: dias, total: plan.dias) {
                    withAnimation(.snappy(duration: 0.25)) {
                        aplicarZoom(.preset(preset), ancla: inicial, plan, m)
                    }
                }
                pellizco = nil
            }
    }

    private func aplicarZoom(_ nuevo: ZoomPrograma, ancla: Pellizco, _ plan: PlanPrograma, _ m: MedidasPrograma) {
        let nueva = medidas(plan, m.tamano(encabezado: altoEncabezado), nuevo)
        zoom = nuevo
        posicionH.scrollTo(x: nueva.limitarX(nueva.x(dia: ancla.diaAncla) - ancla.dedos.x))
        posicionV.scrollTo(y: nueva.limitarY(nueva.y(fila: ancla.filaAncla) - ancla.yFilaAncla))
    }

    /// La escalera baja a medida que avanzan los días. Al soltar el desplazamiento horizontal,
    /// si ningún bloque de los días a la vista se ve, la carta sube o baja hasta ellos.
    private func seguirEscalera(_ plan: PlanPrograma, _ m: MedidasPrograma) {
        let primerDia = Double((desplazamientoX - margen) / m.anchoDia)
        let ultimoDia = Double((desplazamientoX + m.anchoVisible - margen) / m.anchoDia)
        let aLaVista = plan.filas.filter { Double($0.dia + 1) > primerDia && Double($0.dia) < ultimoDia }
        guard let primera = aLaVista.first?.indice, let ultima = aLaVista.last?.indice else { return }
        let arriba = m.y(fila: primera)
        let abajo = m.y(fila: ultima) + m.altoFila
        guard abajo <= desplazamientoY || arriba >= desplazamientoY + m.altoVisible else { return }
        withAnimation(.smooth(duration: 0.45)) {
            posicionV.scrollTo(y: m.limitarY(arriba - m.altoFila))
        }
    }

    /// Después de un ajuste, si el bloque quedó fuera de la pantalla, se lleva a la vista.
    private func mostrar(_ id: UUID, _ m: MedidasPrograma) {
        Task {
            // Espera a que el estado nuevo llegue a la carta.
            try? await Task.sleep(for: .milliseconds(80))
            let actual = PlanPrograma(store.estado)
            guard let fila = actual.filas.first(where: { $0.bloque.id == id }) else { return }
            let x0 = m.x(dia: fila.dia)
            let y0 = m.y(fila: fila.indice)
            withAnimation(.smooth(duration: 0.5)) {
                if x0 < desplazamientoX || x0 + m.anchoDia > desplazamientoX + m.anchoVisible {
                    posicionH.scrollTo(x: m.limitarX(x0 - m.anchoVisible / 2))
                }
                if y0 < desplazamientoY || y0 + m.altoFila > desplazamientoY + m.altoVisible {
                    posicionV.scrollTo(y: m.limitarY(y0 - m.altoFila * 2))
                }
            }
        }
    }
}

// MARK: - Datos de la carta

/// Lo que la carta necesita del estado, calculado en la vista (el modelo no cambia).
struct PlanPrograma {
    let inicio: Date
    let dias: Int
    let filas: [FilaPrograma]
    let pega: [PegaEnDia]
    let holguras: [HolguraEnDia]
    let numeros: [Int]
    /// La meta estimada (último bloque por hacer) y dónde estaba al partir, si se corrió.
    let meta: Date?
    let diaMeta: Int?
    let diaMetaOriginal: Int?
    let corrimiento: Int
    /// Días desde el inicio hasta ahora, con la fracción del día.
    let diaHoy: Double
    let semanaHoy: Int
    /// Primera fila desde hoy: ahí parte la cascada y ahí se centra la vista.
    let filaDeHoy: Int

    init(_ e: EstadoObra) {
        inicio = e.inicioObra
        let ordenados = e.bloques.sorted { $0.inicio < $1.inicio }
        let filas = ordenados.enumerated().map { indice, bloque in
            FilaPrograma(
                bloque: bloque,
                indice: indice,
                dia: e.inicioObra.dias(hasta: bloque.inicio),
                diaOrigen: bloque.origen.flatMap { $0.mismoDia(que: bloque.inicio) ? nil : e.inicioObra.dias(hasta: $0) }
            )
        }
        self.filas = filas
        let meta = Planificador.recepcion(e)
        self.meta = meta
        diaMeta = meta.map { e.inicioObra.dias(hasta: $0) }
        if let meta, let base = e.recepcionBase, !base.mismoDia(que: meta) {
            diaMetaOriginal = e.inicioObra.dias(hasta: base)
            corrimiento = base.dias(hasta: meta)
        } else {
            diaMetaOriginal = nil
            corrimiento = 0
        }
        let ultimo = (filas.map { max($0.dia, $0.diaOrigen ?? 0) } + [diaMetaOriginal ?? 0]).max() ?? 0
        let semanas = max(e.proyecto.semanas, ultimo / 7 + 1)
        dias = semanas * 7
        numeros = (0..<dias).map { e.inicioObra.mas(dias: $0).diaDelMes }

        let diaActual = e.inicioObra.dias(hasta: e.ahora)
        diaHoy = Double(diaActual) + e.ahora.fraccionDelDia
        semanaHoy = diaActual >= 0 ? diaActual / 7 : -1
        filaDeHoy = filas.first { $0.bloque.inicio >= e.ahora.inicioDelDia }?.indice ?? max(0, filas.count - 1)

        let dias = self.dias
        pega = e.pega.compactMap { evento in
            let dia = e.inicioObra.dias(hasta: evento.inicio)
            return (0..<dias).contains(dia) ? PegaEnDia(evento: evento, dia: dia) : nil
        }

        var holguras: [HolguraEnDia] = []
        if semanaHoy >= 0, semanaHoy < semanas {
            for semana in semanaHoy..<semanas {
                let deLaSemana = filas.filter { $0.dia / 7 == semana }.map(\.indice)
                guard let desde = deLaSemana.min(), let hasta = deLaSemana.max() else { continue }
                let lunes = e.inicioObra.mas(dias: semana * 7)
                for slot in Planificador.holgura(e, semanaDe: lunes, desde: e.ahora) {
                    holguras.append(HolguraEnDia(dia: e.inicioObra.dias(hasta: slot.fecha), slot: slot, filaDesde: desde, filaHasta: hasta))
                }
            }
        }
        self.holguras = holguras
    }

    /// La fila del primer bloque desde ese día: en la escalera, filas y días avanzan juntos.
    func fila(paraDia dia: Double) -> Int {
        filas.first { Double($0.dia + 1) > dia }?.indice ?? max(0, filas.count - 1)
    }

    /// "20 oct"
    func fechaCorta(dia: Int) -> String {
        Formato.fechaCorta(inicio.mas(dias: dia))
    }

    /// "20 al 26 oct" o "27 oct al 2 nov"
    func rango(semana: Int) -> String {
        let lunes = inicio.mas(dias: semana * 7)
        let domingo = lunes.mas(dias: 6)
        let mismoMes = Calendar.obra.isDate(lunes, equalTo: domingo, toGranularity: .month)
        return mismoMes
            ? "\(lunes.diaDelMes) al \(Formato.fechaCorta(domingo))"
            : "\(Formato.fechaCorta(lunes)) al \(Formato.fechaCorta(domingo))"
    }
}

struct FilaPrograma: Identifiable {
    let bloque: Bloque
    let indice: Int
    let dia: Int
    let diaOrigen: Int?

    var id: UUID { bloque.id }
}

struct PegaEnDia: Identifiable {
    let evento: EventoPega
    let dia: Int

    var id: UUID { evento.id }
}

struct HolguraEnDia: Identifiable {
    let dia: Int
    let slot: Slot
    let filaDesde: Int
    let filaHasta: Int

    var id: Int { dia }
}

struct MedidasPrograma {
    let dias: Int
    let filas: Int
    let anchoVisible: CGFloat
    let altoVisible: CGFloat
    let anchoDia: CGFloat
    let altoFila: CGFloat
    let margen: CGFloat
    let nivel: NivelDeDetalle

    let margenArriba: CGFloat = 10
    let margenAbajo: CGFloat = 24

    var semanas: Int { dias / 7 }
    var anchoContenido: CGFloat { margen * 2 + CGFloat(dias) * anchoDia }
    var altoContenido: CGFloat { margenArriba + CGFloat(max(filas, 1)) * altoFila + margenAbajo }

    /// Con poco zoom la pastilla se angosta y baja de alto: queda como una ficha de dominó.
    var altoPastilla: CGFloat { min(altoFila * 0.72, max(10, anchoDia * 1.7)) }

    /// Ancho de una pastilla normal (y de su fantasma). El bloque puente es más corto.
    var anchoBase: CGFloat { anchoDia - min(3, anchoDia * 0.2) }

    /// Un poco más ancho que en la tarjeta, para que le quepa la hora al acercar.
    func anchoPastilla(_ bloque: Bloque) -> CGFloat {
        bloque.esPuente ? anchoBase * 0.7 : anchoBase
    }

    func x(dia: Int) -> CGFloat { margen + CGFloat(dia) * anchoDia }
    func x(dia: Double) -> CGFloat { margen + CGFloat(dia) * anchoDia }
    func y(fila: Int) -> CGFloat { margenArriba + CGFloat(fila) * altoFila }
    func y(fila: Double) -> CGFloat { margenArriba + CGFloat(fila) * altoFila }

    func limitarX(_ x: CGFloat) -> CGFloat {
        min(max(0, x), max(0, anchoContenido - anchoVisible))
    }

    func limitarY(_ y: CGFloat) -> CGFloat {
        min(max(0, y), max(0, altoContenido - altoVisible))
    }

    func tamano(encabezado: CGFloat) -> CGSize {
        CGSize(width: anchoVisible, height: altoVisible + encabezado)
    }
}

extension Formato {
    /// "20 oct"
    static func fechaCorta(_ fecha: Date) -> String {
        fecha.formatted(.dateTime.day().month(.abbreviated).locale(locale)).replacingOccurrences(of: ".", with: "")
    }
}

// MARK: - Piezas

/// La pastilla del programa: la misma de la tarjeta, con más detalle cuanto más zoom.
struct PastillaPrograma: View {
    @Environment(\.colorScheme) private var esquema

    let bloque: Bloque
    let nivel: NivelDeDetalle

    var body: some View {
        let color = bloque.tipo.color
        let hecho = bloque.estado == .hecho
        ZStack {
            Capsule()
                .fill(hecho ? color : color.opacity(0.16))
            if !hecho {
                Capsule()
                    .strokeBorder(color.opacity(0.85), lineWidth: 1.2)
            }
            contenido
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(hecho ? Color.white : color.mix(with: esquema == .dark ? .white : .black, by: 0.3))
                .padding(.horizontal, nivel == .completo ? 8 : 3)
        }
    }

    private var simbolo: String {
        bloque.estado == .hecho ? (bloque.esRegreso ? "arrow.uturn.backward" : "checkmark") : bloque.tipo.simbolo
    }

    @ViewBuilder
    private var contenido: some View {
        let icono = Image(systemName: simbolo).fontWeight(.bold)
        let chico = icono.imageScale(.small)
        let hora = Text(Formato.hora(bloque.inicio))
        let duracion = Text("\(bloque.minutos) min").fontWeight(.medium)
        switch nivel {
        case .pastillas:
            EmptyView()
        case .iconos:
            ViewThatFits {
                chico
                Color.clear
            }
        case .horas where bloque.esPuente:
            // Su hora va al lado de la pastilla.
            ViewThatFits {
                chico
                Color.clear
            }
        case .horas:
            // El color ya dice el tipo; el ícono vuelve cuando hay espacio para todos.
            ViewThatFits {
                VStack(spacing: 1) {
                    hora
                    duracion
                }
                hora
                chico
                Color.clear
            }
        case .completo:
            ViewThatFits {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) { icono; hora }
                    Text("\(bloque.tipo.nombre) · \(bloque.minutos) min").fontWeight(.medium)
                }
                HStack(spacing: 4) { icono; hora; Text("· \(bloque.tipo.nombre) · \(bloque.minutos) min") }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) { icono; hora }
                    Text(bloque.tipo.nombre).fontWeight(.medium)
                }
                VStack(spacing: 1) {
                    hora
                    duracion
                }
                hora
                chico
                Color.clear
            }
        }
    }

    /// "Gimnasio, lunes 20 a las 19:30, 45 minutos. Hecho."
    static func descripcion(_ bloque: Bloque, ahora: Date) -> String {
        var partes = ["\(bloque.tipo.nombre), \(Formato.diaConNumero(bloque.inicio).lowercased()) a las \(Formato.hora(bloque.inicio)), \(bloque.minutos) minutos"]
        partes.append(DetalleBloqueSheet.estado(bloque, ahora: ahora))
        if bloque.esPuente { partes.append("Bloque puente") }
        if bloque.estado == .hecho && bloque.esRegreso { partes.append("Ficha de regreso") }
        if let origen = bloque.origen { partes.append("Se movió desde el \(Formato.dia(origen)) \(origen.diaDelMes)") }
        return partes.joined(separator: ". ")
    }
}

/// Un evento de la pega, con su título cuando hay espacio.
struct CapsulaPega: View {
    let evento: EventoPega
    let nivel: NivelDeDetalle

    var body: some View {
        Capsule()
            .fill(Color(.systemGray5))
            .overlay {
                contenido
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, nivel == .completo ? 8 : nivel == .horas ? 4 : 3)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pega: \(evento.titulo), \(Formato.dia(evento.inicio)) de \(Formato.hora(evento.inicio)) a \(Formato.hora(evento.fin))")
    }

    @ViewBuilder
    private var contenido: some View {
        let icono = Image(systemName: "briefcase.fill").foregroundStyle(Color(.systemGray))
        switch nivel {
        case .pastillas:
            EmptyView()
        case .iconos:
            ViewThatFits {
                icono.imageScale(.small)
                Color.clear
            }
        case .horas:
            ViewThatFits {
                HStack(spacing: 2) { icono.imageScale(.small); Text(Formato.hora(evento.inicio)).monospacedDigit() }
                icono.imageScale(.small)
                Color.clear
            }
            .foregroundStyle(.secondary)
        case .completo:
            // El título primero; la hora solo si cabe entera.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    icono
                    Text(evento.titulo)
                    Spacer(minLength: 4)
                    Text("\(Formato.hora(evento.inicio))–\(Formato.hora(evento.fin))").monospacedDigit()
                }
                HStack(spacing: 4) {
                    icono
                    Text(evento.titulo)
                    Spacer(minLength: 4)
                    Text(Formato.hora(evento.inicio)).monospacedDigit()
                }
                HStack(spacing: 4) {
                    icono
                    Text(evento.titulo)
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

/// Cómo leer el programa: los signos de la tarjeta y los propios de esta vista.
struct LeyendaPrograma: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cómo leer el programa")
                .font(.headline)
            ForEach(TipoBloque.allCases) { tipo in
                fila(tipo.nombre) {
                    Capsule()
                        .fill(tipo.color.opacity(0.16))
                        .overlay { Capsule().strokeBorder(tipo.color.opacity(0.85), lineWidth: 1.2) }
                }
            }
            fila("Hecho: una ficha en pie") {
                Capsule().fill(Color.accentColor)
                    .overlay { Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.white) }
            }
            fila("Ficha de regreso") {
                Capsule().fill(Color.accentColor)
                    .overlay { Image(systemName: "arrow.uturn.backward").font(.system(size: 8, weight: .bold)).foregroundStyle(.white) }
            }
            fila("Bloque puente: corto, cuenta completo") {
                Capsule()
                    .fill(Color.accentColor.opacity(0.16))
                    .overlay { Capsule().strokeBorder(Color.accentColor.opacity(0.85), lineWidth: 1.2) }
                    .padding(.horizontal, 4.5)
            }
            fila("Dónde estaba antes de moverse") {
                Capsule().strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
            fila("Holgura de la semana") {
                Rayado(separacion: 4)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                    .clipShape(.rect(cornerRadius: 3))
            }
            fila("Pega") {
                Capsule().fill(Color(.systemGray5))
                    .overlay { Image(systemName: "briefcase.fill").font(.system(size: 7)).foregroundStyle(Color(.systemGray)) }
            }
            fila("Hoy") {
                Rectangle().fill(Color.accentColor).frame(width: 1.5)
            }
            Text("Pellizca para acercar o alejar.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(width: 280, alignment: .leading)
    }

    private func fila(_ texto: String, @ViewBuilder muestra: () -> some View) -> some View {
        HStack(spacing: 10) {
            muestra()
                .frame(width: 30, height: 14)
            Text(texto)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// El aviso de Mi plan, para que también se vea sobre el programa.
struct AvisoFlotante: View {
    @Environment(ObraStore.self) private var store

    var body: some View {
        if let aviso = store.aviso {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text(aviso.texto)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if aviso.deshacer {
                    Button("Deshacer") { store.deshacer() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: aviso.id) {
                try? await Task.sleep(for: .seconds(6))
                store.cerrarAviso(aviso.id)
            }
        }
    }
}

// MARK: - Depuración

#if DEBUG
/// Atajos del programa, además de los de `Depuracion`. Ejemplo:
/// xcrun simctl launch <sim> cl.jpmeniconi.efectodomino -abrir programa -zoom semana -detalle 2 -accion ajustar
enum DepuracionPrograma {
    private static let ajustes = UserDefaults.standard

    /// semana, dos, todo o un número de días visibles.
    static var zoom: String? { ajustes.string(forKey: "zoom") }
    /// Preset que se elige dos segundos después de abrir, como un toque en el control.
    static var luego: String? { ajustes.string(forKey: "luego") }
    /// Fila (bloque en orden de fecha) cuyo detalle se abre.
    static var detalle: Int? { ajustes.object(forKey: "detalle") == nil ? nil : ajustes.integer(forKey: "detalle") }
    /// fui o ajustar, desde el detalle.
    static var accion: String? { ajustes.string(forKey: "accion") }
    /// -detente grande abre el detalle expandido.
    static var detenteGrande: Bool { ajustes.string(forKey: "detente") == "grande" }
}

extension ZoomPrograma {
    init?(depuracion texto: String) {
        switch texto {
        case "semana": self = .preset(.semana)
        case "dos": self = .preset(.dosSemanas)
        case "todo": self = .preset(.todo)
        default:
            guard let dias = Double(texto) else { return nil }
            self = .libre(dias)
        }
    }
}
#endif
