import AppKit

struct SampledPixel: Sendable {
    var redComponent: CGFloat
    var greenComponent: CGFloat
    var blueComponent: CGFloat
    var alphaComponent: CGFloat
}

extension NSImage {
    @MainActor
    func sampleColor(x: Int, y: Int) -> SampledPixel {
        let pixelWidth = Int(size.width.rounded())
        let pixelHeight = Int(size.height.rounded())
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw(in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        NSGraphicsContext.restoreGraphicsState()
        let bytesPerRow = rep.bytesPerRow
        let data = rep.bitmapData!
        let offset = y * bytesPerRow + x * 4
        return SampledPixel(
            redComponent: CGFloat(data[offset]) / 255,
            greenComponent: CGFloat(data[offset + 1]) / 255,
            blueComponent: CGFloat(data[offset + 2]) / 255,
            alphaComponent: CGFloat(data[offset + 3]) / 255
        )
    }
}
