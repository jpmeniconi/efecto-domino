import PhotosUI
import SwiftUI
import UIKit

// MARK: - Fotos de las fichas

/// Una foto de una ficha en pie: las de las visitas de enero o la que Camila agrega al registrar un bloque.
struct FotoDeFicha: Identifiable, Hashable {
    let numero: Int
    let fecha: Date
    /// Recurso de `Assets.xcassets` o JPEG en `Application Support/fotos/`.
    let foto: String
    /// Lo que muestra la foto, para VoiceOver.
    let descripcion: String

    var id: Int { numero }

    /// "jue 15 ene · 19:30"
    var cuando: String { "\(Formato.fechaConDia(fecha)) · \(Formato.hora(fecha))" }

    /// "Ficha 3, jueves, 15 de enero, 19:30. Selfie en el espejo del gimnasio."
    var textoAccesible: String {
        let dia = fecha.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Formato.locale))
        return "Ficha \(numero), \(dia), \(Formato.hora(fecha)). \(descripcion)."
    }
}

/// Foto ficticia de Camila en `Assets.xcassets`. No muestran su cara ni a ninguna persona real.
struct FotoFicticia: Identifiable, Hashable {
    let recurso: String
    let descripcion: String

    var id: String { recurso }
}

enum HistorialFotos {
    static let ficticias: [FotoFicticia] = [
        FotoFicticia(recurso: "foto-gimnasio", descripcion: "Selfie en el espejo del gimnasio, con mancuernas"),
        FotoFicticia(recurso: "foto-parque", descripcion: "Paseo con su perro por un parque, al atardecer"),
        FotoFicticia(recurso: "foto-botella", descripcion: "Su botella de agua en el camarín del gimnasio"),
        FotoFicticia(recurso: "foto-cerro", descripcion: "Sendero en un cerro, con Santiago al fondo"),
        FotoFicticia(recurso: "foto-casa", descripcion: "Elongando en el living de su casa, de noche"),
        FotoFicticia(recurso: "foto-caminata", descripcion: "Caminata con una amiga por una calle con árboles"),
        FotoFicticia(recurso: "foto-mat", descripcion: "Mat enrollado y una toalla junto a la ventana"),
        FotoFicticia(recurso: "foto-zapatillas", descripcion: "Sus zapatillas sobre hojas secas"),
    ]

    /// Las seis visitas de enero ya cuentan en la app, así que también tienen su foto. Fechas ficticias.
    static let deEnero: [FotoDeFicha] = [
        visita(1, dia: 5, 19, 30, "foto-gimnasio"),
        visita(2, dia: 7, 20, 30, "foto-parque"),
        visita(3, dia: 15, 19, 30, "foto-botella"),
        visita(4, dia: 17, 9, 0, "foto-cerro"),
        visita(5, dia: 20, 21, 15, "foto-casa"),
        visita(6, dia: 24, 10, 30, "foto-caminata"),
    ]

    private static func visita(_ numero: Int, dia: Int, _ hora: Int, _ minuto: Int, _ recurso: String) -> FotoDeFicha {
        let fecha = Calendar.obra.date(from: DateComponents(year: 2026, month: 1, day: dia, hour: hora, minute: minuto)) ?? .now
        return FotoDeFicha(numero: numero, fecha: fecha, foto: recurso, descripcion: descripcion(de: recurso, tipo: nil))
    }

    /// Las fotos de sus fichas en pie, la más nueva primero. Un bloque hecho es la ficha
    /// `visitasPrevias` + su orden entre los hechos, con la fecha y la hora del bloque.
    static func fotos(bloques: [Bloque], visitasPrevias: Int) -> [FotoDeFicha] {
        let hechos = bloques.filter { $0.estado == .hecho }.sorted { $0.inicio < $1.inicio }
        let nuevas = hechos.enumerated().compactMap { orden, bloque -> FotoDeFicha? in
            guard let foto = bloque.registro?.foto else { return nil }
            return FotoDeFicha(
                numero: visitasPrevias + orden + 1,
                fecha: bloque.inicio,
                foto: foto,
                descripcion: descripcion(de: foto, tipo: bloque.tipo)
            )
        }
        return (deEnero + nuevas).sorted { $0.numero > $1.numero }
    }

