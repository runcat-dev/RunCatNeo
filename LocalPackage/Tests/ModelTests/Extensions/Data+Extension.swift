import Compression
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension Data {
    static func image(width: Int, height: Int, hasAlpha: Bool = true, type: UTType = .png) -> Data {
        let alphaInfo: CGImageAlphaInfo = hasAlpha ? .premultipliedLast : .noneSkipLast
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: alphaInfo.rawValue
        )!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

struct ZIPFixtureEntry {
    var name: String
    var contents: Data
    var isDeflated = false
    var flags: UInt16 = .zero
    var method: UInt16?
    var declaredUncompressedSize: Int?
}

extension Data {
    static func zipArchive(_ entries: [ZIPFixtureEntry]) -> Data {
        var localSection = Data()
        var centralDirectory = Data()
        for entry in entries {
            let nameData = Data(entry.name.utf8)
            let storedContents = entry.isDeflated ? deflated(entry.contents) : entry.contents
            let method = entry.method ?? (entry.isDeflated ? 8 : .zero)
            let uncompressedSize = UInt32(entry.declaredUncompressedSize ?? entry.contents.count)
            let localHeaderOffset = UInt32(localSection.count)
            localSection.appendLittleEndian(UInt32(0x04034b50))
            localSection.appendLittleEndian(UInt16(20))
            localSection.appendLittleEndian(entry.flags)
            localSection.appendLittleEndian(method)
            localSection.appendLittleEndian(UInt32.zero)
            localSection.appendLittleEndian(UInt32.zero)
            localSection.appendLittleEndian(UInt32(storedContents.count))
            localSection.appendLittleEndian(uncompressedSize)
            localSection.appendLittleEndian(UInt16(nameData.count))
            localSection.appendLittleEndian(UInt16.zero)
            localSection.append(nameData)
            localSection.append(storedContents)
            centralDirectory.appendLittleEndian(UInt32(0x02014b50))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(entry.flags)
            centralDirectory.appendLittleEndian(method)
            centralDirectory.appendLittleEndian(UInt32.zero)
            centralDirectory.appendLittleEndian(UInt32.zero)
            centralDirectory.appendLittleEndian(UInt32(storedContents.count))
            centralDirectory.appendLittleEndian(uncompressedSize)
            centralDirectory.appendLittleEndian(UInt16(nameData.count))
            centralDirectory.appendLittleEndian(UInt16.zero)
            centralDirectory.appendLittleEndian(UInt16.zero)
            centralDirectory.appendLittleEndian(UInt16.zero)
            centralDirectory.appendLittleEndian(UInt16.zero)
            centralDirectory.appendLittleEndian(UInt32.zero)
            centralDirectory.appendLittleEndian(localHeaderOffset)
            centralDirectory.append(nameData)
        }
        var archive = localSection
        archive.append(centralDirectory)
        archive.appendLittleEndian(UInt32(0x06054b50))
        archive.appendLittleEndian(UInt16.zero)
        archive.appendLittleEndian(UInt16.zero)
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt32(centralDirectory.count))
        archive.appendLittleEndian(UInt32(localSection.count))
        archive.appendLittleEndian(UInt16.zero)
        return archive
    }

    static func runnerMetadata(type: String = "monochrome", displayName: String = #"{"en": "Tester", "ja": "テスター"}"#) -> Data {
        Data(#"{"author": "Tester", "displayName": \#(displayName), "type": "\#(type)", "tags": []}"#.utf8)
    }

    private static func deflated(_ data: Data) -> Data {
        let source = [UInt8](data)
        var destination = [UInt8](repeating: .zero, count: source.count + 1024)
        let count = compression_encode_buffer(&destination, destination.count, source, source.count, nil, COMPRESSION_ZLIB)
        return Data(destination.prefix(count))
    }

    private mutating func appendLittleEndian<Value: FixedWidthInteger>(_ value: Value) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
