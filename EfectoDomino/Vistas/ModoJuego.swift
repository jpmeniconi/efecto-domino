import SwiftUI

// MARK: - La partida

/// Una partida del Modo juego: un ciclo de 28 días, como las 28 fichas del dominó.
/// Cada día que se mueve, cada una pone una ficha, una como máximo: gana quien se mueve más días,
/// no quien entrena más fuerte. Solo se cuentan fichas puestas; un día sin ficha no se muestra como falta.
struct Partida: Equatable {
    static let dias = 28

    struct Record: Equatable {
        let fichas: Int
        /// «en enero», «en el ciclo anterior».
        let cuando: String
    }

    /// Lunes en que parte el ciclo.
    let inicio: Date
    /// 0 es el ciclo que parte dos semanas antes del plan.
    let ciclo: Int
    /// Día del ciclo de hoy: 0…27.
    let hoy: Int
    /// Días del ciclo (0…27) en que cada una puso su ficha.
    let camila: Set<Int>
    let javiera: Set<Int>
    /// Cuándo puso Javiera la ficha de hoy, si ya la puso.
    let javieraHoy: Date?
    /// El mejor ciclo de Camila antes de este.
    let record: Record

    var fin: Date { inicio.mas(dias: Self.dias - 1) }

    /// «Javiera puso una ficha hace 2 horas. Te toca.» Solo si Javiera ya puso la de hoy y Camila todavía no.
    func aviso(ahora: Date) -> String? {
        guard let javieraHoy, !camila.contains(hoy) else { return nil }
        return "Javiera puso una ficha \(Self.hace(javieraHoy, ahora: ahora)). Te toca."
    }

    /// Cómo va este ciclo contra su mejor ciclo. Nunca dice cuánto le falta a nadie para perder.
    var frenteAlRecord: String {
        let diferencia = record.fichas - camila.count
        switch diferencia {
        case 1: return "Una ficha más y lo igualas."
        case 2...: return "\(diferencia) fichas más y lo igualas."
        case 0: return "Ya igualaste tu récord."
        default: return "Este ciclo ya es tu nuevo récord."
        }
    }

    static func hace(_ fecha: Date, ahora: Date) -> String {
        let minutos = Int(ahora.timeIntervalSince(fecha) / 60)
        switch minutos {
        case ..<1: return "recién"
        case 1: return "hace 1 minuto"
        case 2..<60: return "hace \(minutos) minutos"
        case 60..<120: return "hace 1 hora"
        default: return "hace \(minutos / 60) horas"
        }
    }
}

extension Partida {
    /// Historial ficticio de Camila antes del plan, en días hacia atrás desde el lunes en que parte:
    /// caminatas y bloques en casa de las dos semanas anteriores, para que la demo no parta en cero.
    static let historialCamila = [14, 12, 11, 9, 7, 5, 4, 2]

    /// Su mejor ciclo antes de la app, ficticio: en enero, con las seis visitas al gimnasio y caminatas.
    static let recordDeEnero = Record(fichas: 14, cuando: "en enero")

    /// Días en que se mueve Javiera, amiga ficticia de Camila, por día del ciclo (de lunes a domingo).
    private static let patronJaviera: [Bool] = [
        true, false, true, true, false, true, true,
        true, true, false, true, false, true, true,
        true, false, true, false, true, true, false,
        true, true, false, true, true, false, true,
    ]

    /// Hora en que Javiera pone su ficha según el día de la semana (lunes primero).
    private static let horaJaviera = [17, 7, 18, 7, 18, 10, 11]

    /// El juego completo del dominó, del doble cero al doble seis: una ficha para cada día del ciclo.
    static let juego: [(Int, Int)] = (0...6).flatMap { a in (a...6).map { b in (a, b) } }

    /// El primer ciclo parte dos semanas antes del plan: así hoy ya hay fichas en el tablero.
    static func ancla(_ inicioObra: Date) -> Date { inicioObra.mas(dias: -14) }

