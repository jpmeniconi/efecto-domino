// Genera el ícono de la app: una escalera de Gantt sobre naranja casco.
// Uso: swift scripts/icono.swift EfectoDomino/Assets.xcassets/AppIcon.appiconset/icono.png
import AppKit

let lado = 1024
let salida = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icono.png"
let espacio = CGColorSpace(name: CGColorSpace.sRGB)!
let contexto = CGContext(
    data: nil, width: lado, height: lado, bitsPerComponent: 8, bytesPerRow: 0,
    space: espacio, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

// Origen arriba a la izquierda.
contexto.translateBy(x: 0, y: CGFloat(lado))
contexto.scaleBy(x: 1, y: -1)

let colores = [
    CGColor(srgbRed: 0.97, green: 0.55, blue: 0.24, alpha: 1),
    CGColor(srgbRed: 0.88, green: 0.30, blue: 0.10, alpha: 1),
] as CFArray
let gradiente = CGGradient(colorsSpace: espacio, colors: colores, locations: [0, 1])!
contexto.drawLinearGradient(gradiente, start: .zero, end: CGPoint(x: lado, y: lado), options: [])

// Tres bloques hechos y uno por venir, en escalera.
let alto: CGFloat = 104
let barras: [(x: CGFloat, y: CGFloat, ancho: CGFloat, opacidad: CGFloat?)] = [
    (168, 220, 340, 1.0),
    (312, 376, 300, 0.92),
    (456, 532, 330, 0.84),
    (600, 688, 256, nil),
]

for barra in barras {
    let rect = CGRect(x: barra.x, y: barra.y, width: barra.ancho, height: alto)
    if let opacidad = barra.opacidad {
        contexto.addPath(CGPath(roundedRect: rect, cornerWidth: alto / 2, cornerHeight: alto / 2, transform: nil))
        contexto.setFillColor(CGColor(gray: 1, alpha: opacidad))
        contexto.fillPath()
    } else {
        let borde = rect.insetBy(dx: 7, dy: 7)
        contexto.addPath(CGPath(roundedRect: borde, cornerWidth: borde.height / 2, cornerHeight: borde.height / 2, transform: nil))
        contexto.setStrokeColor(CGColor(gray: 1, alpha: 0.9))
        contexto.setLineWidth(14)
        contexto.strokePath()
    }
}

let imagen = contexto.makeImage()!
let png = NSBitmapImageRep(cgImage: imagen).representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: salida))
print("Ícono guardado en \(salida)")
