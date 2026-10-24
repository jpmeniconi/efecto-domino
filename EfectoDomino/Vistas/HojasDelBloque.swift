import SwiftUI

/// «Ajustar» y «Fui» en sus hojas, igual en Mi plan y en el programa. El cambio se aplica
/// después de cerrar la hoja, para que Camila vea moverse el plan.
private struct HojasDelBloque: ViewModifier {
    @Environment(ObraStore.self) private var store
    @Binding var ajustando: Bloque?
    @Binding var registrando: Bloque?
    var alAplicar: (Propuesta) -> Void

    @State private var propuestaPendiente: Propuesta?
    @State private var registroPendiente: RegistroPendiente?

    private struct RegistroPendiente {
        let id: UUID
        let registro: Registro
        let prepararSiguiente: [String]
    }

    func body(content: Content) -> some View {
        content
            .sheet(item: $ajustando, onDismiss: aplicarPropuesta) { bloque in
                AjustarSheet(bloque: bloque) { propuestaPendiente = $0 }
            }
            .sheet(item: $registrando, onDismiss: aplicarRegistro) { bloque in
                RegistroSheet(bloque: bloque) { registro, preparar in
                    registroPendiente = RegistroPendiente(id: bloque.id, registro: registro, prepararSiguiente: preparar)
                }
            }
    }

    private func aplicarPropuesta() {
        guard let propuesta = propuestaPendiente else { return }
        propuestaPendiente = nil
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            store.aplicar(propuesta)
            alAplicar(propuesta)
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
}

extension View {
    func hojasDelBloque(
        ajustando: Binding<Bloque?>,
        registrando: Binding<Bloque?>,
        alAplicar: @escaping (Propuesta) -> Void = { _ in }
    ) -> some View {
        modifier(HojasDelBloque(ajustando: ajustando, registrando: registrando, alAplicar: alAplicar))
    }
}
