import AppKit
import SwiftUI

// Rendert das Logo als 1024×1024-PNG: Icon <ausgabe.png>
MainActor.assumeIsolated {
    _ = NSApplication.shared
    let out = CommandLine.arguments[1]
    let renderer = ImageRenderer(content: AppIconView(size: 1024))
    renderer.scale = 1
    guard let cg = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
        fatalError("Rendern fehlgeschlagen")
    }
    try! png.write(to: URL(fileURLWithPath: out))
    print("Logo: \(out)")
}
