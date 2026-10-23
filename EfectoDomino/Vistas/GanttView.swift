import SwiftUI

struct GanttCard: View {
    let bloques: [Bloque]
    let pega: [EventoPega]
    let inicio: Date
    let ahora: Date
    let diasHolgura: [Date]
    var alVerCompleto: (() -> Void)?

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Programa a dos semanas")
                        .font(.headline)
                    Text("Si algo se mueve, se reprograma. Lo hecho se queda.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                GanttView(bloques: bloques, pega: pega, inicio: inicio, ahora: ahora, diasHolgura: diasHolgura)
                Leyenda()
                if let alVerCompleto {
                    Button(action: alVerCompleto) {
                        Label("Ver programa completo", systemImage: "arrow.up.left.and.arrow.down.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
            }
        }
    }
}

/// Carta Gantt en escalera: cada bloque depende del anterior, como fichas de dominó.
struct GanttView: View {
    let bloques: [Bloque]
    let pega: [EventoPega]
    let inicio: Date
    let ahora: Date
    let diasHolgura: [Date]
    var dias = 14

    private let altoEncabezado: CGFloat = 50
    private let altoFila: CGFloat = 28
    private let altoPastilla: CGFloat = 18

    private var filas: Int { max(bloques.count, 4) }
    private var altoTotal: CGFloat { altoEncabezado + altoFila * CGFloat(filas + 1) + 4 }

    var body: some View {
        GeometryReader { geo in
            let ancho: CGFloat = geo.size.width / CGFloat(dias)
            ZStack(alignment: .topLeading) {
                columnas(ancho: ancho)
                encabezado(ancho: ancho)
                filaPega(ancho: ancho)
                ForEach(Array(bloques.enumerated()), id: \.element.id) { item in
                    filaBloque(item.element, fila: item.offset, ancho: ancho)
                }
                lineaHoy(ancho: ancho)
            }
            .frame(width: geo.size.width, height: altoTotal, alignment: .topLeading)
        }
        .frame(height: altoTotal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Carta Gantt con \(bloques.count) bloques en las próximas dos semanas")
    }

    // MARK: - Geometría

    private func x(_ fecha: Date, ancho: CGFloat) -> CGFloat {
        CGFloat(inicio.dias(hasta: fecha)) * ancho
    }

    private func y(fila: Int) -> CGFloat {
        altoEncabezado + altoFila * CGFloat(fila + 1) + (altoFila - altoPastilla) / 2
    }

    private func anchoPastilla(_ bloque: Bloque, ancho: CGFloat) -> CGFloat {
        let base = max(ancho - 4, 10)
        return bloque.esPuente ? base * 0.62 : base
    }

    private func dentro(_ fecha: Date) -> Bool {
        (0..<dias).contains(inicio.dias(hasta: fecha))
    }

    // MARK: - Capas

    private func columnas(ancho: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<dias, id: \.self) { i in
                let dia: Date = inicio.mas(dias: i)
                let esHolgura: Bool = diasHolgura.contains { $0.mismoDia(que: dia) }
                ZStack {
                    if dia.diaSemana >= 6 {
                        Color.primary.opacity(0.035)
                    }
                    if esHolgura {
                        Rayado(separacion: 6)
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    }
                }
                .frame(width: ancho, height: altoTotal - altoEncabezado)
                .clipped()
                .offset(x: CGFloat(i) * ancho, y: altoEncabezado)
            }
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1, height: altoTotal - 16)
                .offset(x: 7 * ancho, y: 16)
        }
    }

    private func encabezado(ancho: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Text("Esta semana")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Próxima")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .offset(x: 7 * ancho + 6)
            ForEach(0..<dias, id: \.self) { i in
                let dia: Date = inicio.mas(dias: i)
                let esHoy: Bool = dia.mismoDia(que: ahora)
                VStack(spacing: 2) {
                    Text(Formato.iniciales[dia.diaSemana - 1])
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(dia.diaDelMes)")
                        .font(.system(size: 11, weight: esHoy ? .bold : .medium, design: .rounded))
                        .foregroundStyle(esHoy ? Color.white : Color.primary)
                        .frame(width: 20, height: 20)
                        .background {
                            if esHoy { Circle().fill(Color.accentColor) }
                        }
                }
                .frame(width: ancho)
                .offset(x: CGFloat(i) * ancho, y: 15)
            }
        }
    }

    private func filaPega(ancho: CGFloat) -> some View {
        let visibles = pega.filter { dentro($0.inicio) }
        return ZStack(alignment: .topLeading) {
            ForEach(visibles) { evento in
                Capsule()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(Color(.systemGray))
                    }
                    .frame(width: max(ancho - 6, 8), height: 12)
                    .offset(x: x(evento.inicio, ancho: ancho) + 3, y: altoEncabezado + (altoFila - 12) / 2)
            }
        }
    }

    private func filaBloque(_ bloque: Bloque, fila: Int, ancho: CGFloat) -> some View {
        let anchoP: CGFloat = anchoPastilla(bloque, ancho: ancho)
        let xP: CGFloat = x(bloque.inicio, ancho: ancho) + (ancho - anchoP) / 2
        let yP: CGFloat = y(fila: fila)
        let animacion = Animation.spring(duration: 0.6, bounce: 0.25).delay(Double(fila) * 0.07)

        return ZStack(alignment: .topLeading) {
            if fila > 0 {
                let anterior = bloques[fila - 1]
                let anchoAnterior: CGFloat = anchoPastilla(anterior, ancho: ancho)
                let xFinAnterior: CGFloat = x(anterior.inicio, ancho: ancho) + (ancho + anchoAnterior) / 2
                Conector(x0: xFinAnterior, x1: xP, alto: altoFila)
                    .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    .frame(height: altoFila)
                    .offset(y: y(fila: fila - 1) + altoPastilla / 2)
            }
            if let origen = bloque.origen, !origen.mismoDia(que: bloque.inicio), dentro(origen) {
                let anchoBase: CGFloat = max(ancho - 4, 10)
                let xOrigen: CGFloat = x(origen, ancho: ancho) + (ancho - anchoBase) / 2
                Capsule()
                    .strokeBorder(Color.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: anchoBase, height: altoPastilla)
                    .offset(x: xOrigen, y: yP)
                Arco(desde: xOrigen + anchoBase / 2, hasta: xP)
                    .stroke(Color.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 2]))
                    .frame(height: altoPastilla)
                    .offset(y: yP - altoPastilla / 2)
            }
            Pastilla(bloque: bloque)
                .frame(width: anchoP, height: altoPastilla)
                .offset(x: xP, y: yP)
            Text(Formato.hora(bloque.inicio))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()
                .offset(x: xP + anchoP + 3, y: yP + 3)
        }
        .animation(animacion, value: bloque.inicio)
        .animation(animacion, value: fila)
    }

    private func lineaHoy(ancho: CGFloat) -> some View {
        let dia = inicio.dias(hasta: ahora)
        let posicion: CGFloat = (CGFloat(dia) + CGFloat(ahora.fraccionDelDia)) * ancho
        return ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 1.5, height: altoTotal - altoEncabezado + 4)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
                .offset(y: -3)
        }
        .frame(width: 7)
        .offset(x: posicion - 3.5, y: altoEncabezado - 4)
        .opacity(dentro(ahora) ? 1 : 0)
        .animation(.smooth(duration: 0.5), value: ahora)
    }
}