    static func descripcion(de foto: String, tipo: TipoBloque?) -> String {
        if let ficticia = ficticias.first(where: { $0.recurso == foto }) { return ficticia.descripcion }
        guard let tipo else { return "Foto de tu fototeca" }
        return "Foto de tu fototeca, del bloque de \(tipo.nombre.lowercased())"
    }

    // MARK: Fotos de la fototeca

    private static var carpeta: URL {
        URL.applicationSupportDirectory.appending(path: "fotos")
    }

    static func esArchivo(_ foto: String) -> Bool { foto.hasSuffix(".jpg") }

    private static let cache = NSCache<NSString, UIImage>()

    static func imagenGuardada(_ foto: String) -> UIImage? {
        guard esArchivo(foto) else { return nil }
        if let imagen = cache.object(forKey: foto as NSString) { return imagen }
        guard let imagen = UIImage(contentsOfFile: carpeta.appending(path: foto).path()) else { return nil }
        cache.setObject(imagen, forKey: foto as NSString)
        return imagen
    }

    /// Guarda una copia reducida en `Application Support/fotos/` y devuelve su nombre.
    static func guardar(_ datos: Data) throws -> String {
        guard let original = UIImage(data: datos) else { throw CocoaError(.fileReadCorruptFile) }
        let lado: CGFloat = 1600
        let escala = min(1, lado / max(original.size.width, original.size.height))
        let tamano = CGSize(width: original.size.width * escala, height: original.size.height * escala)
        let reducida = original.preparingThumbnail(of: tamano) ?? original
        guard let jpeg = reducida.jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let nombre = "\(UUID().uuidString).jpg"
        try jpeg.write(to: carpeta.appending(path: nombre), options: .atomic)
        return nombre
    }
}

/// La imagen de una ficha, venga de los recursos de la app o de la fototeca.
struct ImagenDeFicha: View {
    let foto: String

    var body: some View {
        if let imagen = HistorialFotos.imagenGuardada(foto) {
            Image(uiImage: imagen).resizable()
        } else if HistorialFotos.esArchivo(foto) {
            Color(.tertiarySystemFill)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        } else {
            Image(foto).resizable()
        }
    }
}

// MARK: - «Tus fotos» en «Tu avance»

