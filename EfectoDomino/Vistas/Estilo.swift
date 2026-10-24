import SwiftUI

extension TipoBloque {
    var color: Color {
        switch self {
        case .gimnasio: .accentColor
        case .caminata: .green
        case .casa: .indigo
        }
    }

    /// Ilustración del encabezado de las hojas de un bloque (`Assets.xcassets/ilustracion-*`).
    var ilustracion: String { "ilustracion-\(rawValue)" }
}

/// Encabezado ilustrado de un bloque, como los de los eventos de Google Calendar: Camila haciendo
/// esa actividad. Es decorativo, así que VoiceOver lo salta y con texto muy grande se oculta.
struct IlustracionBloque: View {
    @Environment(\.dynamicTypeSize) private var tamanoTexto

    let tipo: TipoBloque
    var alto: CGFloat = 140

    var body: some View {
        if !tamanoTexto.isAccessibilitySize {
            Image(tipo.ilustracion)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: alto)
                .clipped()
                .accessibilityHidden(true)
        }
    }
}

extension TipoBarrera {
    var simbolo: String {
        switch self {
        case .horario: "clock.badge.exclamationmark"
        case .energia: "moon.zzz"
        case .reinicio: "arrow.uturn.backward"
        case .cuerpo: "bandage"
        case .otra: "ellipsis.circle"
        }
    }
}

/// Tarjeta base, en la línea de las apps Salud y Fitness.
struct Tarjeta<Contenido: View>: View {
    @ViewBuilder var contenido: Contenido

    var body: some View {
        contenido
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
    }
}

/// Botones del mismo ancho lado a lado. Si alguno no cabe en su parte (letra grande, pantalla chica),
/// van uno sobre otro en vez de partir el texto.
struct ParDeBotones: Layout {
    var espacio: CGFloat = 12

    private func enFila(_ subviews: Subviews, ancho: CGFloat) -> Bool {
        let parte = (ancho - espacio * CGFloat(subviews.count - 1)) / CGFloat(subviews.count)
        return subviews.allSatisfy { $0.sizeThatFits(.unspecified).width <= parte }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let ideales = subviews.map { $0.sizeThatFits(.unspecified) }
        let separacion = espacio * CGFloat(subviews.count - 1)
        let ancho = proposal.width ?? (ideales.map(\.width).max() ?? 0) * CGFloat(subviews.count) + separacion
        if enFila(subviews, ancho: ancho) {
            let parte = (ancho - separacion) / CGFloat(subviews.count)
            let alto = subviews.map { $0.sizeThatFits(ProposedViewSize(width: parte, height: nil)).height }.max() ?? 0
            return CGSize(width: ancho, height: alto)
        }
        let alto = subviews.map { $0.sizeThatFits(ProposedViewSize(width: ancho, height: nil)).height }.reduce(0, +)
        return CGSize(width: ancho, height: alto + separacion)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        if enFila(subviews, ancho: bounds.width) {
            let parte = (bounds.width - espacio * CGFloat(subviews.count - 1)) / CGFloat(subviews.count)
            for (i, subview) in subviews.enumerated() {
                let x = bounds.minX + CGFloat(i) * (parte + espacio)
                subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: parte, height: bounds.height))
            }
        } else {
            var y = bounds.minY
            for subview in subviews {
                let alto = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
                subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: alto))
                y += alto + espacio
            }
        }
    }
}

struct Chip: View {
    let texto: String
    let simbolo: String

    var body: some View {
        Label(texto, systemImage: simbolo)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: .capsule)
    }
}

/// Rayado diagonal: así se dibuja la holgura en la carta Gantt.
struct Rayado: Shape {
    var separacion: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var camino = Path()
        var x = -rect.height
        while x < rect.width {
            camino.move(to: CGPoint(x: x, y: rect.height))
            camino.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += separacion
        }
        return camino
    }
}
