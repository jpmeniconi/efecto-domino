import SwiftUI

enum Pestana: String, Hashable {
    case plan, programa, avance
}

/// Las tres pestañas de Camila: lo de hoy, el programa entero y su avance.
/// Los controles del escenario de demo no son una pestaña: quedan arriba en «Mi plan», en el reloj y el menú.
struct PestanasView: View {
    @State private var pestana = PestanasView.inicial

    var body: some View {
        TabView(selection: $pestana) {
            Tab("Mi plan", systemImage: "calendar", value: .plan) {
                ObraView { pestana = $0 }
            }
            Tab("Programa", systemImage: "calendar.day.timeline.leading", value: .programa) {
                ProgramaView()
            }
            // Tres barras que suben: el muro de fichas por semana.
            Tab("Tu avance", systemImage: "chart.bar", value: .avance) {
                AvanceView()
            }
        }
        // Sin .tabBarMinimizeBehavior(.onScrollDown): si la barra se achica al desplazar,
        // el aviso con «Deshacer» podría quedar bajo ella justo después de un ajuste.
    }

    private static var inicial: Pestana {
        #if DEBUG
        switch Depuracion.abrir {
        case "programa": return .programa
        case "aprendizajes": return .avance
        default: break
        }
        if let pestana = Depuracion.pestana.flatMap(Pestana.init(rawValue:)) { return pestana }
        #endif
        return .plan
    }
}

/// El aviso con «Deshacer». Cada pestaña lo pone al fondo de su contenido: así queda sobre la barra.
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
                Button("Deshacer") { store.deshacer() }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: aviso.id) {
                // Al cambiar de pestaña esta tarea se cancela: el aviso sigue para la pestaña que aparece.
                guard (try? await Task.sleep(for: .seconds(6))) != nil else { return }
                store.cerrarAviso(aviso.id)
            }
        }
    }
}
