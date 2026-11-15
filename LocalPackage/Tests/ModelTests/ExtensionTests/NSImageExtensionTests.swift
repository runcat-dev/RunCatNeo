import AppKit
import Testing

@testable import Model

@MainActor
struct NSImageExtensionTests {
    @Test
    func resize_widens_canvas_and_updates_size() {
        let image = loadFixture(name: "solid_red_10x18")
        image.resize(width: 20)
        #expect(image.size == CGSize(width: 20, height: 18))
    }

    @Test
    func resize_narrower_updates_size() {
        let image = loadFixture(name: "half_red_blue_30x18")
        image.resize(width: 10)
        #expect(image.size == CGSize(width: 10, height: 18))
    }

    @Test
    func resize_with_leading_alignment_keeps_left_pixels() {
        let image = loadFixture(name: "half_red_blue_30x18")
        image.resize(width: 10, alignment: .leading)
        let sampled = sampleColor(image: image, x: 1, y: 9)
        #expect(sampled.redComponent > sampled.blueComponent + 0.5)
    }

    @Test
    func resize_with_trailing_alignment_keeps_right_pixels() {
        let image = loadFixture(name: "half_red_blue_30x18")
        image.resize(width: 10, alignment: .trailing)
        let sampled = sampleColor(image: image, x: 8, y: 9)
        #expect(sampled.blueComponent > sampled.redComponent + 0.5)
    }

    @Test
    func resize_with_center_alignment_pads_symmetrically() {
        let image = loadFixture(name: "solid_red_10x18")
        image.resize(width: 20, alignment: .center)
        let leftPad = sampleColor(image: image, x: 0, y: 9)
        let middle = sampleColor(image: image, x: 10, y: 9)
        let rightPad = sampleColor(image: image, x: 19, y: 9)
        #expect(leftPad.alphaComponent < 0.1)
        #expect(middle.redComponent > 0.9)
        #expect(middle.alphaComponent > 0.9)
        #expect(rightPad.alphaComponent < 0.1)
    }

    @Test
    func resize_zero_width_is_noop() {
        let image = loadFixture(name: "solid_red_10x18")
        let originalSize = image.size
        image.resize(width: 0)
        #expect(image.size == originalSize)
    }

    @Test
    func resize_zero_height_image_is_noop() {
        let image = NSImage(size: .zero)
        image.resize(width: 20)
        #expect(image.size == .zero)
    }

    @Test
    func tint_fills_opaque_pixels_and_keeps_transparent_pixels() {
        let image = loadFixture(name: "solid_red_10x18")
        image.resize(width: 20, alignment: .center)
        image.tint(with: CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        let leftPad = sampleColor(image: image, x: 0, y: 9)
        let middle = sampleColor(image: image, x: 10, y: 9)
        #expect(leftPad.alphaComponent < 0.1)
        #expect(middle.blueComponent > 0.9)
        #expect(middle.redComponent < 0.1)
        #expect(middle.alphaComponent > 0.9)
    }

    @Test
    func tint_with_nil_is_noop() {
        let image = loadFixture(name: "solid_red_10x18")
        image.tint(with: nil)
        let middle = sampleColor(image: image, x: 5, y: 9)
        #expect(middle.redComponent > 0.9)
    }
}

@MainActor
private func loadFixture(name: String) -> NSImage {
    let url = Bundle.module.url(forResource: name, withExtension: "png")!
    return NSImage(contentsOf: url)!
}

struct SampledPixel {
    var redComponent: CGFloat
    var greenComponent: CGFloat
    var blueComponent: CGFloat
    var alphaComponent: CGFloat
}

@MainActor
private func sampleColor(image: NSImage, x: Int, y: Int) -> SampledPixel {
    let pixelWidth = Int(image.size.width.rounded())
    let pixelHeight = Int(image.size.height.rounded())
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
    image.draw(in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
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
