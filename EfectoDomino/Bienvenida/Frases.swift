import Foundation

/// Una pausa breve al abrir la app, mientras se prepara. Nunca avanza sola.
struct Frase: Identifiable, Hashable {
    let id: String
    let texto: String
    let autor: String

    var esLarga: Bool { texto.count > 112 }
}

/// Las frases salen de content-drafts/frases-efecto-domino.xlsx (ver scripts/frases.py).
enum Frases {
    /// Las favoritas del Excel si hay; si no, las 20 del prototipo de inicio.
    static var seleccion: [Frase] {
        let ids = favoritas.isEmpty ? prototipo : favoritas
        let porId = Dictionary(candidatas.map { ($0.id, $0) }, uniquingKeysWith: { primera, _ in primera })
        let lista = ids.compactMap { porId[$0] }
        return lista.isEmpty ? candidatas : lista
    }

    /// La frase de esta apertura: una distinta cada vez, en orden.
    static let deEstaApertura: Frase? = {
        let lista = seleccion
        guard !lista.isEmpty else { return nil }
        let clave = "indiceDeFraseDeInicio"
        let indice = UserDefaults.standard.integer(forKey: clave)
        UserDefaults.standard.set(indice + 1, forKey: clave)
        return lista[indice % lista.count]
    }()
}
