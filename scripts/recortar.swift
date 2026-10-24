import AVFoundation

// Uso: recortar.swift <entrada> <salida> <desde segundos>: quita el inicio y exporta H.264 a 1080 de ancho máximo.
let args = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let salida = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: salida)
let sem = DispatchSemaphore(value: 0)
Task {
    let dur = try await asset.load(.duration)
    let pista = try await asset.loadTracks(withMediaType: .video).first!
    let tamano = try await pista.load(.naturalSize)
    let desde = CMTime(seconds: Double(args[3])!, preferredTimescale: 600)
    let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)!
    export.timeRange = CMTimeRange(start: desde, end: dur)
    // Escala a 720 de ancho: suficiente para un proyector y liviano para la web.
    let escala = 720 / tamano.width
    let comp = AVMutableVideoComposition()
    comp.renderSize = CGSize(width: 720, height: (tamano.height * escala / 2).rounded() * 2)
    comp.frameDuration = CMTime(value: 1, timescale: 30)
    let instr = AVMutableVideoCompositionInstruction()
    instr.timeRange = CMTimeRange(start: .zero, end: dur)
    let capa = AVMutableVideoCompositionLayerInstruction(assetTrack: pista)
    capa.setTransform(CGAffineTransform(scaleX: escala, y: escala), at: .zero)
    instr.layerInstructions = [capa]
    comp.instructions = [instr]
    export.videoComposition = comp
    try await export.export(to: salida, as: .mp4)
    let nuevo = AVURLAsset(url: salida)
    print("\(args[2]): \(String(format: "%.1f", try await nuevo.load(.duration).seconds)) s, \(Int(comp.renderSize.width))×\(Int(comp.renderSize.height))")
    sem.signal()
}
sem.wait()
