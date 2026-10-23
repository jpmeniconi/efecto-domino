import SwiftUI

/// «Lo que te funciona»: lo que se repite en su semana real, calculado con lo que registró.
/// La consistencia, las rutinas simples y que la experiencia sea agradable predicen el hábito
/// (Kaushal y Rhodes, 2015): por eso se miran sus horarios, lo que disfruta y cómo vuelve.
struct AprendizajesView: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ListaDeAprendizajes(datos: Aprendizajes(store.estado))
                .navigationTitle("Lo que te funciona")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar", systemImage: "xmark") { dismiss() }
                    }
                }
        }
    }
}

/// Abre «Lo que te funciona» desde la tarjeta «Tu avance».
struct BotonAprendizajes: View {
    @State private var abierta = false

    var body: some View {
        Button {
            abierta = true
        } label: {
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
        .accessibilityHint("Abre tus horarios, lo que disfrutas y cómo vuelves")
        .sheet(isPresented: $abierta) {
            AprendizajesView()
        }
        #if DEBUG
        .onAppear { if Depuracion.abrir == "aprendizajes" { abierta = true } }
        #endif
    }
}

// MARK: - Lista

/// La hoja como lista nativa, en el orden en que se lee una semana: cuándo, qué, cómo vuelve y cómo queda.
private struct ListaDeAprendizajes: View {
    let datos: Aprendizajes

    var body: some View {
        ScrollViewReader { desplazamiento in
            List {
                horarios
                movidos
                gustos
                ayudas
                regreso
                espalda
            }
            .navigationSubtitle(datos.registros == 1 ? "Con tu primer bloque registrado" : "Con tus \(datos.registros) bloques registrados")
            #if DEBUG
            .task {
                guard let foco = Depuracion.foco else { return }
                try? await Task.sleep(for: .milliseconds(500))
                desplazamiento.scrollTo(foco, anchor: .top)
            }
            #endif
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
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) { cifrasDeRegreso }
                VStack(alignment: .leading, spacing: 16) { cifrasDeRegreso }
            }
            .padding(.vertical, 4)
            if let resumen = datos.resumenDeRegreso {
                Text(resumen)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Cómo vuelves").textCase(nil)
        } footer: {
            Text("Cada regreso deja una ficha. Una falta no bota ninguna.")
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
                    Text("\(mejor.tipo.despuesDe) quedó mejor \(mejor.mejor) de \(mejor.total) veces.")
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
            .frame(minHeight: 51, alignment: .bottom)
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

private struct FilaConIcono: View {
    let simbolo: String
    let color: Color
    let titulo: String
    let detalle: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.body.weight(.semibold))
                Text(detalle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: simbolo)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
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
        .accessibilityLabel("Quedó mejor \(espalda.mejor), igual \(espalda.igual) y peor \(espalda.peor) veces")
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
}

// MARK: - Cálculo

/// Patrones de la semana real de Camila. No se guarda nada: se calcula de nuevo con cada registro.
struct Aprendizajes {
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
}

extension Aprendizajes {
    init(_ e: EstadoObra) {
        self.init(bloques: e.bloques, patron: e.patron, movidas: e.movidasPorVentana, ajustesResueltos: e.ajustesResueltos)
    }

    init(bloques: [Bloque], patron: [Ventana], movidas: [String: Int], ajustesResueltos: [String]) {
        let hechos = bloques.filter { $0.estado == .hecho }.sorted { $0.inicio < $1.inicio }
        let registrados = hechos.filter { $0.registro != nil }

        registros = registrados.count
        porDia = (1...7).map { dia in hechos.filter { $0.inicio.diaSemana == dia } }
        cumplidos = Self.cumplidos(hechos)
        movidos = Self.movidos(bloques: bloques, hechos: hechos, patron: patron, movidas: movidas, ajustesResueltos: ajustesResueltos)
        gustos = Self.gustos(registrados)
        ayudas = Self.ayudas(registrados)
        regresos = hechos.filter(\.esRegreso).count
        puentes = hechos.filter(\.esPuente).count
        espalda = Self.espalda(registrados)
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
