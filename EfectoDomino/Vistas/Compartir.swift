import SwiftUI
import UniformTypeIdentifiers

/// Imagen del avance para compartir. Camila decide con quién y cuándo: nada se publica solo.
struct ReporteDeAvance: Transferable {
    let bloques: [Bloque]
    let proyecto: Proyecto
    let inicioObra: Date
    let ahora: Date

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { reporte in
            try await reporte.png()
        }
    }

    @MainActor
    func png() throws -> Data {
        let renderizador = ImageRenderer(content: ReporteView(reporte: self).frame(width: 360, height: 450))
        renderizador.scale = 3
        guard let datos = renderizador.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
        return datos
    }
}

/// La tarjeta que se comparte: el muro en blanco sobre naranja, como el ícono.
struct ReporteView: View {
    let reporte: ReporteDeAvance

    private var hechos: Int { reporte.bloques.filter { $0.estado == .hecho }.count }
    private var regresos: Int { reporte.bloques.filter { $0.estado == .hecho && $0.esRegreso }.count }
    private var semanaActual: Int { max(0, reporte.inicioObra.dias(hasta: reporte.ahora) / 7) + 1 }

    /// Igual que el muro de la app: si el efecto dominó llevó bloques a la semana 7, también se ven.
    private var semanas: Int {
        let ultima = reporte.bloques.map { reporte.inicioObra.dias(hasta: $0.inicio) / 7 }.max() ?? 0
        return max(reporte.proyecto.semanas, ultima + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Mi plan · semana \(semanaActual) de \(reporte.proyecto.semanas)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(reporte.proyecto.visitasPrevias + hechos)")
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                Text("fichas en pie")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(.white)
            muro
            Text(regresos == 0 ? "Sin partir de cero." : "Volví después de un atraso \(regresos == 1 ? "1 vez" : "\(regresos) veces"). Sin partir de cero.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
            Text("Efecto Dominó")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.55, blue: 0.24), Color(red: 0.88, green: 0.30, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var muro: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<semanas, id: \.self) { semana in
                let lunes = reporte.inicioObra.mas(dias: semana * 7)
                let hechosSemana = reporte.bloques.filter { $0.estado == .hecho && $0.inicio.lunes == lunes }
                VStack(spacing: 3) {
                    ForEach((0..<reporte.proyecto.porSemana).reversed(), id: \.self) { nivel in
                        let forma = RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        if nivel < hechosSemana.count {
                            forma.fill(.white)
                        } else {
                            forma.strokeBorder(.white.opacity(0.4), lineWidth: 1)
                        }
                    }
                    .frame(height: 15)
                }
            }
        }
    }
}

extension Bloque {
    /// Invitación a un bloque concreto. El bloque no depende de la otra persona.
    func invitacion(ahora: Date) -> String? {
        let dia = Formato.diaRelativo(inicio, ahora: ahora)
        let cuando = ahora.dias(hasta: inicio) <= 1 ? dia.lowercased() : "el \(dia.lowercased())"
        let plan: String
        switch tipo {
        case .gimnasio: plan = "Voy al gimnasio \(minutos) minutos."
        case .caminata: plan = "Voy a caminar \(minutos) minutos."
        case .casa: return nil
        }
        return "¿Te sumas \(cuando) a las \(Formato.hora(inicio))? \(plan) Si no puedes, no pasa nada: igual voy."
    }
}
