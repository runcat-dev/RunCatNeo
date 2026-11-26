import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import DataSource

struct CGImageExtensionTests {
    @Test
    func pngData_returns_png_that_decodes_to_same_size() throws {
        let context = try #require(CGContext(
            data: nil,
            width: 20,
            height: 36,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let cgImage = try #require(context.makeImage())
        let imageSource = try #require(CGImageSourceCreateWithData(try cgImage.pngData() as CFData, nil))
        #expect(CGImageSourceGetType(imageSource) as String? == UTType.png.identifier)
        let decodedImage = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        #expect(decodedImage.width == 20)
        #expect(decodedImage.height == 36)
    }
}
