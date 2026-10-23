import Foundation
import FoundationModels

/// La carga real al abrir la app, paso a paso. Sin demoras inventadas.
enum Arranque {
    /// Corre los pasos y avisa el avance (0…1) después de cada uno.
    @MainActor
    static func preparar(_ store: ObraStore, avance: (_ valor: Double, _ esUltimo: Bool) -> Void) async {
        let pasos: [@MainActor () async -> Void] = [
            { _ = store.recepcion },     // el plan quedó cargado y la meta calculada
            { prepararLectura() },        // precarga el modelo de lenguaje del iPhone
        ]
        for (indice, paso) in pasos.enumerated() {
            await paso()
            avance(Double(indice + 1) / Double(pasos.count), indice == pasos.count - 1)
            await Task.yield()
        }
    }

    /// La primera lectura en «Ajustar» sale más rápida si el modelo ya está en memoria.
    @MainActor
    private static func prepararLectura() {
        guard LectorIA.disponibilidad == .lista else { return }
        LanguageModelSession(instructions: LectorIA.instrucciones).prewarm()
    }
}
