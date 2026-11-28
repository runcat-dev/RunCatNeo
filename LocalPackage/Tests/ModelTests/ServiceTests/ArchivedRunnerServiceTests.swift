import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct ArchivedRunnerServiceTests {
    private let archiveURL = URL(filePath: "/tmp/tester.zip")

    private func archivedRunnerService(reading archive: Data, fileSize: Int? = nil) -> ArchivedRunnerService {
        ArchivedRunnerService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in archive }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.attributesOfItem = { _ in [.size: fileSize ?? archive.count] }
            }
        ))
    }

    private func metadataEntry(type: String = "monochrome") -> ZIPFixtureEntry {
        ZIPFixtureEntry(name: "metadata.json", contents: Data.runnerMetadata(type: type))
    }

    private func frameEntries(widths: [Int]) -> [ZIPFixtureEntry] {
        widths.enumerated().map { index, width in
            ZIPFixtureEntry(name: "frames/tester-frame-\(index).png", contents: Data.image(width: width, height: 36))
        }
    }

    @Test(arguments: [
        ("ja", "トリ"),
        ("en", "Bird"),
        ("xx", "Bird"),
        (nil, "Bird"),
    ] as [(String?, String)])
    func unarchive_reads_gallery_zip_in_requested_language(languageCode: String?, runnerName: String) throws {
        let sut = archivedRunnerService(reading: try Data(contentsOf: URL.fixture(name: "bird", fileExtension: "zip")))
        let archivedRunner = try sut.unarchive(from: archiveURL, languageCode: languageCode)
        #expect(archivedRunner.runnerName == runnerName)
        #expect(archivedRunner.isTemplate)
        #expect(archivedRunner.frameImages.map(\.cgImage.width) == [32, 32, 32, 32, 32])
    }

    @Test
    func unarchive_sorts_frames_in_localized_standard_order() throws {
        let widths = Array(10 ... 21)
        let archive = Data.zipArchive([metadataEntry(type: "color")] + frameEntries(widths: widths).reversed())
        let archivedRunner = try archivedRunnerService(reading: archive).unarchive(from: archiveURL, languageCode: "en")
        #expect(!archivedRunner.isTemplate)
        #expect(archivedRunner.frameImages.map(\.cgImage.width) == widths)
    }

    @Test
    func unarchive_reads_deflated_entries_and_skips_directory_entries() throws {
        let archive = Data.zipArchive([
            ZIPFixtureEntry(name: "metadata.json", contents: Data.runnerMetadata(), isDeflated: true),
            ZIPFixtureEntry(name: "frames/", contents: Data()),
            ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36), isDeflated: true),
        ])
        let archivedRunner = try archivedRunnerService(reading: archive).unarchive(from: archiveURL, languageCode: "ja")
        #expect(archivedRunner.runnerName == "テスター")
        #expect(archivedRunner.frameImages.map(\.cgImage.width) == [30])
    }

    @Test
    func unarchive_throws_invalidRunnerArchive_without_reading_when_file_exceeds_size_limit() {
        let readCount = AllocatedUnfairLock(initialState: 0)
        let sut = ArchivedRunnerService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in
                    readCount.withLock { $0 += 1 }
                    return Data()
                }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.attributesOfItem = { _ in [.size: ArchivedRunner.maxFileSize + 1] }
            }
        ))
        #expect(throws: RCNError.customRunner(.invalidRunnerArchive)) {
            try sut.unarchive(from: archiveURL, languageCode: "en")
        }
        #expect(readCount.withLock(\.self) == 0)
    }

    @Test(arguments: [
        ("not a zip", Data("not a zip archive".utf8)),
        ("missing metadata", Data.zipArchive([
            ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36)),
        ])),
        ("unknown type", Data.zipArchive([
            ZIPFixtureEntry(name: "metadata.json", contents: Data.runnerMetadata(type: "rainbow")),
            ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36)),
        ])),
        ("missing English name", Data.zipArchive([
            ZIPFixtureEntry(name: "metadata.json", contents: Data.runnerMetadata(displayName: #"{"ja": "テスター"}"#)),
            ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36)),
        ])),
        ("no frames", Data.zipArchive([
            ZIPFixtureEntry(name: "metadata.json", contents: Data.runnerMetadata()),
        ])),
        ("extra entry", Data.zipArchive([
            ZIPFixtureEntry(name: "metadata.json", contents: Data.runnerMetadata()),
            ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36)),
            ZIPFixtureEntry(name: "preview.png", contents: Data.image(width: 30, height: 36)),
        ])),
        ("nested folder", Data.zipArchive([
            ZIPFixtureEntry(name: "tester/metadata.json", contents: Data.runnerMetadata()),
            ZIPFixtureEntry(name: "tester/frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36)),
        ])),
        ("duplicate entry", Data.zipArchive([
            ZIPFixtureEntry(name: "metadata.json", contents: Data.runnerMetadata()),
            ZIPFixtureEntry(name: "metadata.json", contents: Data.runnerMetadata()),
            ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36)),
        ])),
    ])
    func unarchive_throws_invalidRunnerArchive_when_archive_is_not_gallery_format(_ label: String, archive: Data) {
        #expect(throws: RCNError.customRunner(.invalidRunnerArchive), "\(label)") {
            try archivedRunnerService(reading: archive).unarchive(from: archiveURL, languageCode: "en")
        }
    }

    @Test(arguments: [
        ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36), flags: 0x0001),
        ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36), method: 12),
        ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36), isDeflated: true, declaredUncompressedSize: 10),
        ZIPFixtureEntry(name: "frames/../frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36)),
        ZIPFixtureEntry(name: "/frames/tester-frame-0.png", contents: Data.image(width: 30, height: 36)),
        ZIPFixtureEntry(name: "frames\\tester-frame-0.png", contents: Data.image(width: 30, height: 36)),
    ])
    func unarchive_throws_invalidRunnerArchive_when_frame_entry_is_unreadable(frameEntry: ZIPFixtureEntry) {
        let archive = Data.zipArchive([metadataEntry(), frameEntry])
        #expect(throws: RCNError.customRunner(.invalidRunnerArchive)) {
            try archivedRunnerService(reading: archive).unarchive(from: archiveURL, languageCode: "en")
        }
    }

    @Test
    func unarchive_throws_invalidRunnerArchive_when_archive_is_truncated() {
        let archive = Data.zipArchive([metadataEntry()] + frameEntries(widths: [30]))
        #expect(throws: RCNError.customRunner(.invalidRunnerArchive)) {
            try archivedRunnerService(reading: archive.dropLast(10)).unarchive(from: archiveURL, languageCode: "en")
        }
    }

    @Test
    func unarchive_throws_invalidRunnerArchive_when_archive_is_zip64() {
        var archive = Data.zipArchive([metadataEntry()] + frameEntries(widths: [30]))
        let entryCountOffset = archive.count - 22 + 10
        archive.replaceSubrange(entryCountOffset ..< entryCountOffset + 2, with: [0xFF, 0xFF])
        #expect(throws: RCNError.customRunner(.invalidRunnerArchive)) {
            try archivedRunnerService(reading: archive).unarchive(from: archiveURL, languageCode: "en")
        }
    }

    @Test
    func unarchive_throws_invalidRunnerArchive_when_entry_count_exceeds_limit() {
        let archive = Data.zipArchive([metadataEntry()] + frameEntries(widths: Array(repeating: 30, count: ArchivedRunner.maxEntryCount)))
        #expect(throws: RCNError.customRunner(.invalidRunnerArchive)) {
            try archivedRunnerService(reading: archive).unarchive(from: archiveURL, languageCode: "en")
        }
    }

    @Test
    func unarchive_throws_invalidRunnerArchive_when_entry_expands_beyond_limit() {
        let archive = Data.zipArchive([
            metadataEntry(),
            ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: Data(count: ArchivedRunner.maxEntrySize + 1), isDeflated: true),
        ])
        #expect(throws: RCNError.customRunner(.invalidRunnerArchive)) {
            try archivedRunnerService(reading: archive).unarchive(from: archiveURL, languageCode: "en")
        }
    }

    @Test(arguments: [
        Data.image(width: 10, height: 18),
        Data.image(width: 101, height: 36),
        Data.image(width: 30, height: 36, type: .jpeg),
    ])
    func unarchive_throws_invalidFrameImage_when_frame_violates_requirements(frame: Data) {
        let archive = Data.zipArchive([
            metadataEntry(),
            ZIPFixtureEntry(name: "frames/tester-frame-0.png", contents: frame),
        ])
        #expect(throws: RCNError.customRunner(.invalidFrameImage)) {
            try archivedRunnerService(reading: archive).unarchive(from: archiveURL, languageCode: "en")
        }
    }

    @Test
    func unarchive_throws_frameLimitExceeded_when_archive_has_too_many_frames() {
        let archive = Data.zipArchive([metadataEntry()] + frameEntries(widths: Array(repeating: 30, count: FrameImage.maxCount + 1)))
        #expect(throws: RCNError.customRunner(.frameLimitExceeded)) {
            try archivedRunnerService(reading: archive).unarchive(from: archiveURL, languageCode: "en")
        }
    }
}
