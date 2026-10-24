import SwiftUI

/// Un dato de un estudio publicado, no una frase motivacional: lo que la evidencia dice que funciona.
struct DatoDeEvidencia: Identifiable, Hashable {
    var id: String { fuente }
    let texto: String
    let fuente: String
}

enum SabiasQue {
    /// Cada dato está redactado como asociación, sin prometer resultados ni dar indicaciones médicas.
    static let datos: [DatoDeEvidencia] = [
        DatoDeEvidencia(
            texto: "Faltar una vez no echa a perder un hábito: en un estudio que siguió a 96 personas formando uno nuevo, saltarse un día no cambió su avance.",
            fuente: "Lally et al., 2010 · European Journal of Social Psychology"
        ),
        DatoDeEvidencia(
            texto: "Formar un hábito tomó en promedio 66 días, con casos desde 18 hasta 254. Los famosos 21 días no salen de ningún estudio.",
            fuente: "Lally et al., 2010 · European Journal of Social Psychology"
        ),
        DatoDeEvidencia(
            texto: "En personas que recién entraban a un gimnasio, ir al menos cuatro veces por semana durante seis semanas fue lo que formó el hábito.",
            fuente: "Kaushal y Rhodes, 2015 · Journal of Behavioral Medicine"
        ),
        DatoDeEvidencia(
            texto: "En un megaestudio con 61.293 socios de gimnasio, lo que más subió la asistencia fue premiar volver después de faltar.",
            fuente: "Milkman et al., 2021 · Nature"
        ),
        DatoDeEvidencia(
            texto: "Quienes juntan su actividad en uno o dos días a la semana tienen cerca de 30 % menos riesgo de muerte por cualquier causa que quienes no se mueven.",
            fuente: "O'Donovan et al., 2017 · JAMA Internal Medicine"
        ),
        DatoDeEvidencia(
            texto: "Quince minutos diarios de actividad moderada se asociaron con 14 % menos mortalidad y unos tres años más de vida, en un estudio con más de 400 mil personas.",
            fuente: "Wen et al., 2011 · The Lancet"
        ),
        DatoDeEvidencia(
            texto: "Tres momentos al día de uno o dos minutos de actividad intensa, como subir escaleras rápido, se asociaron con hasta 40 % menos mortalidad.",
            fuente: "Stamatakis et al., 2022 · Nature Medicine"
        ),
        DatoDeEvidencia(
            texto: "La mitad de la actividad recomendada, como una hora y cuarto de caminata enérgica a la semana, se asoció con 18 % menos riesgo de depresión.",
            fuente: "Pearce et al., 2022 · JAMA Psychiatry"
        ),
        DatoDeEvidencia(
            texto: "El ejercicio junto con educación redujo en cerca de 45 % el riesgo de volver a tener un episodio de dolor lumbar.",
            fuente: "Steffens et al., 2016 · JAMA Internal Medicine"
        ),
        DatoDeEvidencia(
            texto: "Cómo te sientes mientras te mueves predice si lo vas a repetir: disfrutar un bloque pesa más que hacerlo intenso.",
            fuente: "Rhodes y Kates, 2015 · Annals of Behavioral Medicine"
        ),
    ]

    /// Un dato distinto cada día del escenario, para que no se repita al abrir la pestaña.
    static func delDia(_ fecha: Date) -> Int {
        let dia = Calendar.obra.ordinality(of: .day, in: .era, for: fecha) ?? 0
        return dia % datos.count
    }
}

/// «¿Sabías que?» en «Tu avance»: un dato por día y la opción de ver otro.
struct SabiasQueTarjeta: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var desplazamiento = 0

    private var dato: DatoDeEvidencia {
        SabiasQue.datos[(SabiasQue.delDia(store.ahora) + desplazamiento) % SabiasQue.datos.count]
    }

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                Label("¿Sabías que?", systemImage: "book.closed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text(dato.texto)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(dato.fuente)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .id(dato.id)
                .transition(reducirMovimiento ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
                .accessibilityElement(children: .combine)
                Divider()
                Button {
                    withAnimation(.smooth(duration: 0.35)) { desplazamiento += 1 }
                } label: {
                    Label("Otro dato", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .accessibilityHint("Datos de estudios publicados. No reemplazan la indicación de un profesional.")
    }
}