    init(estado e: EstadoObra) {
        let ancla = Self.ancla(e.inicioObra)
        let ciclo = Int((Double(ancla.dias(hasta: e.ahora)) / Double(Self.dias)).rounded(.down))
        let inicio = ancla.mas(dias: ciclo * Self.dias)
        let hoy = inicio.dias(hasta: e.ahora)

        var javiera = Set((0..<hoy).filter { Self.seMueveJaviera(dia: $0, ciclo: ciclo) })
        var javieraHoy: Date?
        if Self.seMueveJaviera(dia: hoy, ciclo: ciclo) {
            let hora = inicio.mas(dias: hoy).a(Self.horaJaviera[e.ahora.diaSemana - 1])
            if hora <= e.ahora {
                javiera.insert(hoy)
                javieraHoy = hora
            }
        }

        var record = Self.recordDeEnero
        for anterior in 0..<max(ciclo, 0) {
            let fichas = Self.fichasDeCamila(e, desde: ancla.mas(dias: anterior * Self.dias), hasta: Self.dias - 1).count
            if fichas > record.fichas {
                record = Record(fichas: fichas, cuando: anterior == ciclo - 1 ? "en el ciclo anterior" : "hace \(ciclo - anterior) ciclos")
            }
        }

        self.init(
            inicio: inicio,
            ciclo: ciclo,
            hoy: hoy,
            camila: Self.fichasDeCamila(e, desde: inicio, hasta: hoy),
            javiera: javiera,
            javieraHoy: javieraHoy,
            record: record
        )
    }

    /// Días distintos con algún bloque hecho, más el historial ficticio: máximo una ficha por día.
    static func fichasDeCamila(_ e: EstadoObra, desde inicio: Date, hasta ultimo: Int) -> Set<Int> {
        let hechos = e.bloques.filter { $0.estado == .hecho }.map(\.inicio)
        let historial = historialCamila.map { e.inicioObra.mas(dias: -$0) }
        return Set((hechos + historial).map { inicio.dias(hasta: $0) }.filter { (0...ultimo).contains($0) })
    }

    private static func seMueveJaviera(dia: Int, ciclo: Int) -> Bool {
        let i = ((dia + 7 * ciclo) % dias + dias) % dias
        return patronJaviera[i]
    }
}

// MARK: - Jugadoras

/// Camila y Javiera, ficticias: los avatares son ilustraciones, nunca fotos.
enum Jugadora {
    case camila, javiera

    var nombre: String {
        switch self {
        case .camila: "Camila"
        case .javiera: "Javiera"
        }
    }

    var avatar: String { "juego-avatar-\(self == .camila ? "camila" : "javiera")" }

    /// Un solo acento: el naranja es de Camila. Javiera va en gris.
    var color: Color { self == .camila ? .accentColor : Color.primary.opacity(0.4) }
}

struct AvatarJuego: View {
    let jugadora: Jugadora
    var tamano: CGFloat = 40
    /// Del color del fondo: separa los avatares cuando se montan uno sobre otro.
    var borde = Color(.secondarySystemGroupedBackground)

    var body: some View {
        Image(jugadora.avatar)
            .resizable()
            .scaledToFill()
            .frame(width: tamano, height: tamano)
            .clipShape(.circle)
            .overlay(Circle().strokeBorder(borde, lineWidth: max(2, tamano / 24)))
            .accessibilityHidden(true)
    }
}

// MARK: - Tarjeta en «Tu avance»

/// Acceso al Modo juego desde «Tu avance»: el marcador del ciclo y, si corresponde, el turno.
struct ModoJuegoTarjeta: View {
    @Environment(ObraStore.self) private var store
    @State private var abierto = false
    #if DEBUG
    @State private var depuracionHecha = false
    #endif

