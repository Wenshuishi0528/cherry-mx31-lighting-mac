import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16,32,64,128,256,512,1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = Double(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    NSColor(calibratedRed: 0.95, green: 0.94, blue: 0.92, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 50,y: 50,width: 924,height: 924), xRadius: 205,yRadius: 205).fill()
    NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.18, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 138,y: 285,width: 748,height: 455), xRadius: 65,yRadius: 65).fill()
    for row in 0..<4 {
        for column in 0..<9 {
            if row == 0 && (2...6).contains(column) { continue }
            NSColor(calibratedHue: Double(column)/12 + 0.03, saturation: 0.48, brightness: 0.96, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 187 + column * 74, y: 341 + row * 91, width: 56, height: 65), xRadius: 12, yRadius: 12).fill()
        }
    }
    NSColor(calibratedRed: 0.94,green: 0.69,blue: 0.74,alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 335,y: 341,width: 352,height: 65), xRadius: 12,yRadius: 12).fill()
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(size).png"))
}
