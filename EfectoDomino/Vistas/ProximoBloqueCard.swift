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
                HStack {
                    Label(empezo ? "Bloque de hoy" : "Próximo bloque", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if bloque.esPuente {
                        Chip(texto: "Bloque puente", simbolo: "arrow.uturn.backward")
                            .foregroundStyle(Color.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(Formato.diaRelativo(bloque.inicio, ahora: ahora))
                            .font(.title2.weight(.semibold))
                        Text(Formato.hora(bloque.inicio))
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Label("\(bloque.tipo.nombre) · \(bloque.minutos) min", systemImage: bloque.tipo.simbolo)
                        .font(.headline)
                        .foregroundStyle(bloque.tipo.color)
                }
                .animation(.snappy, value: bloque.inicio)

                preparacion

                HStack(spacing: 12) {
                    Button(action: alRegistrar) {
                        Label("Fui", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!puedeRegistrar)

                    Button(action: alAjustar) {
                        Label("Ajustar", systemImage: "arrow.triangle.branch")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
                .controlSize(.large)
            }
        }
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
                        HStack(spacing: 6) {
                            Image(systemName: listo ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(listo ? Color.accentColor : Color.secondary)
                                .contentTransition(.symbolEffect(.replace))
                            Text(item)
                                .foregroundStyle(listo ? Color.primary : Color.secondary)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
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
                HStack(spacing: 12) {
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