/// Historial de fotos de las fichas en pie: ver lo que ya hizo dan ganas de volver.
struct HistorialFotosSeccion: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.dynamicTypeSize) private var tamanoTexto
    @Namespace private var zoom
    @ScaledMetric(relativeTo: .body) private var anchoBase: CGFloat = 150
    @State private var ampliando = false
    @State private var actual = 0
    @State private var visible: Int?

    private var fotos: [FotoDeFicha] {
        HistorialFotos.fotos(bloques: store.estado.bloques, visitasPrevias: store.proyecto.visitasPrevias)
    }

    private var ancho: CGFloat { min(anchoBase, 250) }

    var body: some View {
        let fotos = fotos
        if !fotos.isEmpty {
            Tarjeta {
                VStack(alignment: .leading, spacing: 12) {
                    // Con texto muy grande, uno sobre otro: lado a lado el título se partiría en sílabas.
                    Group {
                        if tamanoTexto.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 4) {
                                titulo
                                cuenta(fotos.count)
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline) {
                                titulo
                                Spacer(minLength: 8)
                                cuenta(fotos.count)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 10) {
                            ForEach(fotos) { foto in
                                Button {
                                    actual = foto.id
                                    ampliando = true
                                } label: {
                                    MiniaturaDeFicha(foto: foto, ancho: ancho, etiquetaAbajo: tamanoTexto.isAccessibilitySize)
                                }
                                .buttonStyle(.plain)
                                .matchedTransitionSource(id: foto.id, in: zoom) { fuente in
                                    fuente.clipShape(.rect(cornerRadius: 16, style: .continuous))
                                }
                                .accessibilityLabel(foto.textoAccesible)
                                .accessibilityHint("Abre la foto en pantalla completa")
                                .accessibilityAddTraits(.isImage)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $visible, anchor: .leading)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 18, for: .scrollContent)
                    .padding(.horizontal, -18)
                    .animation(.snappy, value: fotos)
                }
            }
            #if DEBUG
            .background { BajarHastaAqui() }
            .task { abrirDesdeDepuracion(fotos) }
            #endif
            .fullScreenCover(isPresented: $ampliando) {
                // Si desliza hasta otra foto, el carrusel la deja a la vista para que el zoom vuelva a ella.
                FotosAmpliadas(fotos: fotos, inicial: actual) { numero in
                    actual = numero
                    visible = numero
                }
                .navigationTransition(.zoom(sourceID: actual, in: zoom))
            }
        }
    }

    private var titulo: some View {
        Label("Tus fotos", systemImage: "photo.on.rectangle")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func cuenta(_ cantidad: Int) -> some View {
        Text(cantidad == 1 ? "1 foto" : "\(cantidad) fotos")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    #if DEBUG
    private func abrirDesdeDepuracion(_ fotos: [FotoDeFicha]) {
        guard !DepuracionFotos.ampliadaHecha, let numero = DepuracionFotos.fotoAmpliada,
              fotos.contains(where: { $0.id == numero }) else { return }
        DepuracionFotos.ampliadaHecha = true
        actual = numero
        visible = numero
        ampliando = true
    }
    #endif
}

/// Foto vertical con su ficha y su fecha en una esquina, sobre material.
struct MiniaturaDeFicha: View {
    let foto: FotoDeFicha
    let ancho: CGFloat
    /// Con texto muy grande la etiqueta va bajo la foto: encima la taparía entera.
    var etiquetaAbajo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ImagenDeFicha(foto: foto.foto)
                .scaledToFill()
                .frame(width: ancho, height: ancho * 1.5)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if !etiquetaAbajo {
                        etiqueta
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: .rect(cornerRadius: 10, style: .continuous))
                            .padding(8)
                    }
                }
                .contentShape(.rect(cornerRadius: 16, style: .continuous))
            if etiquetaAbajo {
                etiqueta.frame(width: ancho, alignment: .leading)
            }
        }
    }

    private var etiqueta: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Ficha \(foto.numero)")
                .font(.caption.weight(.semibold))
            Text(foto.cuando)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lineLimit(etiquetaAbajo ? nil : 1)
        .minimumScaleFactor(0.8)
    }
}

/// Las fotos a pantalla completa: se desliza entre ellas y se cierra deslizando hacia abajo.
struct FotosAmpliadas: View {
    let fotos: [FotoDeFicha]
    var alCambiar: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var actual: Int

    init(fotos: [FotoDeFicha], inicial: Int, alCambiar: @escaping (Int) -> Void) {
        self.fotos = fotos
        self.alCambiar = alCambiar
        _actual = State(initialValue: inicial)
    }

    private var foto: FotoDeFicha? { fotos.first { $0.id == actual } }

