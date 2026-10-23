import SwiftUI

/// Lo construido: la frecuencia de las primeras seis semanas, como un muro.
/// Una falta nunca quita ladrillos.
struct AvanceCard: View {
    let bloques: [Bloque]
    let proyecto: Proyecto
    let inicioObra: Date
    let ahora: Date
    let recepcion: Date?
    let corrimiento: Int
    let ajustes: Int

    private var hechos: Int { bloques.filter { $0.estado == .hecho }.count }
    private var regresos: Int { bloques.filter { $0.estado == .hecho && $0.esRegreso }.count }
    private var semanaActual: Int { max(0, inicioObra.dias(hasta: ahora) / 7) + 1 }
    private var hechosEstaSemana: Int {
        bloques.filter { $0.estado == .hecho && $0.inicio.lunes == ahora.lunes }.count
    }

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Obra gruesa · semana \(semanaActual) de \(proyecto.semanas)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(hechosEstaSemana)")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("de \(proyecto.porSemana) esta semana")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Recepción")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(recepcion.map(Formato.fechaConDia) ?? "—")
                            .font(.subheadline.weight(.semibold))
                            .contentTransition(.numericText())
                        Text(textoCorrimiento)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .animation(.snappy, value: hechosEstaSemana)
                .animation(.snappy, value: recepcion)

                MuroSemanal(bloques: bloques, inicioObra: inicioObra, ahora: ahora, porSemana: proyecto.porSemana, semanasMinimas: proyecto.semanas)
                Fundaciones(cantidad: proyecto.fundaciones)

                HStack(spacing: 8) {
                    Chip(texto: "\(hechos) de \(proyecto.meta) ladrillos", simbolo: "square.stack.3d.up.fill")
                    if regresos > 0 {
                        Chip(texto: regresos == 1 ? "1 regreso" : "\(regresos) regresos", simbolo: "arrow.uturn.backward")
                            .foregroundStyle(Color.accentColor)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.5, bounce: 0.4), value: regresos)
            }
        }
    }

    private var textoCorrimiento: String {
        if corrimiento > 0 { return "Se corrió \(Formato.dias(corrimiento))" }
        if ajustes > 0 { return ajustes == 1 ? "Igual, tras 1 ajuste" : "Igual, tras \(ajustes) ajustes" }
        return "Según lo planificado"
    }
}

/// Una columna por semana; cada ladrillo es un bloque. Lo hecho va abajo.
struct MuroSemanal: View {
    let bloques: [Bloque]
    let inicioObra: Date
    let ahora: Date
    let porSemana: Int
    let semanasMinimas: Int

    private var semanas: Int {
        let ultima = bloques.map { inicioObra.dias(hasta: $0.inicio) / 7 }.max() ?? 0
        return max(semanasMinimas, ultima + 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<semanas, id: \.self) { semana in
                columna(semana)
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.3), value: bloques)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bloques.filter { $0.estado == .hecho }.count) bloques hechos")
    }

    private func columna(_ semana: Int) -> some View {
        let lunes = inicioObra.mas(dias: semana * 7)
        let enSemana = bloques
            .filter { $0.inicio.lunes == lunes }
            .sorted { ($0.estado == .hecho ? 0 : 1, $0.inicio) < ($1.estado == .hecho ? 0 : 1, $1.inicio) }
        let esActual = ahora.lunes == lunes
        return VStack(spacing: 3) {
            ForEach((0..<porSemana).reversed(), id: \.self) { nivel in
                Ladrillo(bloque: nivel < enSemana.count ? enSemana[nivel] : nil)
            }
            Text("S\(semana + 1)")
                .font(.system(size: 10, weight: esActual ? .bold : .medium, design: .rounded))
                .foregroundStyle(esActual ? Color.accentColor : Color.secondary)
                .padding(.top, 2)
        }
        .padding(4)
        .background {
            if esActual {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor.opacity(0.08))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct Ladrillo: View {
    let bloque: Bloque?

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: 3.5, style: .continuous)
        ZStack {
            if let bloque {
                if bloque.estado == .hecho {
                    forma.fill(bloque.esRegreso ? Color.accentColor : Color.accentColor.opacity(0.72))
                    if bloque.esRegreso {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                } else {
                    forma.strokeBorder(Color.accentColor.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
            } else {
                forma.fill(Color.primary.opacity(0.05))
            }
        }
        .frame(height: 15)
    }
}

/// Las seis visitas de enero: no se cuentan de nuevo, pero no se parte de cero.
struct Fundaciones: View {
    let cantidad: Int

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(0..<cantidad, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.secondary.opacity(0.55)).frame(width: 9, height: 5)
                }
            }
            Text("Fundaciones: tus \(cantidad) visitas de enero. No partes de cero.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
