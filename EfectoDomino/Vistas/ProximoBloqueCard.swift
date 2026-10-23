import SwiftUI

struct ProximoBloqueCard: View {
    let bloque: Bloque
    let ahora: Date
    var alAjustar: () -> Void
    var alRegistrar: () -> Void
    var alPreparar: (String) -> Void

    private var empezo: Bool { ahora >= bloque.inicio }
    private var puedeRegistrar: Bool { ahora >= bloque.inicio.mas(minutos: -30) }
    private var checklist: [String] { Escenario.preparacion(para: bloque.tipo) }

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack { titulo; Spacer(); chipPuente }
                    VStack(alignment: .leading, spacing: 8) { titulo; chipPuente }
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Con letra grande, «Miércoles 28» y la hora no caben en una línea del iPhone chico.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) { dia; hora }
                        VStack(alignment: .leading, spacing: 0) { dia; hora }
                    }
                    .accessibilityElement(children: .combine)
                    Label("\(bloque.tipo.nombre) · \(bloque.minutos) min", systemImage: bloque.tipo.simbolo)
                        .font(.headline)
                        .foregroundStyle(bloque.tipo.color)
                }
                .animation(.snappy, value: bloque.inicio)

                preparacion

                ParDeBotones {
                    Button(action: alRegistrar) {
                        Label("Fui", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!puedeRegistrar)
                    .accessibilityHint(puedeRegistrar ? "Deja una ficha en pie" : "Se activa media hora antes del bloque")

                    Button(action: alAjustar) {
                        Label("Ajustar", systemImage: "arrow.triangle.branch")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .accessibilityHint("Cuenta qué pasó y elige otra opción")
                }
                .controlSize(.large)

                if let invitacion = bloque.invitacion(ahora: ahora) {
                    ShareLink(item: invitacion) {
                        Label("Invitar a alguien", systemImage: "person.2")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityHint("Comparte una invitación a este bloque")
                }
            }
        }
        // El modelo tarda en cargar la primera vez: se prepara mientras Camila mira su plan.
        .task { LectorIA.precalentar() }
    }

    private var titulo: some View {
        Label(empezo ? "Bloque de hoy" : "Próximo bloque", systemImage: "calendar.badge.clock")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var chipPuente: some View {
        if bloque.esPuente {
            Chip(texto: "Bloque puente", simbolo: "arrow.uturn.backward")
                .foregroundStyle(Color.accentColor)
        }
    }

    private var dia: some View {
        Text(Formato.diaRelativo(bloque.inicio, ahora: ahora))
            .font(.title2.weight(.semibold))
    }

    private var hora: some View {
        Text(Formato.hora(bloque.inicio))
            .font(.system(size: 46, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private var preparacion: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Antes de salir · \(bloque.preparacion.filter(checklist.contains).count) de \(checklist.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
                ForEach(checklist, id: \.self) { item in
                    let listo = bloque.preparacion.contains(item)
                    Button {
                        alPreparar(item)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: listo ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(listo ? Color.accentColor : Color.secondary)
                                .contentTransition(.symbolEffect(.replace))
                            Text(item)
                                .foregroundStyle(listo ? Color.primary : Color.secondary)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item)
                    .accessibilityAddTraits(listo ? .isSelected : [])
                    .sensoryFeedback(.selection, trigger: listo)
                }
            }
        }
    }
}

/// Un bloque de un día anterior que quedó sin registrar. Sin juicio: solo preguntar.
struct PendienteCard: View {
    let bloque: Bloque
    var alRegistrar: () -> Void
    var alAjustar: () -> Void

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                Label("Quedó sin registrar", systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(Formato.diaConNumero(bloque.inicio)) · \(Formato.hora(bloque.inicio)) · \(bloque.tipo.nombre)")
                    .font(.headline)
                ParDeBotones {
                    Button(action: alRegistrar) {
                        Label("Sí, fui", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    Button(action: alAjustar) {
                        Label("No alcancé", systemImage: "arrow.triangle.branch").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
}