    var body: some View {
        NavigationStack {
            TabView(selection: $actual) {
                ForEach(fotos) { foto in
                    ImagenDeFicha(foto: foto.foto)
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(foto.id)
                        .accessibilityElement()
                        .accessibilityLabel(foto.textoAccesible)
                        .accessibilityAddTraits(.isImage)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: actual) { _, numero in alCambiar(numero) }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let foto {
                        VStack(spacing: 1) {
                            Text("Ficha \(foto.numero)")
                                .font(.headline)
                            Text(foto.cuando)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Elegir la foto al registrar

/// Las fotos de Camila en una grilla, como la fototeca. La fototeca real queda como segunda opción:
/// en la demo no se abre, porque mostraría fotos reales en el proyector.
struct ElegirFotoSheet: View {
    var elegida: String?
    var alElegir: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var itemFototeca: PhotosPickerItem?
    @State private var guardando = false
    @State private var problema = false

    private let columnas = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columnas, spacing: 3) {
                    ForEach(HistorialFotos.ficticias) { foto in
                        celda(foto)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                if problema {
                    Text("No se pudo usar esa foto. Prueba con otra.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Agregar foto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
            .safeAreaBar(edge: .bottom) {
                PhotosPicker(selection: $itemFototeca, matching: .images) {
                    HStack(spacing: 8) {
                        if guardando {
                            ProgressView()
                        } else {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                        Text("Elegir de la fototeca")
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .disabled(guardando)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .onChange(of: itemFototeca) { _, item in
                guard let item else { return }
                Task { await usarDeLaFototeca(item) }
            }
        }
    }

    private func celda(_ foto: FotoFicticia) -> some View {
        let marcada = foto.recurso == elegida
        return Button {
            alElegir(foto.recurso)
            dismiss()
        } label: {
            Color.clear
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay {
                    Image(foto.recurso)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(.rect(cornerRadius: 6, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if marcada {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(6)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(foto.descripcion)
        .accessibilityAddTraits(marcada ? [.isImage, .isSelected] : .isImage)
    }

    private func usarDeLaFototeca(_ item: PhotosPickerItem) async {
        guardando = true
        problema = false
        defer { guardando = false }
        do {
            guard let datos = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadUnknown) }
            alElegir(try HistorialFotos.guardar(datos))
            dismiss()
        } catch {
            problema = true
            itemFototeca = nil
        }
    }
}

// MARK: - Atajos de depuración

#if DEBUG
/// Atajos de las fotos (solo Debug). Se leen aquí para no tocar `App/Depuracion.swift`:
/// - `-fotoDePrueba foto-mat` deja esa foto elegida al abrir el registro; con `-registrar YES` se guarda sola.
/// - `-elegirFoto YES` abre la grilla de fotos al abrir el registro.
/// - `-verFotos YES` baja «Tu avance» hasta «Tus fotos».
/// - `-fotoAmpliada <n>` abre la foto de la ficha n a pantalla completa.
enum DepuracionFotos {
    private static let ajustes = UserDefaults.standard

    static var fotoDePrueba: String? { ajustes.string(forKey: "fotoDePrueba") }
    static var elegirFoto: Bool { ajustes.bool(forKey: "elegirFoto") }
    static var verFotos: Bool { ajustes.bool(forKey: "verFotos") }
    static var fotoAmpliada: Int? {
        ajustes.object(forKey: "fotoAmpliada") == nil ? nil : ajustes.integer(forKey: "fotoAmpliada")
    }

    /// Cada atajo corre una sola vez: volver a la pestaña no lo repite.
    static var bajadaHecha = false
    static var ampliadaHecha = false
}

/// `-verFotos YES`: busca el desplazamiento de «Tu avance» y lo baja hasta esta sección.
/// Solo para capturas: así no hay que tocar `AvanceView`.
private struct BajarHastaAqui: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { Marcador() }
    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Marcador: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil, DepuracionFotos.verFotos, !DepuracionFotos.bajadaHecha else { return }
            DepuracionFotos.bajadaHecha = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                var vista = superview
                while let actual = vista, !(actual is UIScrollView) { vista = actual.superview }
                guard let desplazamiento = vista as? UIScrollView else { return }
                let marco = convert(bounds, to: desplazamiento)
                let tope = desplazamiento.contentSize.height - desplazamiento.bounds.height + desplazamiento.adjustedContentInset.bottom
                let y = min(marco.minY - desplazamiento.adjustedContentInset.top - 12, tope)
                desplazamiento.setContentOffset(CGPoint(x: 0, y: max(y, -desplazamiento.adjustedContentInset.top)), animated: false)
            }
        }
    }
}
#endif
