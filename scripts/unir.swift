import AVFoundation

// Uso: unir.swift <salida> <videos...>: junta los videos en ese orden, sin audio, y exporta H.264.
// Los videos deben venir a 720 de ancho (recortar.swift los deja así); el tamaño final es el del primero.
// Si un video parte con la pantalla de arranque en blanco, le quita ese blanco (el arranque de la app varía más de un segundo).
// «video.mp4@1.5» además parte 1,5 s después de que aparece el contenido: sirve para empalmar tomas sin depender del arranque.
let args = CommandLine.arguments
guard args.count >= 3 else {
    print("Uso: unir.swift <salida> <videos...>")
    exit(1)
}
let salida = URL(fileURLWithPath: args[1])
try? FileManager.default.removeItem(at: salida)
let sem = DispatchSemaphore(value: 0)

/// Qué parte de la pantalla es blanco puro, sin contar la barra de estado ni el indicador de inicio.
func fraccionBlanca(_ img: CGImage) -> Double {
    let w = img.width, h = img.height
    var datos = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &datos, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    var total = 0, blancos = 0
    for y in Int(Double(h) * 0.12)..<Int(Double(h) * 0.95) {
        for x in 0..<w {
            let i = (y * w + x) * 4
            total += 1
            if datos[i] >= 252 && datos[i + 1] >= 252 && datos[i + 2] >= 252 { blancos += 1 }
        }
    }
    return Double(blancos) / Double(total)
}

/// El segundo del primer cuadro con contenido, buscando hasta 12 s por si el arranque es en frío.
func segundoConContenido(_ asset: AVURLAsset) async -> Double {
    let gen = AVAssetImageGenerator(asset: asset)
    gen.maximumSize = CGSize(width: 120, height: 260)
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter = .zero
    var t = 0.0
    let duracion = (try? await asset.load(.duration))?.seconds ?? 12
    while t < min(12, duracion) {
        guard let (img, _) = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)) else { return 0 }
        if fraccionBlanca(img) < 0.995 { return t }
        t += 0.05
    }
    return 0
}

func unir() async throws {
    let composicion = AVMutableComposition()
    let pista = composicion.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    var inicio = CMTime.zero

    for argumento in args.dropFirst(2) {
        let partes = argumento.split(separator: "@", maxSplits: 1).map(String.init)
        let ruta = partes[0]
        let despues = partes.count > 1 ? Double(partes[1]) ?? 0 : 0
        let asset = AVURLAsset(url: URL(fileURLWithPath: ruta))
        guard let origen = try await asset.loadTracks(withMediaType: .video).first else {
            print("\(ruta): no tiene video")
            exit(1)
        }
        let completo = try await origen.load(.timeRange)
        let desde = await segundoConContenido(asset) + despues
        let rango = CMTimeRange(start: completo.start + CMTime(seconds: desde, preferredTimescale: 600), end: completo.end)
        if inicio == .zero { composicion.naturalSize = try await origen.load(.naturalSize) }
        try pista.insertTimeRange(rango, of: origen, at: inicio)
        inicio = inicio + rango.duration
    }

    // Sin composición de video: las grabaciones del simulador tienen cuadros solo cuando algo cambia, y con una
    // composición la exportación junta esos cuadros y se come los tramos quietos.
    let export = AVAssetExportSession(asset: composicion, presetName: AVAssetExportPresetHighestQuality)!
    try await export.export(to: salida, as: .mp4)
    let nuevo = AVURLAsset(url: salida)
    let tamano = try await nuevo.loadTracks(withMediaType: .video).first!.load(.naturalSize)
    print("\(args[1]): \(String(format: "%.1f", try await nuevo.load(.duration).seconds)) s, \(Int(tamano.width))×\(Int(tamano.height)), \(args.count - 2) videos")
}

Task {
    do {
        try await unir()
    } catch {
        print("Error: \(error)")
        exit(1)
    }
    sem.signal()
}
sem.wait()