/// Una "pastilla" de la carta Gantt.
struct Pastilla: View {
    let bloque: Bloque

    var body: some View {
        let color: Color = bloque.tipo.color
        let hecho: Bool = bloque.estado == .hecho
        ZStack {
            Capsule()
                .fill(hecho ? color : color.opacity(0.16))
            if !hecho {
                Capsule()
                    .strokeBorder(color.opacity(0.85), lineWidth: 1.2)
            }
            Image(systemName: hecho ? (bloque.esRegreso ? "arrow.uturn.backward" : "checkmark") : bloque.tipo.simbolo)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(hecho ? Color.white : color)
        }
    }
}

/// Conector final-inicio entre dos bloques consecutivos.
struct Conector: Shape {
    var x0: CGFloat
    var x1: CGFloat
    var alto: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(x0, x1) }
        set {
            x0 = newValue.first
            x1 = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var camino = Path()
        let codo = x0 + 3
        camino.move(to: CGPoint(x: x0, y: 0))
        camino.addLine(to: CGPoint(x: codo, y: 0))
        camino.addLine(to: CGPoint(x: codo, y: alto))
        camino.addLine(to: CGPoint(x: max(x1, codo), y: alto))
        return camino
    }
}

/// Flecha curva desde la posición original (fantasma) hasta la nueva.
struct Arco: Shape {
    var desde: CGFloat
    var hasta: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(desde, hasta) }
        set {
            desde = newValue.first
            hasta = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var camino = Path()
        let y = rect.minY
        camino.move(to: CGPoint(x: desde, y: y))
        camino.addQuadCurve(to: CGPoint(x: hasta, y: rect.midY), control: CGPoint(x: (desde + hasta) / 2, y: y - 10))
        let sentido: CGFloat = hasta >= desde ? 1 : -1
        camino.move(to: CGPoint(x: hasta - 4 * sentido, y: rect.midY - 4))
        camino.addLine(to: CGPoint(x: hasta, y: rect.midY))
        camino.addLine(to: CGPoint(x: hasta - 5 * sentido, y: rect.midY + 1))
        return camino
    }
}

struct Leyenda: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                ForEach(TipoBloque.allCases) { tipo in
                    HStack(spacing: 4) {
                        Capsule().fill(tipo.color).frame(width: 12, height: 6)
                        Text(tipo.nombre)
                    }
                }
            }
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Rayado(separacion: 3)
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                        .frame(width: 12, height: 8)
                        .clipShape(.rect(cornerRadius: 2))
                    Text("Holgura")
                }
                HStack(spacing: 4) {
                    Capsule().fill(Color(.systemGray4)).frame(width: 12, height: 6)
                    Text("Pega")
                }
                HStack(spacing: 4) {
                    Capsule()
                        .strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [2, 1.5]))
                        .frame(width: 12, height: 7)
                    Text("Dónde estaba")
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}
