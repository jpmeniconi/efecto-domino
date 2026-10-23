import SwiftUI

extension TipoBloque {
    var color: Color {
        switch self {
        case .gimnasio: .accentColor
        case .caminata: .green
        case .casa: .indigo
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
