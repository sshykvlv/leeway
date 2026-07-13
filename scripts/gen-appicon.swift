// Генератор иконки приложения: белый тайл + три вертикальных гейдж-бара
// (трек + заполнение снизу) — эхо менюбар-глифа IconRenderer (концепт A,
// выбор владельца 13.07: «А, но на белом фоне»). Пилюли графитовые,
// третья — янтарная «квота на исходе»: суть продукта в одном взгляде.
// Запуск: swift scripts/gen-appicon.swift → icon/AppIcon-1024.png
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no ctx") }

// Тайл: macOS-скругление ~22.6% стороны; белый с едва тёплым градиентом вниз,
// чтобы тайл не выглядел «дыркой» на светлых фонах.
let tile = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                        xRadius: size * 0.226, yRadius: size * 0.226)
tile.addClip()
let top = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1)
let bottom = NSColor(srgbRed: 0.945, green: 0.945, blue: 0.955, alpha: 1)
NSGradient(starting: top, ending: bottom)!.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

// Три бара: трек во всю рабочую высоту + заполнение снизу с круглыми капами.
struct Bar { let fill: CGFloat; let color: NSColor }
let graphite = NSColor(srgbRed: 0.145, green: 0.145, blue: 0.165, alpha: 1)
let bars: [Bar] = [
    Bar(fill: 0.78, color: graphite),                                                    // спокойный
    Bar(fill: 0.52, color: graphite),                                                    // рабочий
    Bar(fill: 0.24, color: NSColor(srgbRed: 1.00, green: 0.69, blue: 0.25, alpha: 1)),   // на исходе
]
let barW: CGFloat = size * 0.132
let gap: CGFloat = size * 0.096
let totalW = barW * 3 + gap * 2
let x0 = (size - totalW) / 2
let yPad: CGFloat = size * 0.24
let trackH = size - yPad * 2

for (i, bar) in bars.enumerated() {
    let x = x0 + CGFloat(i) * (barW + gap)
    // трек — едва заметный, задаёт «шкалу»
    let track = NSBezierPath(roundedRect: NSRect(x: x, y: yPad, width: barW, height: trackH),
                             xRadius: barW / 2, yRadius: barW / 2)
    NSColor(white: 0, alpha: 0.07).setFill()
    track.fill()
    // заполнение снизу; минимум = диаметр капа, чтобы форма оставалась пилюлей
    let h = max(barW, trackH * bar.fill)
    let fill = NSBezierPath(roundedRect: NSRect(x: x, y: yPad, width: barW, height: h),
                            xRadius: barW / 2, yRadius: barW / 2)
    bar.color.setFill()
    fill.fill()
}
_ = ctx // silence unused warning path
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("png fail") }
let out = URL(fileURLWithPath: "icon/AppIcon-1024.png")
try! FileManager.default.createDirectory(atPath: "icon", withIntermediateDirectories: true)
try! png.write(to: out)
print("written: \(out.path)")