    var body: some View {
        let partida = Partida(estado: store.estado)
        Button {
            abierto = true
        } label: {
            Tarjeta {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Modo juego", systemImage: "flag.2.crossed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 14) {
                        HStack(spacing: -12) {
                            AvatarJuego(jugadora: .camila, tamano: 44)
                            AvatarJuego(jugadora: .javiera, tamano: 44)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Camila \(partida.camila.count) · Javiera \(partida.javiera.count)")
                                .font(.headline)
                                .monospacedDigit()
                            Text("De 28 fichas · día \(partida.hoy + 1) del ciclo")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let aviso = partida.aviso(ahora: store.ahora) {
                        Divider()
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                            Text(aviso)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .contentShape(.rect(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre el Modo juego con Javiera")
        .navigationDestination(isPresented: $abierto) { ModoJuegoView() }
        #if DEBUG
        .task {
            guard !depuracionHecha else { return }
            depuracionHecha = true
            if DepuracionJuego.abrir { abierto = true }
        }
        #endif
    }
}

// MARK: - Pantalla

struct ModoJuegoView: View {
    enum Modo: Hashable { case javiera, record }

    @Environment(ObraStore.self) private var store
    @State private var modo: Modo = .javiera
    @State private var tituloVisible = false
    #if DEBUG
    @State private var depuracionHecha = false
    #endif

    var body: some View {
        let partida = Partida(estado: store.estado)
        ScrollViewReader { lector in
            ScrollView {
                VStack(spacing: 16) {
                    EscenaJuego(dia: partida.hoy + 1)
                    Picker("Partida", selection: $modo.animation(.smooth(duration: 0.3))) {
                        Text("Con Javiera").tag(Modo.javiera)
                        Text("Contra tu récord").tag(Modo.record)
                    }
                    .pickerStyle(.segmented)
                    switch modo {
                    case .javiera:
                        if let aviso = partida.aviso(ahora: store.ahora) {
                            TurnoTarjeta(aviso: aviso)
                        }
                        MarcadorTarjeta(partida: partida)
                    case .record:
                        RecordTarjeta(partida: partida)
                    }
                    TableroTarjeta(partida: partida)
                        .id("tablero")
                    ReglasTarjeta()
                        .id("reglas")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            #if DEBUG
            .task {
                guard !depuracionHecha else { return }
                depuracionHecha = true
                if DepuracionJuego.modo == "record" { modo = .record }
                if let foco = DepuracionJuego.foco {
                    try? await Task.sleep(for: .milliseconds(400))
                    lector.scrollTo(foco, anchor: .top)
                }
            }
            #endif
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Modo juego")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // El título grande vive en la escena: el de la barra aparece al bajar.
            ToolbarItem(placement: .principal) {
                Text("Modo juego")
                    .font(.headline)
                    .opacity(tituloVisible ? 1 : 0)
                    .accessibilityHidden(!tituloVisible)
            }
        }
        .onScrollGeometryChange(for: Bool.self) { geometria in
            geometria.contentOffset.y + geometria.contentInsets.top > 230
        } action: { _, visible in
            withAnimation(.easeInOut(duration: 0.2)) { tituloVisible = visible }
        }
    }
}

/// Arriba de la partida: Camila y Javiera con las espadas cruzadas y las piezas flotando despacio.
/// Con «Reducir movimiento» todo queda quieto.
private struct EscenaJuego: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let dia: Int

    private struct Pieza {
        let imagen: String
        let x: Double
        let y: Double
        let tamano: CGFloat
        let giro: Double
        let fase: Double
    }

    private static let piezas = [
        Pieza(imagen: "juego-ficha-domino", x: 0.09, y: 0.2, tamano: 58, giro: -16, fase: 0),
        Pieza(imagen: "juego-zapatilla", x: 0.9, y: 0.18, tamano: 56, giro: 12, fase: 1.4),
        Pieza(imagen: "juego-mancuerna", x: 0.1, y: 0.84, tamano: 54, giro: 20, fase: 2.3),
        Pieza(imagen: "juego-botella", x: 0.9, y: 0.82, tamano: 50, giro: -12, fase: 3.6),
        Pieza(imagen: "juego-fichas-sueltas", x: 0.5, y: 0.14, tamano: 44, giro: 8, fase: 4.7),
    ]

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reducirMovimiento)) { contexto in
                let t = reducirMovimiento ? 0 : contexto.date.timeIntervalSinceReferenceDate
                GeometryReader { geometria in
                    let ancho = geometria.size.width
                    let alto = geometria.size.height
                    ZStack {
                        ForEach(Self.piezas.indices, id: \.self) { i in
                            let pieza = Self.piezas[i]
                            Image(pieza.imagen)
                                .resizable()
                                .scaledToFit()
                                .frame(width: pieza.tamano, height: pieza.tamano)
                                .rotationEffect(.degrees(pieza.giro + sin(t * 0.5 + pieza.fase) * 6))
                                .position(
                                    x: pieza.x * ancho + cos(t * 0.35 + pieza.fase) * 4,
                                    y: pieza.y * alto + sin(t * 0.7 + pieza.fase) * 7
                                )
                        }
                        HStack(alignment: .top, spacing: 6) {
                            avatar(.camila)
                            Image("juego-espadas")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 62, height: 62)
                                .scaleEffect(1 + sin(t * 1.1) * 0.035)
                                .padding(.top, 14)
                            avatar(.javiera)
                        }
                        .position(x: ancho / 2, y: alto * 0.54)
                    }
                }
            }
            .frame(height: 196)
            .accessibilityHidden(true)

            Text("Modo juego")
                .font(.largeTitle.bold())
            Text("Camila y Javiera · día \(dia) de 28")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 22)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background {
            RadialGradient(
                colors: [Color.accentColor.opacity(0.16), .clear],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 10,
                endRadius: 190
            )
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 26))
        .accessibilityElement(children: .combine)
    }

    private func avatar(_ jugadora: Jugadora) -> some View {
        VStack(spacing: 6) {
            AvatarJuego(jugadora: jugadora, tamano: 88, borde: jugadora == .camila ? .accentColor : Color.primary.opacity(0.12))
            Text(jugadora.nombre)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct TurnoTarjeta: View {
    let aviso: String

    var body: some View {
        Tarjeta {
            HStack(spacing: 14) {
                AvatarJuego(jugadora: .javiera, tamano: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Es tu turno")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(aviso)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }
}

/// Fichas puestas en la barra, de izquierda a derecha: la barra no muestra qué días.
private struct BarraDeFichas: View {
    let puestas: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<Partida.dias, id: \.self) { i in
                Capsule()
                    .fill(i < puestas ? color : Color.primary.opacity(0.08))
                    .frame(height: 8)
            }
        }
    }
}

private struct FilaDeFichas<Icono: View>: View {
    let titulo: String
    let detalle: String
    let puestas: Int
    let color: Color
    @ViewBuilder var icono: Icono

    var body: some View {
        HStack(spacing: 12) {
            icono
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(titulo)
                        .font(.headline)
                    Spacer()
                    Text(detalle)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                BarraDeFichas(puestas: puestas, color: color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titulo): \(detalle)")
    }
}

private struct MarcadorTarjeta: View {
    let partida: Partida

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 16) {
                Label("Este ciclo", systemImage: "flag.2.crossed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                FilaDeFichas(titulo: "Camila", detalle: "\(partida.camila.count) de 28", puestas: partida.camila.count, color: Jugadora.camila.color) {
                    AvatarJuego(jugadora: .camila, tamano: 38)
                }
                FilaDeFichas(titulo: "Javiera", detalle: "\(partida.javiera.count) de 28", puestas: partida.javiera.count, color: Jugadora.javiera.color) {
                    AvatarJuego(jugadora: .javiera, tamano: 38)
                }
                Text("El ciclo cierra el \(Formato.dia(partida.fin)) \(partida.fin.formatted(.dateTime.day().month(.wide).locale(Formato.locale))).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RecordTarjeta: View {
    let partida: Partida

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 16) {
                Label("Ciclo contra ciclo", systemImage: "trophy")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                FilaDeFichas(
                    titulo: "Tu récord",
                    detalle: "\(partida.record.fichas) fichas, \(partida.record.cuando)",
                    puestas: partida.record.fichas,
                    color: Color.primary.opacity(0.4)
                ) { icono("trophy.fill") }
                FilaDeFichas(
                    titulo: "Este ciclo",
                    detalle: partida.camila.count == 1 ? "1 ficha hasta hoy" : "\(partida.camila.count) fichas hasta hoy",
                    puestas: partida.camila.count,
                    color: .accentColor
                ) { AvatarJuego(jugadora: .camila, tamano: 38) }
                Text(partida.frenteAlRecord)
                    .font(.body)
                Text("Las fichas de cada ciclo quedan guardadas: lo hecho no se pierde.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func icono(_ simbolo: String) -> some View {
        Image(systemName: simbolo)
            .font(.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 38, height: 38)
            .background(Color.primary.opacity(0.06), in: .circle)
    }
}

/// El tablero de Camila: 4 filas de 7 días, con una ficha del dominó en cada día que se movió.
/// Los días sin ficha, pasados o futuros, se ven iguales: el tablero no marca faltas.
private struct TableroTarjeta: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let partida: Partida
    @State private var enPie = false

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Tu tablero", systemImage: "square.grid.3x3.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(partida.camila.count == 1 ? "1 ficha en pie" : "\(partida.camila.count) fichas en pie")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                Grid(horizontalSpacing: 8, verticalSpacing: 10) {
                    GridRow {
                        ForEach(Formato.iniciales.indices, id: \.self) { i in
                            Text(Formato.iniciales[i])
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(0..<4, id: \.self) { semana in
                        GridRow {
                            ForEach(0..<7, id: \.self) { dia in
                                let i = semana * 7 + dia
                                FichaDelTablero(
                                    puntos: Partida.juego[i],
                                    puesta: partida.camila.contains(i),
                                    esHoy: i == partida.hoy
                                )
                                // Al entrar, las fichas se ponen de pie una tras otra.
                                .scaleEffect(enPie || !partida.camila.contains(i) ? 1 : 0.7, anchor: .bottom)
                                .rotationEffect(.degrees(enPie || !partida.camila.contains(i) ? 0 : -10), anchor: .bottom)
                                .opacity(enPie || !partida.camila.contains(i) ? 1 : 0)
                                .animation(.spring(duration: 0.45, bounce: 0.35).delay(Double(i) * 0.025), value: enPie)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if reducirMovimiento { enPie = true } else { DispatchQueue.main.async { enPie = true } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tu tablero: \(partida.camila.count) fichas puestas. Hoy es el día \(partida.hoy + 1) de 28.")
    }
}

private struct FichaDelTablero: View {
    let puntos: (Int, Int)
    let puesta: Bool
    let esHoy: Bool

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: 7, style: .continuous)
        forma
            .fill(puesta ? Color.accentColor : Color.primary.opacity(0.06))
            .overlay {
                if puesta {
                    VStack(spacing: 0) {
                        PuntosDomino(valor: puntos.0)
                        Capsule()
                            .fill(.white.opacity(0.65))
                            .frame(height: 1.5)
                            .padding(.horizontal, 6)
                        PuntosDomino(valor: puntos.1)
                    }
                    .padding(3)
                }
            }
            .overlay {
                if esHoy && !puesta {
                    forma.strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                }
            }
            .aspectRatio(0.56, contentMode: .fit)
            .frame(maxWidth: 38)
            .shadow(color: puesta ? Color.accentColor.opacity(0.25) : .clear, radius: 3, y: 2)
    }
}

/// Los puntos de media ficha, de 0 a 6, como en el dominó.
private struct PuntosDomino: View {
    let valor: Int

    private static let posiciones: [[(Double, Double)]] = [
        [],
        [(0.5, 0.5)],
        [(0.27, 0.27), (0.73, 0.73)],
        [(0.27, 0.27), (0.5, 0.5), (0.73, 0.73)],
        [(0.27, 0.27), (0.73, 0.27), (0.27, 0.73), (0.73, 0.73)],
        [(0.27, 0.27), (0.73, 0.27), (0.5, 0.5), (0.27, 0.73), (0.73, 0.73)],
        [(0.27, 0.22), (0.73, 0.22), (0.27, 0.5), (0.73, 0.5), (0.27, 0.78), (0.73, 0.78)],
    ]

    var body: some View {
        Canvas { contexto, tamano in
            let radio = min(tamano.width, tamano.height) * 0.1
            for (x, y) in Self.posiciones[valor] {
                let centro = CGPoint(x: x * tamano.width, y: y * tamano.height)
                let punto = CGRect(x: centro.x - radio, y: centro.y - radio, width: radio * 2, height: radio * 2)
                contexto.fill(Path(ellipseIn: punto), with: .color(.white))
            }
        }
    }
}

private struct ReglasTarjeta: View {
    private static let reglas: [(simbolo: String, texto: String)] = [
        ("calendar", "Cada partida dura un ciclo de 28 días, como las 28 fichas del dominó."),
        ("1.circle", "Cada día que te mueves pones una ficha, una como máximo. Gana quien se mueve más días, no quien entrena más fuerte."),
        ("flag.checkered", "Gana la primera en poner sus 28 fichas. Si ninguna llega, gana la que tenga más al cerrar el ciclo."),
        ("eye.slash", "Javiera ve cuántas fichas pusiste, nunca qué días."),
    ]

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                Label("Cómo se juega", systemImage: "book.closed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(Self.reglas.indices, id: \.self) { i in
                    let regla = Self.reglas[i]
                    Label {
                        Text(regla.texto)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: regla.simbolo)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

#if DEBUG
/// Atajos del Modo juego (solo Debug), junto con `-pestana avance`:
/// `-juego YES` abre la pantalla, `-juegoModo record` parte en «Contra tu récord» y
/// `-juegoFoco tablero|reglas` baja a esa tarjeta.
enum DepuracionJuego {
    static var abrir: Bool { UserDefaults.standard.bool(forKey: "juego") }
    static var modo: String? { UserDefaults.standard.string(forKey: "juegoModo") }
    static var foco: String? { UserDefaults.standard.string(forKey: "juegoFoco") }
}
#endif
