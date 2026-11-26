import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct CustomMetricsSourceEditorTests {
    private let snapshotJSON = #"{ "title": "Imported", "metrics": [], "lastUpdatedDate": "2026-06-05T04:50:40Z" }"#

    private func makeSource() -> CustomMetricsSource {
        CustomMetricsSource(
            id: UUID(1),
            displayName: "Imported",
            fileURL: URL(filePath: "/tmp/metrics.json"),
            bookmark: Data([0xAB]),
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private enum RecordedAction: Equatable {
        case customMetricsSourceAdded
        case errorOccurred(RCNError)
    }

    private func actionRecorder() -> (
        lock: AllocatedUnfairLock<[RecordedAction]>,
        action: (CustomMetricsSourceEditor.Action) async -> Void
    ) {
        let lock = AllocatedUnfairLock<[RecordedAction]>(initialState: [])
        let action: (CustomMetricsSourceEditor.Action) async -> Void = { action in
            switch action {
            case .customMetricsSourceAdded:
                lock.withLock { $0.append(.customMetricsSourceAdded) }
            case let .errorOccurred(error):
                lock.withLock { $0.append(.errorOccurred(error)) }
            default:
                break
            }
        }
        return (lock, action)
    }

    @MainActor @Test
    func canAdd_is_false_until_source_is_chosen() {
        let sut = CustomMetricsSourceEditor(.testDependencies(), id: UUID(0))
        #expect(!sut.canAdd)
        let chosen = CustomMetricsSourceEditor(.testDependencies(), id: UUID(0), source: makeSource())
        #expect(chosen.canAdd)
    }

    @MainActor @Test
    func previewBundle_combines_source_snapshot_and_symbol_image() {
        let snapshot = CustomMetricsSnapshot(title: "Imported", lastUpdatedDate: Date(timeIntervalSince1970: 0))
        let sut = CustomMetricsSourceEditor(
            .testDependencies(),
            id: UUID(0),
            source: makeSource(),
            snapshot: snapshot,
            symbolImageData: Data([0x01])
        )
        #expect(sut.previewBundle == CustomMetricsBundle(id: UUID(1), snapshot: snapshot, symbolImageData: Data([0x01])))
    }

    @MainActor @Test
    func send_chooseSourceButtonTapped_shows_source_file_importer() async {
        let sut = CustomMetricsSourceEditor(.testDependencies(), id: UUID(0))
        await sut.send(.chooseSourceButtonTapped)
        #expect(sut.showingSourceFileImporter)
    }

    @MainActor @Test
    func send_sourceFileImporterResponse_success_sets_source_and_snapshot() async throws {
        let sut = CustomMetricsSourceEditor(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.read = { _ in Data(snapshotJSON.utf8) }
                },
                urlClient: testDependency(of: URLClient.self) {
                    $0.startAccessingSecurityScopedResource = { _ in true }
                    $0.bookmarkData = { _, _ in Data([0xAB]) }
                }
            ),
            id: UUID(0)
        )
        await sut.send(.sourceFileImporterResponse(.success([URL(filePath: "/tmp/metrics.json")])))
        #expect(sut.source?.displayName == "Imported")
        #expect(sut.source?.bookmark == Data([0xAB]))
        #expect(sut.snapshot?.title == "Imported")
    }

    @MainActor @Test
    func send_sourceFileImporterResponse_forwards_error_when_json_is_invalid() async {
        let recorder = actionRecorder()
        let sut = CustomMetricsSourceEditor(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.read = { _ in Data("not json".utf8) }
                },
                urlClient: testDependency(of: URLClient.self) {
                    $0.startAccessingSecurityScopedResource = { _ in true }
                }
            ),
            id: UUID(0),
            action: recorder.action
        )
        await sut.send(.sourceFileImporterResponse(.success([URL(filePath: "/tmp/metrics.json")])))
        #expect(recorder.lock.withLock(\.self) == [.errorOccurred(.customMetrics(.invalidFormat))])
        #expect(sut.source == nil)
    }

    @MainActor @Test
    func send_sourceFileImporterResponse_success_without_url_is_noop() async {
        let sut = CustomMetricsSourceEditor(.testDependencies(), id: UUID(0))
        await sut.send(.sourceFileImporterResponse(.success([])))
        #expect(sut.source == nil)
        #expect(sut.snapshot == nil)
    }

    @MainActor @Test
    func send_removeSourceButtonTapped_clears_source_and_snapshot() async {
        let sut = CustomMetricsSourceEditor(
            .testDependencies(),
            id: UUID(0),
            source: makeSource(),
            snapshot: CustomMetricsSnapshot(title: "Imported", lastUpdatedDate: Date(timeIntervalSince1970: 0))
        )
        await sut.send(.removeSourceButtonTapped)
        #expect(sut.source == nil)
        #expect(sut.snapshot == nil)
        #expect(!sut.canAdd)
    }

    @MainActor @Test
    func send_symbolImageGuidanceButtonTapped_shows_symbol_image_guidance_popover() async {
        let sut = CustomMetricsSourceEditor(.testDependencies(), id: UUID(0))
        await sut.send(.symbolImageGuidanceButtonTapped)
        #expect(sut.showingSymbolImageGuidancePopover)
    }

    @MainActor @Test
    func send_chooseSymbolImageButtonTapped_shows_symbol_image_file_importer() async {
        let sut = CustomMetricsSourceEditor(.testDependencies(), id: UUID(0))
        await sut.send(.chooseSymbolImageButtonTapped)
        #expect(sut.showingSymbolImageFileImporter)
    }

    @MainActor @Test
    func send_symbolImageFileImporterResponse_success_sets_symbol_image_data() async {
        let imageData = Data.image(width: 48, height: 48)
        let sut = CustomMetricsSourceEditor(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.read = { _ in imageData }
                },
                urlClient: testDependency(of: URLClient.self) {
                    $0.startAccessingSecurityScopedResource = { _ in true }
                }
            ),
            id: UUID(0)
        )
        await sut.send(.symbolImageFileImporterResponse(.success([URL(filePath: "/tmp/symbol.png")])))
        #expect(sut.symbolImageData == imageData)
    }

    @MainActor @Test
    func send_symbolImageFileImporterResponse_forwards_error_and_keeps_previous_image_when_image_is_invalid() async {
        let recorder = actionRecorder()
        let sut = CustomMetricsSourceEditor(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.read = { _ in Data.image(width: 36, height: 36) }
                },
                urlClient: testDependency(of: URLClient.self) {
                    $0.startAccessingSecurityScopedResource = { _ in true }
                }
            ),
            id: UUID(0),
            symbolImageData: Data([0x01]),
            action: recorder.action
        )
        await sut.send(.symbolImageFileImporterResponse(.success([URL(filePath: "/tmp/symbol.png")])))
        #expect(recorder.lock.withLock(\.self) == [.errorOccurred(.customMetrics(.invalidSymbolImage))])
        #expect(sut.symbolImageData == Data([0x01]))
    }

    @MainActor @Test
    func send_removeSymbolImageButtonTapped_clears_symbol_image_data() async {
        let sut = CustomMetricsSourceEditor(.testDependencies(), id: UUID(0), symbolImageData: Data([0x01]))
        await sut.send(.removeSymbolImageButtonTapped)
        #expect(sut.symbolImageData == nil)
    }

    @MainActor @Test
    func send_addButtonTapped_persists_source_and_reports_customMetricsSourceAdded() async {
        let recorder = actionRecorder()
        let storage = UserDefaultsClient.storage()
        let sut = CustomMetricsSourceEditor(
            .testDependencies(userDefaultsClient: storage.client),
            id: UUID(0),
            source: makeSource(),
            action: recorder.action
        )
        await sut.send(.addButtonTapped)
        #expect(storage.currentConfiguration() == CustomMetricsConfiguration(sources: [makeSource()]))
        #expect(recorder.lock.withLock(\.self) == [.customMetricsSourceAdded])
    }

    @MainActor @Test
    func send_addButtonTapped_forwards_error_when_saving_symbol_image_fails() async {
        let recorder = actionRecorder()
        let storage = UserDefaultsClient.storage()
        let sut = CustomMetricsSourceEditor(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.write = { _, _ in throw URLError(.unknown) }
                },
                userDefaultsClient: storage.client
            ),
            id: UUID(0),
            source: makeSource(),
            symbolImageData: Data.image(width: 48, height: 48),
            action: recorder.action
        )
        await sut.send(.addButtonTapped)
        #expect(storage.currentConfiguration() == nil)
        #expect(recorder.lock.withLock(\.self) == [.errorOccurred(.customMetrics(.savingFailed))])
    }

    @MainActor @Test
    func send_addButtonTapped_without_source_is_noop() async {
        let recorder = actionRecorder()
        let storage = UserDefaultsClient.storage()
        let sut = CustomMetricsSourceEditor(
            .testDependencies(userDefaultsClient: storage.client),
            id: UUID(0),
            action: recorder.action
        )
        await sut.send(.addButtonTapped)
        #expect(storage.currentConfiguration() == nil)
        #expect(recorder.lock.withLock(\.self).isEmpty)
    }

    @MainActor @Test
    func send_errorOccurred_shows_alert() async {
        let sut = CustomMetricsSourceEditor(.testDependencies(), id: UUID(0))
        await sut.send(.errorOccurred(.customMetrics(.invalidSymbolImage)))
        #expect(sut.error == .customMetrics(.invalidSymbolImage))
        #expect(sut.showingAlert)
    }
}
