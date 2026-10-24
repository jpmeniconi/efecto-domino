import SwiftUI

/// Raíz de la app: la frase de inicio y, cuando Camila quiere, sus pestañas.
struct RaizView: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var enBienvenida = RaizView.mostrarBienvenida

    var body: some View {
        ZStack {
            if enBienvenida, let frase = Frases.deEstaApertura {
                BienvenidaView(frase: frase) {
                    withAnimation(reducirMovimiento ? .easeInOut(duration: 0.25) : .smooth(duration: 0.55)) {
                        enBienvenida = false
                    }
                }
                .transition(reducirMovimiento ? .opacity : .opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(1)
            } else {
                PestanasView()
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: enBienvenida)
        .onChange(of: store.notificaciones.apertura, initial: true) { _, apertura in
            if apertura != nil { enBienvenida = false }
        }
    }

    private static var mostrarBienvenida: Bool {
        #if DEBUG
        let ajustes = UserDefaults.standard
        if ajustes.bool(forKey: "sinBienvenida") || Depuracion.reiniciar || Depuracion.momento != nil
            || Depuracion.abrir != nil || Depuracion.pestana != nil {
            return false
        }
        #endif
        return true
    }
}

/// Una frase y su autor mientras la app se prepara. La flecha se activa al terminar la carga,
/// pero la frase se queda hasta que Camila decide seguir.
struct BienvenidaView: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    let frase: Frase
    var alEntrar: () -> Void

    @State private var aparecio = false
    @State private var avance: Double = 0
    @State private var lista = false

    var body: some View {
        VStack(spacing: 0) {
            MarcaDomino()
                .padding(.top, 20)
                .opacity(aparecio ? 1 : 0)
            Spacer(minLength: 24)
            cita
            Spacer(minLength: 24)
            VStack(spacing: 16) {
                BotonEntrar(avance: avance, lista: lista, accion: alEntrar)
                Text(lista ? "Listo cuando tú quieras" : "Preparando tu plan…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .padding(.bottom, 36)
            .opacity(aparecio ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task { await cargar() }
    }

    /// La frase va en una tarjeta como las del resto de la app, con una ilustración de Camila que cambia con la frase.
    private var cita: some View {
        VStack(alignment: .leading, spacing: 0) {
            IlustracionBloque(tipo: tipoDeLaIlustracion, alto: 150)
            VStack(alignment: .leading, spacing: 14) {
                Text(frase.texto)
                    .font(frase.esLarga ? .title3.weight(.semibold) : .title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(frase.autor)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 20)
        .opacity(aparecio ? 1 : 0)
        .offset(y: aparecio || reducirMovimiento ? 0 : 10)
        .blur(radius: aparecio || reducirMovimiento ? 0 : 4)
        .accessibilityElement(children: .combine)
    }

    private var tipoDeLaIlustracion: TipoBloque {
        let suma = frase.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return TipoBloque.allCases[suma % TipoBloque.allCases.count]
    }

    private func cargar() async {
        withAnimation(.easeOut(duration: reducirMovimiento ? 0.2 : 0.8)) { aparecio = true }
        await Arranque.preparar(store) { valor, esUltimo in
            guard !reducirMovimiento else {
                avance = valor
                if esUltimo { lista = true }
                return
            }
            // La flecha se activa cuando el anillo termina de cerrarse.
            withAnimation(.easeOut(duration: 0.6)) {
                avance = valor
            } completion: {
                if esUltimo {
                    withAnimation(.smooth(duration: 0.35)) { lista = true }
                }
            }
        }
    }
}

/// Flecha dentro del anillo de carga.
struct BotonEntrar: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    let avance: Double
    let lista: Bool
    var accion: () -> Void

    var body: some View {
        Button(action: accion) {
            ZStack {
                Circle()
                    .fill(lista ? Color.accentColor.opacity(0.12) : .clear)
                Circle()
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1.6)
                Circle()
                    .trim(from: 0, to: avance)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "arrow.right")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(lista ? Color.accentColor : Color.secondary.opacity(0.4))
                    .symbolEffect(.bounce, value: reducirMovimiento ? false : lista)
            }
            .frame(width: 76, height: 76)
            .contentShape(.circle)
        }
        .buttonStyle(AlTocar())
        .disabled(!lista)
        .accessibilityLabel("Entrar a Dominó")
        .accessibilityValue(lista ? "Listo" : "Preparando")
    }
}

private struct AlTocar: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reducirMovimiento ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// El ícono de la app y su nombre, arriba de la frase de inicio.
struct MarcaDomino: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("logo")
                .resizable()
                .frame(width: 34, height: 34)
                .clipShape(.rect(cornerRadius: 8, style: .continuous))
            Text("Dominó")
                .font(.title3.weight(.semibold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dominó")
    }
}
