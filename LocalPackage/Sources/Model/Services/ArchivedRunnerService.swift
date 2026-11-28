/*
 ArchivedRunnerService.swift
 Model

 Created by Takuto Nakamura on 2026/11/28.
 Copyright 2026 Kyome22 (Takuto Nakamura)

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Compression
import DataSource
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ArchivedRunnerService {
    private let dataClient: DataClient
    private let fileManagerClient: FileManagerClient
    private let uuidClient: UUIDClient

    init(_ appDependencies: AppDependencies) {
        dataClient = appDependencies.dataClient
        fileManagerClient = appDependencies.fileManagerClient
        uuidClient = appDependencies.uuidClient
    }

    func unarchive(from url: URL, languageCode: String?) throws -> ArchivedRunner {
        let attributes = try fileManagerClient.attributesOfItem(url.path(percentEncoded: false))
        guard let fileSize = attributes[.size] as? Int, fileSize <= ArchivedRunner.maxFileSize else {
            throw RCNError.customRunner(.invalidRunnerArchive)
        }
        var entries = try ZIPReader(bytes: [UInt8](dataClient.read(url))).entries()
        guard let metadataData = entries.removeValue(forKey: ArchivedRunner.metadataEntryName),
              let metadata = try? JSONDecoder().decode(RunnerMetadata.self, from: metadataData),
              let runnerName = languageCode.flatMap({ metadata.displayName[$0] }) ?? metadata.displayName["en"] else {
            throw RCNError.customRunner(.invalidRunnerArchive)
        }
        let frameImages = try sortedFrameDataList(in: entries).map(makeFrameImage(from:))
        return ArchivedRunner(runnerName: runnerName, isTemplate: metadata.type.isTemplate, frameImages: frameImages)
    }

    private func sortedFrameDataList(in frameEntries: [String: Data]) throws -> [Data] {
        guard !frameEntries.isEmpty,
              frameEntries.keys.allSatisfy({ $0.wholeMatch(of: #/frames/[^/]+\.png/#) != nil }) else {
            throw RCNError.customRunner(.invalidRunnerArchive)
        }
        guard frameEntries.count <= FrameImage.maxCount else {
            throw RCNError.customRunner(.frameLimitExceeded)
        }
        return frameEntries
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            .map(\.value)
    }

    private func makeFrameImage(from data: Data) throws -> FrameImage {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(imageSource) as String? == UTType.png.identifier,
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
              cgImage.height == FrameImage.height,
              FrameImage.widthRange.contains(cgImage.width) else {
            throw RCNError.customRunner(.invalidFrameImage)
        }
        return FrameImage(id: uuidClient.create(), cgImage: cgImage)
    }
}

private struct ZIPReader {
    static let endRecordSignature = 0x06054b50
    static let centralDirectoryHeaderSignature = 0x02014b50
    static let localHeaderSignature = 0x04034b50
    static let endRecordSize = 22
    static let centralDirectoryHeaderSize = 46
    static let localHeaderSize = 30
    static let maxCommentLength = 0xFFFF
    static let encryptionFlags = 0x0041
    static let storedMethod = 0
    static let deflatedMethod = 8
    static let invalidArchive = RCNError.customRunner(.invalidRunnerArchive)

    let bytes: [UInt8]

    func entries() throws(RCNError) -> [String: Data] {
        let endRecordOffset = try findEndRecordOffset()
        let diskNumber = try uint16(at: endRecordOffset + 4)
        let centralDirectoryDiskNumber = try uint16(at: endRecordOffset + 6)
        let entryCountOnDisk = try uint16(at: endRecordOffset + 8)
        let entryCount = try uint16(at: endRecordOffset + 10)
        let centralDirectorySize = try uint32(at: endRecordOffset + 12)
        let centralDirectoryOffset = try uint32(at: endRecordOffset + 16)
        guard diskNumber == .zero,
              centralDirectoryDiskNumber == .zero,
              entryCountOnDisk == entryCount,
              entryCount <= ArchivedRunner.maxEntryCount,
              centralDirectoryOffset + centralDirectorySize == endRecordOffset else {
            throw Self.invalidArchive
        }
        var entries = [String: Data]()
        var offset = centralDirectoryOffset
        for _ in 0 ..< entryCount {
            let entry = try centralDirectoryEntry(at: offset)
            offset = entry.nextHeaderOffset
            guard !entry.name.hasSuffix("/") else { continue }
            guard entries[entry.name] == nil else {
                throw Self.invalidArchive
            }
            entries[entry.name] = try contents(of: entry)
        }
        return entries
    }

    private func findEndRecordOffset() throws(RCNError) -> Int {
        let lastCandidate = bytes.count - Self.endRecordSize
        let firstCandidate = max(.zero, lastCandidate - Self.maxCommentLength)
        guard lastCandidate >= .zero else {
            throw Self.invalidArchive
        }
        for offset in stride(from: lastCandidate, through: firstCandidate, by: -1) {
            guard try uint32(at: offset) == Self.endRecordSignature,
                  try offset + Self.endRecordSize + uint16(at: offset + 20) == bytes.count else { continue }
            return offset
        }
        throw Self.invalidArchive
    }

    private func centralDirectoryEntry(at offset: Int) throws(RCNError) -> Entry {
        guard try uint32(at: offset) == Self.centralDirectoryHeaderSignature else {
            throw Self.invalidArchive
        }
        let flags = try uint16(at: offset + 8)
        let method = try uint16(at: offset + 10)
        let compressedSize = try uint32(at: offset + 20)
        let uncompressedSize = try uint32(at: offset + 24)
        let nameLength = try uint16(at: offset + 28)
        let extraFieldLength = try uint16(at: offset + 30)
        let commentLength = try uint16(at: offset + 32)
        let localHeaderOffset = try uint32(at: offset + 42)
        let nameOffset = offset + Self.centralDirectoryHeaderSize
        guard let name = String(bytes: try slice(at: nameOffset, count: nameLength), encoding: .utf8),
              Self.isSafe(entryName: name),
              flags & Self.encryptionFlags == .zero,
              [Self.storedMethod, Self.deflatedMethod].contains(method),
              uncompressedSize <= ArchivedRunner.maxEntrySize else {
            throw Self.invalidArchive
        }
        return Entry(
            name: name,
            method: method,
            compressedSize: compressedSize,
            uncompressedSize: uncompressedSize,
            localHeaderOffset: localHeaderOffset,
            nextHeaderOffset: nameOffset + nameLength + extraFieldLength + commentLength
        )
    }

    private func contents(of entry: Entry) throws(RCNError) -> Data {
        guard try uint32(at: entry.localHeaderOffset) == Self.localHeaderSignature else {
            throw Self.invalidArchive
        }
        let nameLength = try uint16(at: entry.localHeaderOffset + 26)
        let extraFieldLength = try uint16(at: entry.localHeaderOffset + 28)
        let dataOffset = entry.localHeaderOffset + Self.localHeaderSize + nameLength + extraFieldLength
        let compressedBytes = try slice(at: dataOffset, count: entry.compressedSize)
        if entry.method == Self.storedMethod {
            guard entry.compressedSize == entry.uncompressedSize else {
                throw Self.invalidArchive
            }
            return Data(compressedBytes)
        }
        return try inflate(compressedBytes, expectedSize: entry.uncompressedSize)
    }

    private func inflate(_ compressedBytes: [UInt8], expectedSize: Int) throws(RCNError) -> Data {
        guard expectedSize > .zero else {
            return Data()
        }
        guard !compressedBytes.isEmpty else {
            throw Self.invalidArchive
        }
        var decompressedBytes = [UInt8](repeating: .zero, count: expectedSize + 1)
        let decompressedCount = compressedBytes.withUnsafeBufferPointer { source in
            decompressedBytes.withUnsafeMutableBufferPointer { destination in
                compression_decode_buffer(
                    destination.baseAddress!,
                    destination.count,
                    source.baseAddress!,
                    source.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decompressedCount == expectedSize else {
            throw Self.invalidArchive
        }
        return Data(decompressedBytes.prefix(expectedSize))
    }

    private func slice(at offset: Int, count: Int) throws(RCNError) -> [UInt8] {
        guard offset >= .zero, count >= .zero, offset + count <= bytes.count else {
            throw Self.invalidArchive
        }
        return Array(bytes[offset ..< offset + count])
    }

    private func uint16(at offset: Int) throws(RCNError) -> Int {
        try slice(at: offset, count: 2).reversed().reduce(.zero) { $0 << 8 | Int($1) }
    }

    private func uint32(at offset: Int) throws(RCNError) -> Int {
        try slice(at: offset, count: 4).reversed().reduce(.zero) { $0 << 8 | Int($1) }
    }

    private static func isSafe(entryName name: String) -> Bool {
        !name.isEmpty
            && !name.hasPrefix("/")
            && !name.contains("\\")
            && !name.contains("\0")
            && !name.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    private struct Entry {
        var name: String
        var method: Int
        var compressedSize: Int
        var uncompressedSize: Int
        var localHeaderOffset: Int
        var nextHeaderOffset: Int
    }
}
