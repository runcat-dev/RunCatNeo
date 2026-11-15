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
        let sampled = image.sampleColor(x: 1, y: 9)
        #expect(sampled.redComponent > sampled.blueComponent + 0.5)
    }

    @Test
    func resize_with_trailing_alignment_keeps_right_pixels() {
        let image = loadFixture(name: "half_red_blue_30x18")
        image.resize(width: 10, alignment: .trailing)
        let sampled = image.sampleColor(x: 8, y: 9)
        #expect(sampled.blueComponent > sampled.redComponent + 0.5)
    }

    @Test
    func resize_with_center_alignment_pads_symmetrically() {
        let image = loadFixture(name: "solid_red_10x18")
        image.resize(width: 20, alignment: .center)
        let leftPad = image.sampleColor(x: 0, y: 9)
        let middle = image.sampleColor(x: 10, y: 9)
        let rightPad = image.sampleColor(x: 19, y: 9)
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
        let leftPad = image.sampleColor(x: 0, y: 9)
        let middle = image.sampleColor(x: 10, y: 9)
        #expect(leftPad.alphaComponent < 0.1)
        #expect(middle.blueComponent > 0.9)
        #expect(middle.redComponent < 0.1)
        #expect(middle.alphaComponent > 0.9)
    }

    @Test
    func tint_with_nil_is_noop() {
        let image = loadFixture(name: "solid_red_10x18")
        image.tint(with: nil)
        let middle = image.sampleColor(x: 5, y: 9)
        #expect(middle.redComponent > 0.9)
    }
}

@MainActor
private func loadFixture(name: String) -> NSImage {
    let url = Bundle.module.url(forResource: name, withExtension: "png")!
    return NSImage(contentsOf: url)!
}
