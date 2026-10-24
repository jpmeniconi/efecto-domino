import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Dos vistas del mismo estado: invitación y bloque reubicado en el programa.
// Uso desde la raíz: swift scripts/clip-semana.swift
// No abre el simulador ni cambia datos de la app. Solo regenera los tres medios de la lámina.
let raiz = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let medios = raiz.appendingPathComponent("presentacion/medios")
let lienzo = CGSize(width: 720, height: 1564)
let semaforo = DispatchSemaphore(value: 0)

func tiempo(_ segundos: Double) -> CMTime { CMTime(seconds: segundos, preferredTimescale: 600) }

func encuadre(_ tamano: CGSize) -> CGAffineTransform {
    // Conserva las proporciones de la fuente y centra cualquier recorte mínimo.
    let escala = max(lienzo.width / tamano.width, lienzo.height / tamano.height)
    return CGAffineTransform(a: escala, b: 0, c: 0, d: escala,
                            tx: (lienzo.width - tamano.width * escala) / 2,
                            ty: (lienzo.height - tamano.height * escala) / 2)
}

func poster(_ asset: AVAsset, segundo: Double, nombre: String) async throws {
    let generador = AVAssetImageGenerator(asset: asset)
    generador.appliesPreferredTrackTransform = true
    generador.requestedTimeToleranceBefore = .zero
    generador.requestedTimeToleranceAfter = .zero
    let resultado = try await generador.image(at: tiempo(segundo))
    let imagen = resultado.image
    let contexto = CGContext(data: nil, width: 720, height: 1564, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    contexto.concatenate(encuadre(CGSize(width: imagen.width, height: imagen.height)))
    contexto.interpolationQuality = .high
    contexto.draw(imagen, in: CGRect(x: 0, y: 0, width: imagen.width, height: imagen.height))
    let destino = CGImageDestinationCreateWithURL(medios.appendingPathComponent(nombre).appendingPathExtension("png") as CFURL,
                                                UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destino, contexto.makeImage()!, nil)
    guard CGImageDestinationFinalize(destino) else { throw NSError(domain: "ClipSemana", code: 1) }
    print("\(nombre).png: 720 × 1564; origen \(segundo) s")
}

Task.detached {
    defer { semaforo.signal() }
    do {
        let miercoles = AVURLAsset(url: medios.appendingPathComponent("demo-miercoles.mp4"))
        let programa = AVURLAsset(url: medios.appendingPathComponent("demo-programa.mp4"))
        let composicion = AVMutableComposition()
        let pista = composicion.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let partes: [(AVAsset, Double, Double, Double)] = [
            (miercoles, 9.64, 12.85, 0),
            (programa, 0.40, 1.80, 4)
        ]
        var instrucciones: [AVVideoCompositionInstructionProtocol] = []
        for (asset, desde, hasta, comienzo) in partes {
            let origen = try await asset.loadTracks(withMediaType: .video).first!
            let tramo = CMTimeRange(start: tiempo(desde), end: tiempo(hasta))
            try pista.insertTimeRange(tramo, of: origen, at: tiempo(comienzo))
            pista.scaleTimeRange(CMTimeRange(start: tiempo(comienzo), duration: tramo.duration), toDuration: tiempo(4))
            let tamano = try await origen.load(.naturalSize)
            let orientacion = try await origen.load(.preferredTransform)
            let instruccion = AVMutableVideoCompositionInstruction()
            instruccion.timeRange = CMTimeRange(start: tiempo(comienzo), duration: tiempo(4))
            let capa = AVMutableVideoCompositionLayerInstruction(assetTrack: pista)
            capa.setTransform(orientacion.concatenating(encuadre(tamano)), at: tiempo(comienzo))
            instruccion.layerInstructions = [capa]
            instrucciones.append(instruccion)
        }
        let video = AVMutableVideoComposition()
        video.renderSize = lienzo
        video.frameDuration = CMTime(value: 1, timescale: 30)
        video.instructions = instrucciones
        let salida = medios.appendingPathComponent("semana-recorrido.mp4")
        try? FileManager.default.removeItem(at: salida)
        let exportador = AVAssetExportSession(asset: composicion, presetName: AVAssetExportPresetHighestQuality)!
        exportador.videoComposition = video
        exportador.shouldOptimizeForNetworkUse = true
        try await exportador.export(to: salida, as: .mp4)
        try await poster(miercoles, segundo: 11.565, nombre: "semana-invitar")
        try await poster(programa, segundo: 1.510, nombre: "semana-reubicacion")

        let final = AVURLAsset(url: salida)
        let duracion = try await final.load(.duration).seconds
        let videoFinal = try await final.loadTracks(withMediaType: .video).first!
        let tamanoFinal = try await videoFinal.load(.naturalSize)
        let sonido = try await final.loadTracks(withMediaType: .audio)
        let formato = try await videoFinal.load(.formatDescriptions).first!
        let codigo = CMFormatDescriptionGetMediaSubType(formato)
        let codec = String(bytes: [24, 16, 8, 0].map { UInt8((codigo >> $0) & 255) }, encoding: .ascii)!
        print("Salida: \(duracion) s; \(tamanoFinal); codec \(codec); pistas audio \(sonido.count)")
        // AVFoundation puede cerrar la exportación un fotograma antes del final nominal.
        guard abs(duracion - 8) <= 1.0 / 30.0 + 0.001, tamanoFinal == lienzo, sonido.isEmpty, codec == "avc1" else {
            throw NSError(domain: "ClipSemana", code: 2, userInfo: [NSLocalizedDescriptionKey: "Formato exportado inesperado"])
        }
        print("semana-recorrido.mp4: \(duracion) s; corte 4.000 s; \(Int(tamanoFinal.width)) × \(Int(tamanoFinal.height)); \(codec); sin audio")
    } catch {
        fputs("Error al crear los medios: \(error)\n", stderr)
        exit(1)
    }
}
semaforo.wait()
