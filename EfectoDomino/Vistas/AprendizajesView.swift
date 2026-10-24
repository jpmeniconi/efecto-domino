import SwiftUI

/// «Lo que te funciona»: lo que se repite en su semana real, calculado con lo que registró.
/// La consistencia, las rutinas simples y que la experiencia sea agradable predicen el hábito
/// (Kaushal y Rhodes, 2015): por eso se miran sus horarios, lo que disfruta y cómo vuelve.
struct AprendizajesView: View {
    @Environment(ObraStore.self) private var store
    @State private var ejemplo: Aprendizajes?

    var body: some View {
        let datos = Aprendizajes(store.estado)
        Group {
            if let ejemplo {
                ListaDeAprendizajes(datos: ejemplo, esEjemplo: true) {
                    withAnimation { self.ejemplo = nil }
                }
            } else if datos.registros < Aprendizajes.minimo {
                estadoVacio(registros: datos.registros)
            } else {
                ListaDeAprendizajes(datos: datos)
            }
        }
        .navigationTitle("Lo que te funciona")
        .navigationBarTitleDisplayMode(.inline)
        #if DEBUG
        .onAppear { if Depuracion.ejemplo { verEjemplo() } }
        #endif
    }

    /// Con pocos registros no se inventan patrones: se dice cuántos faltan y se ofrece un ejemplo.
    private func estadoVacio(registros: Int) -> some View {
        ContentUnavailableView {
            Label("Registra \(Aprendizajes.minimo) bloques para ver tus patrones", systemImage: "rectangle.split.1x2.fill")
        } description: {
            Text("Llevas \(registros) de \(Aprendizajes.minimo). Con menos, cualquier patrón sería casualidad.")
        } actions: {
            Button("Ver un ejemplo de la semana 6") {
                withAnimation { verEjemplo() }
            }
            .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    /// El ejemplo usa las fechas de su programa: su semana 6 y su meta estimada.
    private func verEjemplo() {
        ejemplo = .ejemplo(desde: store.estado.inicioObra)
    }
}

/// Lleva a «Lo que te funciona» desde la tarjeta de «Tu avance».
struct BotonAprendizajes: View {
    var accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack {
                Label("Lo que te funciona", systemImage: "chart.bar.doc.horizontal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre tus horarios, lo que disfrutas, cómo vuelves y tu manual para seguir")
    }
}

// MARK: - Lista

/// La hoja como lista nativa, en el orden en que se lee una semana: cuándo, qué, cómo vuelve y cómo queda.
/// Al final, el manual para seguir cuando termine el programa.
private struct ListaDeAprendizajes: View {
    let datos: Aprendizajes
    var esEjemplo = false
    var alSalirDelEjemplo: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var tamano

    var body: some View {
        ScrollViewReader { desplazamiento in
            List {
                if esEjemplo { avisoDeEjemplo }
                horarios
                movidos
                gustos
                ayudas
                regreso
                espalda
                alTerminar
                reglas
                compartir
            }
            .navigationSubtitle(subtitulo)
            #if DEBUG
            .task {
                guard let foco = Depuracion.foco else { return }
                try? await Task.sleep(for: .milliseconds(500))
                desplazamiento.scrollTo(foco, anchor: .top)
            }
            #endif
        }
    }

    private var subtitulo: String {
        if esEjemplo { return "Ejemplo de la semana 6" }
        return datos.registros == 1 ? "Con tu primer bloque registrado" : "Con tus \(datos.registros) bloques registrados"
    }

    /// El ejemplo nunca se confunde con sus datos: lo dice arriba, en el subtítulo y en el texto que se comparte.
    private var avisoDeEjemplo: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label("Ejemplo de la semana 6", systemImage: "eye")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Text("Así se ve esta hoja en la semana 6, con \(datos.registros) bloques registrados. No son tus datos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            Button("Volver a mis datos", action: alSalirDelEjemplo)
        }
    }

    private var horarios: some View {
        Section {
            SemanaReal(porDia: datos.porDia)
                .padding(.vertical, 6)
            if datos.cumplidos.isEmpty {
                Text("Todavía no hay bloques hechos.")
                    .foregroundStyle(.secondary)
            }
            ForEach(datos.cumplidos) { cumplido in
                FilaConIcono(
                    simbolo: cumplido.tipo.simbolo,
                    color: cumplido.tipo.color,
                    titulo: cumplido.horario.nombre,
                    detalle: cumplido.detalle
                )
            }
        } header: {
            Text("Horarios que se cumplen").textCase(nil)
        }
        .id("horarios")
    }

    private var movidos: some View {
        Section {
            if datos.movidos.isEmpty {
                Text("Ningún horario se ha movido.")
                    .foregroundStyle(.secondary)
            }
            ForEach(datos.movidos) { movido in
                FilaConIcono(
                    simbolo: "arrow.triangle.branch",
                    color: .secondary,
                    titulo: movido.horario.nombre,
                    detalle: movido.detalle
                )
            }
        } header: {
            Text("Horarios que se movieron").textCase(nil)
        } footer: {
            Text("Si un horario se mueve seguido, se cambia el horario, no tú.")
        }
        .id("movidos")
    }

    private var gustos: some View {
        Section {
            if datos.gustos.isEmpty {
                Text(Self.sinDatos("¿Cómo lo pasaste?"))
                    .foregroundStyle(.secondary)
            }
            ForEach(datos.gustos) { gusto in
                Label {
                    VStack(alignment: .leading, spacing: 8) {
                        TituloYValor(titulo: gusto.tipo.nombre, valor: "Bien \(gusto.bien) de \(gusto.total)")
                        ProgressView(value: gusto.proporcion)
                            .tint(gusto.tipo.color)
                    }
                } icon: {
                    Image(systemName: gusto.tipo.simbolo)
                        .foregroundStyle(gusto.tipo.color)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(gusto.tipo.nombre): la pasaste bien \(gusto.bien) de \(gusto.total) veces")
            }
        } header: {
            Text("Lo que más disfrutas").textCase(nil)
        } footer: {
            Text("Según lo que marcas en «¿Cómo lo pasaste?».")
        }
        .id("disfrute")
    }

    private var ayudas: some View {
        Section {
            if datos.ayudas.isEmpty {
                Text(Self.sinDatos("¿Qué te ayudó a ir?"))
                    .foregroundStyle(.secondary)
            }
            ForEach(datos.ayudas) { ayuda in
                TituloYValor(titulo: ayuda.texto, valor: Aprendizajes.contar(ayuda.veces, "vez", "veces"))
                    .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Lo que más te ayudó a ir").textCase(nil)
        }
        .id("ayudas")
    }

    private var regreso: some View {
        Section {
            let disposicion = tamano.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            disposicion { cifrasDeRegreso }
                .padding(.vertical, 4)
            if let resumen = datos.resumenDeRegreso {
                Text(resumen)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Cómo vuelves").textCase(nil)
        } footer: {
            Text("Cada regreso deja una ficha.")
        }
        .id("regreso")
    }

    @ViewBuilder
    private var cifrasDeRegreso: some View {
        Cifra(valor: datos.regresos, titulo: "Fichas de regreso", simbolo: "arrow.uturn.backward")
        Cifra(valor: datos.puentes, titulo: "Bloques puente", simbolo: "timer")
    }

    private var espalda: some View {
        Section {
            if datos.espalda.total == 0 {
                Text(Self.sinDatos("¿Cómo quedó la espalda?"))
                    .foregroundStyle(.secondary)
            } else {
                ConteoEspalda(espalda: datos.espalda)
                    .padding(.vertical, 4)
                TituloYValor(
                    titulo: datos.espalda.recientes.count == 1 ? "Último bloque" : "Últimos \(datos.espalda.recientes.count) bloques",
                    valor: datos.espalda.recientes.map(\.rawValue).joined(separator: ", ")
                )
                .accessibilityElement(children: .combine)
                if let mejor = datos.espalda.mejorDespuesDe {
                    Text("\(mejor.tipo.despuesDe), tu espalda quedó mejor \(mejor.mejor) de \(mejor.total) veces.")
                }
            }
        } header: {
            Text("Cómo va tu espalda").textCase(nil)
        } footer: {
            if datos.espalda.peor > 0 {
                Text("Si la molestia se repite, conviene verlo con un profesional.")
            }
        }
        .id("espalda")
    }

    /// Recordatorios y premios funcionan solo mientras duran (Milkman et al., 2021):
    /// lo que se lleva es lo que aprendió de su propia semana.
    private var alTerminar: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("El plan pasa a tus manos")
                    .font(.headline)
                Text(datos.manual.introduccion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            ForEach(datos.manual.horarios) { cumplido in
                FilaConIcono(
                    simbolo: cumplido.tipo.simbolo,
                    color: cumplido.tipo.color,
                    titulo: cumplido.horario.nombre,
                    detalle: "\(cumplido.tipo.nombre), \(cumplido.minutos) min"
                )
            }
            if !datos.manual.gustos.isEmpty {
                FilaConEtiqueta(simbolo: "face.smiling", etiqueta: "Lo que disfrutas", valor: datos.manual.textoGustos)
            }
            if !datos.manual.ayudas.isEmpty {
                FilaConEtiqueta(simbolo: "checklist", etiqueta: "Lo que te ayuda a ir", valor: datos.manual.textoAyudas)
            }
        } header: {
            Text("Al terminar las \(datos.manual.semanas) semanas").textCase(nil)
        } footer: {
            if datos.manual.horarios.count < datos.manual.porSemana {
                Text("Se completa a medida que registras bloques.")
            }
        }
        .headerProminence(.increased)
        .id("alterminar")
    }

    private var reglas: some View {
        Section {
            ForEach(datos.manual.reglas) { regla in
                FilaConIcono(
                    simbolo: "\(regla.numero).circle.fill",
                    color: .accentColor,
                    titulo: regla.titulo,
                    detalle: regla.detalle
                )
            }
        } header: {
            Text("Tus tres reglas").textCase(nil)
        }
        .id("reglas")
    }

    /// Compartir es decisión de Camila: el texto lleva solo lo que le funciona, nunca sus faltas.
    private var compartir: some View {
        Section {
            ShareLink(item: datos.manual.texto(esEjemplo: esEjemplo), subject: Text("Mi manual para seguir")) {
                Label("Guardar o compartir mi manual", systemImage: "square.and.arrow.up")
            }
        } footer: {
            Text(esEjemplo
                ? "El texto también dice que es un ejemplo."
                : "Texto simple con lo que te funciona. Tú decides si lo guardas o a quién se lo mandas.")
        }
        .id("compartir")
    }

    private static func sinDatos(_ pregunta: String) -> String {
        "Márcalo en «\(pregunta)» al registrar un bloque."
    }
}

// MARK: - Piezas

/// Bloques hechos por día de la semana: dónde se juntan las fichas. Lo más antiguo va abajo.
private struct SemanaReal: View {
    let porDia: [[Bloque]]
    @Environment(\.dynamicTypeSize) private var tamano

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bloques hechos por día")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(porDia.indices, id: \.self) { dia in
                    VStack(spacing: 3) {
                        ForEach(porDia[dia].reversed()) { bloque in
                            Ficha(bloque: bloque)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(alignment: .top, spacing: 6) {
                ForEach(porDia.indices, id: \.self) { dia in
                    VStack(spacing: 1) {
                        Text(Formato.iniciales[dia])
                            .font(.caption.weight(.semibold))
                        if !tamano.isAccessibilitySize {
                            Text(horaFrecuente(porDia[dia]) ?? " ")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(descripcion)
    }

    private func horaFrecuente(_ bloques: [Bloque]) -> String? {
        Dictionary(grouping: bloques) { Formato.hora($0.inicio) }
            .max { a, b in a.value.count != b.value.count ? a.value.count < b.value.count : a.key > b.key }?
            .key
    }

    private var descripcion: String {
        let dias = porDia.indices
            .filter { !porDia[$0].isEmpty }
            .map { "\(Formato.nombresDias[$0]) \(porDia[$0].count)" }
        return dias.isEmpty ? "Todavía no hay bloques hechos" : "Bloques hechos por día: " + dias.joined(separator: ", ")
    }
}

/// Título y detalle en un solo párrafo (salto de línea U+2028): con letra muy grande, iOS deja el ícono
/// en la primera línea y el resto usa todo el ancho, como en Ajustes.
private struct FilaConIcono: View {
    let simbolo: String
    let color: Color
    let titulo: String
    let detalle: String

    var body: some View {
        Label {
            Text("\(Text(titulo).font(.body.weight(.semibold)))\u{2028}\(Text(detalle).font(.subheadline).foregroundStyle(.secondary))")
        } icon: {
            Image(systemName: simbolo)
                .foregroundStyle(color)
        }
    }
}

/// Etiqueta chica arriba y el valor abajo, como en Contactos.
private struct FilaConEtiqueta: View {
    let simbolo: String
    let etiqueta: String
    let valor: String

    var body: some View {
        Label {
            Text("\(Text(etiqueta).font(.subheadline).foregroundStyle(.secondary))\u{2028}\(Text(valor))")
        } icon: {
            Image(systemName: simbolo)
                .foregroundStyle(Color.accentColor)
        }
    }
}

/// Título y valor en una línea; con texto muy grande, el valor pasa abajo.
private struct TituloYValor: View {
    let titulo: String
    let valor: String
    @Environment(\.dynamicTypeSize) private var tamano

    var body: some View {
        if tamano.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                Text(valor)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(titulo)
                Spacer(minLength: 0)
                Text(valor)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

private struct Cifra: View {
    let valor: Int
    let titulo: String
    let simbolo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(titulo, systemImage: simbolo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text("\(valor)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct ConteoEspalda: View {
    let espalda: Aprendizajes.Espalda

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            columna(espalda.mejor, "Mejor", destacada: true)
            columna(espalda.igual, "Igual", destacada: false)
            columna(espalda.peor, "Peor", destacada: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quedó mejor \(Aprendizajes.contar(espalda.mejor, "vez", "veces")), igual \(espalda.igual) y peor \(espalda.peor)")
    }

    private func columna(_ cantidad: Int, _ nombre: String, destacada: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(cantidad)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(destacada ? Color.accentColor : Color.primary)
            Text(nombre)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension TipoBloque {
    /// "Después de caminar", para abrir una frase.
    var despuesDe: String {
        switch self {
        case .gimnasio: "Después del gimnasio"
        case .caminata: "Después de caminar"
        case .casa: "Después de los bloques en casa"
        }
    }

    /// "caminata y bloques en casa", para nombrarlos dentro de una lista.
    var enLista: String {
        switch self {
        case .gimnasio: "gimnasio"
        case .caminata: "caminata"
        case .casa: "bloques en casa"
        }
    }
}

// MARK: - Cálculo

/// Patrones de la semana real de Camila. No se guarda nada: se calcula de nuevo con cada registro.
struct Aprendizajes {
    /// Con menos registros, cualquier patrón sería casualidad.
    static let minimo = 3

    /// Día y hora de la semana, como los horarios del plan: «miércoles 06:30».
    struct Horario: Hashable, Comparable {
        let dia: Int // 1 = lunes … 7 = domingo
        let hora: Int
        let minuto: Int

        init(dia: Int, hora: Int, minuto: Int) {
            self.dia = dia
            self.hora = hora
            self.minuto = minuto
        }

        init(_ fecha: Date) {
            self.init(dia: fecha.diaSemana, hora: fecha.hora, minuto: fecha.minuto)
        }

        init(_ ventana: Ventana) {
            self.init(dia: ventana.dia, hora: ventana.hora, minuto: ventana.minuto)
        }

        /// Lee `Ventana.clave`: "3-06:30" = miércoles 06:30.
        init?(clave: String) {
            let partes = clave.split(separator: "-")
            let reloj = partes.last?.split(separator: ":").compactMap { Int($0) } ?? []
            guard partes.count == 2, let dia = Int(partes[0]), (1...7).contains(dia), reloj.count == 2 else { return nil }
            self.init(dia: dia, hora: reloj[0], minuto: reloj[1])
        }

        var clave: String { "\(dia)-\(reloj)" }
        /// "06:30"
        var reloj: String { Formato.hora(hora, minuto) }
        /// "miércoles"
        var nombreDelDia: String { Formato.nombresDias[dia - 1] }
        /// "Miércoles 06:30"
        var nombre: String { "\(nombreDelDia.conMayuscula) \(reloj)" }

        static func < (a: Horario, b: Horario) -> Bool {
            (a.dia, a.hora, a.minuto) < (b.dia, b.hora, b.minuto)
        }
    }

    struct Cumplido: Identifiable {
        let horario: Horario
        let tipo: TipoBloque
        let minutos: Int
        let hechos: Int
        let puentes: Int
        var id: Horario { horario }

        var detalle: String {
            if puentes == hechos { return "\(tipo.nombre) · \(Aprendizajes.contar(puentes, "bloque puente", "bloques puente"))" }
            let base = "\(tipo.nombre) · \(Aprendizajes.contar(hechos, "bloque hecho", "bloques hechos"))"
            guard puentes > 0 else { return base }
            return base + (puentes == 1 ? ", uno de ellos puente" : ", \(puentes) de ellos puente")
        }
    }

    struct Movido: Identifiable {
        let horario: Horario
        let veces: Int
        /// El plan cambió este horario por otro (un ajuste al plan que Camila aceptó).
        let reemplazo: Horario?
        /// Donde terminó haciendo los bloques que salieron de este horario.
        let destino: Horario?
        var id: Horario { horario }

        var detalle: String {
            let base = "Se movió \(Aprendizajes.contar(veces, "vez", "veces"))"
            if let reemplazo { return "\(base) · ahora es a las \(reemplazo.reloj)" }
            guard let destino else { return base }
            return destino.dia == horario.dia
                ? "\(base) · lo hiciste a las \(destino.reloj)"
                : "\(base) · lo hiciste el \(destino.nombreDelDia) a las \(destino.reloj)"
        }
    }

    struct Gusto: Identifiable {
        let tipo: TipoBloque
        let bien: Int
        let total: Int
        var proporcion: Double { Double(bien) / Double(total) }
        var id: TipoBloque { tipo }
    }

    struct Ayuda: Identifiable {
        let texto: String
        let veces: Int
        var id: String { texto }
    }

    struct Espalda {
        var mejor = 0
        var igual = 0
        var peor = 0
        var recientes: [Sensacion] = []
        /// El tipo de bloque después del cual quedó mejor la mayoría de las veces.
        var mejorDespuesDe: (tipo: TipoBloque, mejor: Int, total: Int)?
        var total: Int { mejor + igual + peor }
    }

    /// Lo que se lleva al terminar el programa: sus horarios, lo que disfruta y tres reglas, sin la app.
    struct Manual {
        struct Regla: Identifiable {
            let numero: Int
            let titulo: String
            let detalle: String
            var id: Int { numero }
        }

        let semanas: Int
        let porSemana: Int
        /// La meta estimada: el último bloque del plan. Si no quedan, ya terminó.
        let meta: Date?
        let horarios: [Cumplido]
        let gustos: [TipoBloque]
        let ayudas: [String]
        let holgura: [Horario]

        var introduccion: String {
            let cierre = "sigues sin la app, con lo que ya sabes que te funciona."
            guard let meta else { return "Completaste el programa: \(cierre)" }
            return "Tu meta estimada es el \(Formato.fechaConDia(meta)). Desde ahí \(cierre)"
        }

        var textoGustos: String { Aprendizajes.enLista(gustos.map(\.enLista)).conMayuscula }

        var textoAyudas: String {
            Aprendizajes.enLista(ayudas.map { $0.prefix(1).lowercased() + $0.dropFirst() }).conMayuscula
        }

        var reglas: [Regla] {
            let espacios = Aprendizajes.enLista(holgura.map { "\($0.nombreDelDia) \($0.reloj)" })
            return [
                Regla(
                    numero: 1,
                    titulo: "Si un bloque no calza, primero la holgura de la semana.",
                    detalle: holgura.isEmpty ? "Muévelo a otro espacio libre de la misma semana." : "Espacios libres: \(espacios)."
                ),
                Regla(
                    numero: 2,
                    titulo: "Con poco tiempo o energía, un bloque puente.",
                    detalle: "15 o 20 minutos el mismo día. Corto, pero cuenta completo."
                ),
                Regla(
                    numero: 3,
                    titulo: "Nunca recuperar con más bloques.",
                    detalle: "Máximo \(porSemana) por semana. Lo que no cabe se corre, no se acumula."
                ),
            ]
        }

        /// Texto simple para guardarlo o mandarlo. En primera persona: es su manual.
        func texto(esEjemplo: Bool) -> String {
            var lineas = esEjemplo ? ["Ejemplo de la semana 6.", ""] : []
            lineas.append("Mi manual para seguir")
            if !horarios.isEmpty {
                lineas += ["", "Mis horarios"] + horarios.map { "• \($0.horario.nombre) · \($0.tipo.nombre), \($0.minutos) min" }
            }
            if !gustos.isEmpty {
                lineas += ["", "Lo que disfruto"] + gustos.map { "• \($0.nombre)" }
            }
            if !ayudas.isEmpty {
                lineas += ["", "Lo que me ayuda a ir"] + ayudas.map { "• \($0)" }
            }
            lineas += ["", "Mis tres reglas"] + reglas.map { "\($0.numero). \($0.titulo) \($0.detalle)" }
            return lineas.joined(separator: "\n")
        }
    }

    let registros: Int
    /// Bloques hechos por día de la semana (0 = lunes), del más antiguo al más reciente.
    let porDia: [[Bloque]]
    let cumplidos: [Cumplido]
    let movidos: [Movido]
    let gustos: [Gusto]
    let ayudas: [Ayuda]
    let regresos: Int
    let puentes: Int
    let espalda: Espalda
    let manual: Manual

    /// Cuántos regresos fueron con un bloque puente (todo bloque puente hecho es un regreso).
    var resumenDeRegreso: String? {
        guard regresos > 0, puentes > 0 else { return nil }
        if puentes == regresos {
            return regresos == 1 ? "Volviste con un bloque puente." : "Tus \(regresos) regresos fueron con un bloque puente."
        }
        return "\(puentes) de tus \(regresos) regresos \(puentes == 1 ? "fue" : "fueron") con un bloque puente."
    }

    static func contar(_ cantidad: Int, _ singular: String, _ plural: String) -> String {
        cantidad == 1 ? "1 \(singular)" : "\(cantidad) \(plural)"
    }

    /// "a, b y c"
    static func enLista(_ elementos: [String]) -> String {
        guard let ultimo = elementos.last, elementos.count > 1 else { return elementos.first ?? "" }
        return elementos.dropLast().joined(separator: ", ") + " y " + ultimo
    }
}

extension Aprendizajes {
    init(_ e: EstadoObra) {
        self.init(
            bloques: e.bloques,
            patron: e.patron,
            alternativas: e.alternativas,
            movidas: e.movidasPorVentana,
            ajustesResueltos: e.ajustesResueltos,
            porSemana: e.proyecto.porSemana,
            semanas: e.proyecto.semanas
        )
    }

    init(bloques: [Bloque], patron: [Ventana], alternativas: [Ventana], movidas: [String: Int], ajustesResueltos: [String], porSemana: Int, semanas: Int) {
        let hechos = bloques.filter { $0.estado == .hecho }.sorted { $0.inicio < $1.inicio }
        let registrados = hechos.filter { $0.registro != nil }

        registros = registrados.count
        porDia = (1...7).map { dia in hechos.filter { $0.inicio.diaSemana == dia } }
        cumplidos = Self.cumplidos(hechos)
        movidos = Self.movidos(bloques: bloques, hechos: hechos, patron: patron, movidas: movidas, ajustesResueltos: ajustesResueltos)
        gustos = Self.gustos(registrados)
        ayudas = Self.ayudas(registrados)
        regresos = bloques.regresos
        puentes = hechos.filter(\.esPuente).count
        espalda = Self.espalda(registrados)
        manual = Self.manual(
            cumplidos: cumplidos,
            gustos: gustos,
            ayudas: ayudas,
            patron: patron,
            alternativas: alternativas,
            meta: Planificador.recepcion(bloques),
            porSemana: porSemana,
            semanas: semanas
        )
    }

    /// Un horario por día, el que más se cumplió (los que fueron solo bloque puente no cuentan),
    /// hasta completar una semana del plan.
    private static func manual(cumplidos: [Cumplido], gustos: [Gusto], ayudas: [Ayuda], patron: [Ventana], alternativas: [Ventana], meta: Date?, porSemana: Int, semanas: Int) -> Manual {
        let delPatron = Set(patron.map { Horario($0) })
        let mejoresPorDia = Dictionary(grouping: cumplidos.filter { $0.hechos > $0.puentes }) { $0.horario.dia }
            .values
            .compactMap { grupo in
                grupo.max { a, b in
                    a.hechos != b.hechos ? a.hechos < b.hechos : !delPatron.contains(a.horario) && delPatron.contains(b.horario)
                }
            }
        let horarios = mejoresPorDia
            .sorted { $0.hechos != $1.hechos ? $0.hechos > $1.hechos : $0.horario < $1.horario }
            .prefix(porSemana)
            .sorted { $0.horario < $1.horario }
        var disfruta = gustos.filter { $0.proporcion >= 0.5 }.prefix(2).map(\.tipo)
        if disfruta.isEmpty, let favorito = gustos.first, favorito.bien > 0 { disfruta = [favorito.tipo] }
        return Manual(
            semanas: semanas,
            porSemana: porSemana,
            meta: meta,
            horarios: horarios,
            gustos: disfruta,
            ayudas: ayudas.prefix(2).map { comoHabito($0.texto) },
            holgura: alternativas.map { Horario($0) }.sorted()
        )
    }

    /// Lo que marcó en pasado («Tenía el bolso listo»), escrito como algo que se repite («Dejar el bolso listo»).
    private static func comoHabito(_ ayuda: String) -> String {
        switch ayuda {
        case "Tenía el bolso listo": "Dejar el bolso listo"
        case "Bloqueé la agenda": "Bloquear la agenda"
        case "Era corto": "Hacerlo corto"
        case "Fui con alguien": "Ir con alguien"
        case "Salí a la hora": "Salir a la hora"
        default: ayuda
        }
    }

    private static func cumplidos(_ hechos: [Bloque]) -> [Cumplido] {
        Dictionary(grouping: hechos) { Horario($0.inicio) }
            .map { horario, grupo in
                let base = grupo.last { !$0.esPuente } ?? grupo[grupo.count - 1]
                return Cumplido(
                    horario: horario,
                    tipo: base.tipo,
                    minutos: base.minutos,
                    hechos: grupo.count,
                    puentes: grupo.filter(\.esPuente).count
                )
            }
            .sorted { $0.hechos != $1.hechos ? $0.hechos > $1.hechos : $0.horario < $1.horario }
    }

    /// Cuántas veces se movió cada horario: el origen de los bloques movidos y lo que contó el plan.
    private static func movidos(bloques: [Bloque], hechos: [Bloque], patron: [Ventana], movidas: [String: Int], ajustesResueltos: [String]) -> [Movido] {
        let delPatron = Set(patron.map { Horario($0) })
        var veces: [Horario: Int] = [:]
        var destinos: [Horario: [Horario]] = [:]
        for bloque in bloques {
            guard let origen = bloque.origen else { continue }
            veces[Horario(origen), default: 0] += 1
            if bloque.estado == .hecho { destinos[Horario(origen), default: []].append(Horario(bloque.inicio)) }
        }
        for (clave, cantidad) in movidas {
            guard let horario = Horario(clave: clave) else { continue }
            veces[horario] = max(veces[horario] ?? 0, cantidad)
        }
        return veces
            .filter { $0.value > 0 }
            .map { horario, cantidad in
                let reemplazo = ajustesResueltos.contains(horario.clave) && !delPatron.contains(horario)
                    ? patron.first { $0.dia == horario.dia }.map { Horario($0) }
                    : nil
                // Un bloque movido dentro del mismo día no guarda origen: queda hecho ese día, fuera del plan.
                let mismoDia = hechos
                    .filter { $0.origen == nil && $0.inicio.diaSemana == horario.dia }
                    .map { Horario($0.inicio) }
                    .filter { $0 != horario && !delPatron.contains($0) }
                return Movido(
                    horario: horario,
                    veces: cantidad,
                    reemplazo: reemplazo,
                    destino: masFrecuente(destinos[horario, default: []] + mismoDia)
                )
            }
            .sorted { $0.veces != $1.veces ? $0.veces > $1.veces : $0.horario < $1.horario }
    }

    private static func gustos(_ registrados: [Bloque]) -> [Gusto] {
        TipoBloque.allCases
            .compactMap { tipo -> Gusto? in
                let marcas = registrados.filter { $0.tipo == tipo }.compactMap { $0.registro?.disfrute }
                guard !marcas.isEmpty else { return nil }
                return Gusto(tipo: tipo, bien: marcas.filter { $0 == .bien }.count, total: marcas.count)
            }
            .sorted { a, b in
                if a.proporcion != b.proporcion { return a.proporcion > b.proporcion }
                if a.total != b.total { return a.total > b.total }
                return orden(a.tipo) < orden(b.tipo)
            }
    }

    private static func ayudas(_ registrados: [Bloque]) -> [Ayuda] {
        Dictionary(grouping: registrados.flatMap { $0.registro?.ayudo ?? [] }) { $0 }
            .map { Ayuda(texto: $0.key, veces: $0.value.count) }
            .sorted { a, b in
                if a.veces != b.veces { return a.veces > b.veces }
                return (orden(a.texto), a.texto) < (orden(b.texto), b.texto)
            }
    }

    private static func espalda(_ registrados: [Bloque]) -> Espalda {
        let marcas = registrados.compactMap { bloque in
            bloque.registro?.espalda.map { (tipo: bloque.tipo, sensacion: $0) }
        }
        var resultado = Espalda()
        resultado.mejor = marcas.filter { $0.sensacion == .mejor }.count
        resultado.igual = marcas.filter { $0.sensacion == .igual }.count
        resultado.peor = marcas.filter { $0.sensacion == .peor }.count
        resultado.recientes = marcas.suffix(3).map(\.sensacion)
        resultado.mejorDespuesDe = TipoBloque.allCases
            .compactMap { tipo -> (tipo: TipoBloque, mejor: Int, total: Int)? in
                let delTipo = marcas.filter { $0.tipo == tipo }
                let mejor = delTipo.filter { $0.sensacion == .mejor }.count
                return delTipo.count >= 2 && mejor * 2 >= delTipo.count ? (tipo, mejor, delTipo.count) : nil
            }
            .max { a, b in
                let pa = Double(a.mejor) / Double(a.total)
                let pb = Double(b.mejor) / Double(b.total)
                return pa != pb ? pa < pb : a.total < b.total
            }
        return resultado
    }

    private static func masFrecuente(_ horarios: [Horario]) -> Horario? {
        Dictionary(grouping: horarios) { $0 }
            .max { a, b in a.value.count != b.value.count ? a.value.count < b.value.count : a.key > b.key }?
            .key
    }

    private static func orden(_ tipo: TipoBloque) -> Int {
        TipoBloque.allCases.firstIndex(of: tipo) ?? 0
    }

    private static func orden(_ ayuda: String) -> Int {
        Escenario.ayudas.firstIndex(of: ayuda) ?? Escenario.ayudas.count
    }
}

// MARK: - Ejemplo

extension Aprendizajes {
    /// Semana 6 ficticia, para ver la hoja antes de tener datos propios. Siempre se muestra marcada como ejemplo.
    /// La historia: el miércoles 06:30 no resultó y pasó a la tarde; cuando algo se cayó, volvió con holgura
    /// o con un bloque puente. Pasa por el mismo cálculo que los datos reales.
    static func ejemplo(desde inicio: Date) -> Aprendizajes {
        let ahora = inicio.mas(dias: 36).a(22, 0) // martes de la semana 6, después de su bloque
        let miercolesTarde = Ventana(dia: 3, hora: 19, minuto: 30, tipo: .gimnasio, minutos: 45)

        // Cómo lo pasó y cómo quedó la espalda, bloque a bloque, por tipo.
        let disfrute: [TipoBloque: [Disfrute]] = [
            .gimnasio: [.normal, .normal, .bien, .normal, .bien, .mal, .bien, .bien, .normal, .bien, .bien],
            .casa: [.normal, .bien, .bien, .normal, .bien, .bien],
            .caminata: [.bien, .bien, .normal, .bien, .bien],
        ]
        let espalda: [TipoBloque: [Sensacion]] = [
            .gimnasio: [.peor, .igual, .igual, .mejor, .igual, .mejor, .igual, .mejor, .igual, .mejor, .igual],
            .casa: [.igual, .mejor, .mejor, .mejor, .mejor, .mejor],
            .caminata: [.mejor, .igual, .mejor, .igual, .mejor],
        ]

        var cuenta: [TipoBloque: Int] = [:]
        var bloques: [Bloque] = []
        for semana in 1...6 {
            let lunes = inicio.mas(dias: 7 * (semana - 1))
            for ventana in Escenario.patron {
                // Desde la semana 3, el miércoles es en la tarde: aceptó el ajuste al plan.
                let horario = ventana.dia == 3 && semana >= 3 ? miercolesTarde : ventana
                var bloque = Bloque(tipo: horario.tipo, inicio: horario.slot(enSemanaDe: lunes).fecha, minutos: horario.minutos)
                switch (semana, ventana.dia) {
                case (1, 3): // Apagó la alarma: bloque puente en la tarde.
                    bloque.inicio = lunes.mas(dias: 2).a(19, 30)
                    bloque.minutos = 20
                    bloque.esPuente = true
                case (2, 3): // Otra vez la alarma: holgura el mismo día.
                    bloque.inicio = lunes.mas(dias: 2).a(19, 30)
                case (4, 1): // Se alargó la reunión: holgura el viernes.
                    bloque.origen = bloque.inicio
                    bloque.inicio = lunes.mas(dias: 4).a(19, 30)
                case (4, 6): // Llegó sin energía: bloque puente caminando.
                    bloque.inicio = lunes.mas(dias: 5).a(20, 0)
                    bloque.minutos = 20
                    bloque.esPuente = true
                case (5, 2): // Comité largo: holgura el jueves.
                    bloque.origen = bloque.inicio
                    bloque.inicio = lunes.mas(dias: 3).a(21, 15)
                default:
                    break
                }
                if bloque.inicio < ahora {
                    let n = cuenta[bloque.tipo, default: 0]
                    cuenta[bloque.tipo] = n + 1
                    bloque.estado = .hecho
                    bloque.esRegreso = bloque.origen != nil || bloque.esPuente
                    bloque.registro = Registro(
                        fecha: bloque.fin,
                        disfrute: disfrute[bloque.tipo].map { $0[n % $0.count] },
                        espalda: espalda[bloque.tipo].map { $0[n % $0.count] },
                        ayudo: ayudasDeEjemplo(bloque, semana: semana)
                    )
                }
                bloques.append(bloque)
            }
        }

        return Aprendizajes(
            bloques: bloques,
            patron: Escenario.patron.map { $0.dia == 3 ? miercolesTarde : $0 },
            alternativas: Escenario.alternativas.filter { $0 != miercolesTarde },
            movidas: ["3-06:30": 2, "1-19:30": 1, "2-21:15": 1, "6-10:30": 1],
            ajustesResueltos: ["3-06:30"],
            porSemana: 4,
            semanas: 6
        )
    }

    private static func ayudasDeEjemplo(_ bloque: Bloque, semana: Int) -> [String] {
        if bloque.esPuente || bloque.tipo == .casa { return ["Era corto"] }
        switch bloque.tipo {
        case .gimnasio where bloque.origen != nil: return ["Salí a la hora", "Tenía el bolso listo"]
        case .gimnasio where bloque.inicio.diaSemana == 1: return ["Bloqueé la agenda", "Tenía el bolso listo"]
        case .caminata: return semana.isMultiple(of: 2) ? [] : ["Fui con alguien"]
        default: return ["Tenía el bolso listo"]
        }
    }
}

#if DEBUG
extension Depuracion {
    /// -abrir aprendizajes -ejemplo YES: abre la hoja directo en el ejemplo de la semana 6.
    static var ejemplo: Bool { UserDefaults.standard.bool(forKey: "ejemplo") }
}
#endif
