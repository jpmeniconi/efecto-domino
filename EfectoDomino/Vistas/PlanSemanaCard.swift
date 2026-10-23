import SwiftUI

/// El domingo en la noche, en vez de «mañana parto»: la semana concreta, con su pega a la vista.
struct PlanSemanaCard: View {
    let lunes: Date
    let bloques: [Bloque]
    let numeroSemana: Int
    let semanas: Int
    let hechos: Int
    let opciones: (Bloque) -> [Slot]
    var alMover: (Bloque, Slot) -> Void
    var alConfirmar: () -> Void

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Tu semana del \(Formato.dia(lunes)) \(lunes.diaDelMes)", systemImage: "calendar.badge.checkmark")
                        .font(.headline)
                    Text(resumen)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    ForEach(bloques) { bloque in
                        fila(bloque)
                        if bloque.id != bloques.last?.id {
                            Divider()
                        }
                    }
                }

                Button(action: alConfirmar) {
                    Text("Confirmar semana")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        }
    }

    private var resumen: String {
        let base = "En vez de «mañana parto»: \(bloques.count) bloques que caben en tu semana real, la \(numeroSemana) de \(semanas)."
        if hechos == 0 { return base + " Tus visitas de enero siguen ahí: no partes de cero." }
        let bloquesHechos = hechos == 1 ? "1 bloque hecho" : "\(hechos) bloques hechos"
        return base + " Llevas \(bloquesHechos): sigues, no partes de cero."
    }

    private func fila(_ bloque: Bloque) -> some View {
        HStack(spacing: 12) {
            Image(systemName: bloque.tipo.simbolo)
                .foregroundStyle(bloque.tipo.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(Formato.diaConNumero(bloque.inicio)) · \(Formato.hora(bloque.inicio))")
                    .font(.subheadline.weight(.semibold))
                Text("\(bloque.tipo.nombre), \(bloque.minutos) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            let alternativas = opciones(bloque)
            if !alternativas.isEmpty {
                Menu {
                    ForEach(alternativas, id: \.self) { slot in
                        Button("\(Formato.diaConNumero(slot.fecha)) · \(Formato.hora(slot.fecha)) · \(slot.tipo.nombre)") {
                            alMover(bloque, slot)
                        }
                    }
                } label: {
                    Text("Cambiar")
                        .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 10)
        .animation(.snappy, value: bloque.inicio)
    }
}

/// Cuando un horario del plan no rinde, la obra propone revisar el supuesto.
struct AjusteCard: View {
    let ajuste: Planificador.AjusteDeRendimiento
    var alAceptar: () -> Void
    var alDescartar: () -> Void

    private var desde: String { Formato.hora(ajuste.desde.hora, ajuste.desde.minuto) }
    private var hacia: String { Formato.hora(ajuste.hacia.hora, ajuste.hacia.minuto) }
    private var dia: String { Formato.nombresDias[ajuste.desde.dia - 1] }

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                Label("Ajuste al plan", systemImage: "wrench.adjustable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Tu bloque del \(dia) a las \(desde) se movió esta semana. ¿Dejamos \(Formato.cadaSemana(ajuste.desde.dia)) a las \(hacia) desde ahora?")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Si un horario no te funciona, se cambia el horario, no tú.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button(action: alAceptar) {
                        Text("Sí, cambiar").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    Button(action: alDescartar) {
                        Text("Mantener").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
                .controlSize(.large)
            }
        }
    }
}
