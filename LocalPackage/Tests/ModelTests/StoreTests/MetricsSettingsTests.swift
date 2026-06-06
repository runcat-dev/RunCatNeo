import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct MetricsSettingsTests {
    @MainActor @Test
    func send_task_reloads_customMetricsSources_from_user_defaults() async {
        let storage = makeStorage(initialSources: [
            CustomMetricsSource(
                id: UUID(1),
                displayName: "Existing",
                fileURL: URL(filePath: "/tmp/existing.json"),
                bookmark: Data([0x42]),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let sut = MetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsSettingsTests"))
        #expect(sut.customMetricsSources.count == 1)
        #expect(sut.customMetricsSources.first?.displayName == "Existing")
    }

    @MainActor @Test
    func send_addCustomMetricsSourceButtonTapped_shows_file_importer() async {
        let sut = MetricsSettings(.testDependencies())
        await sut.send(.addCustomMetricsSourceButtonTapped)
        #expect(sut.showingFileImporter == true)
    }

    @MainActor @Test
    func send_onCompletionFileImporter_success_appends_source_and_emits_change() async throws {
        let storage = makeStorage()
        let emittedChange = AllocatedUnfairLock<Int>(initialState: 0)
        let appStateClient = AppStateClient.testDependency(.init(initialState: .init()))
        Task {
            let stream = appStateClient.withLock(\.customMetricsConfigurationChanges.stream)
            for await _ in stream {
                emittedChange.withLock { $0 += 1 }
            }
        }
        let fileURL = URL(filePath: NSTemporaryDirectory())
            .appending(path: "metrics-\(UUID().uuidString).json")
        let json = #"{ "title": "Imported", "metrics": [], "lastUpdatedDate": "2026-06-05T04:50:40Z" }"#
        try json.write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let urlClient = testDependency(of: URLClient.self) {
            $0.startAccessingSecurityScopedResource = { _ in true }
            $0.stopAccessingSecurityScopedResource = { _ in }
            $0.bookmarkData = { _, _ in Data([0xAB]) }
        }
        let sut = MetricsSettings(.testDependencies(
            appStateClient: appStateClient,
            urlClient: urlClient,
            userDefaultsClient: storage.client
        ))
        await sut.send(.onCompletionFileImporter(.success(fileURL)))
        #expect(sut.customMetricsSources.count == 1)
        #expect(sut.customMetricsSources.first?.displayName == "Imported")
        #expect(sut.customMetricsSources.first?.bookmark == Data([0xAB]))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(emittedChange.withLock(\.self) >= 1)
    }

    @MainActor @Test
    func send_onCompletionFileImporter_failure_does_not_throw() async {
        struct DummyError: Error {}
        let storage = makeStorage()
        let sut = MetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.onCompletionFileImporter(.failure(DummyError())))
        #expect(sut.customMetricsSources.isEmpty)
    }

    @MainActor @Test
    func send_removeCustomMetricsSourceButtonTapped_marks_pending_and_shows_dialog() async {
        let existingID = UUID(2)
        let storage = makeStorage(initialSources: [
            CustomMetricsSource(
                id: existingID,
                displayName: "Pending",
                fileURL: URL(filePath: "/tmp/pending.json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let sut = MetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsSettingsTests"))
        await sut.send(.removeCustomMetricsSourceButtonTapped(existingID))
        #expect(sut.pendingRemovalSourceID == existingID)
        #expect(sut.showingConfirmationDialog == true)
        #expect(sut.customMetricsSources.count == 1)
    }

    @MainActor @Test
    func send_removingCustomMetricsSourceConfirmed_removes_pending_source() async {
        let existingID = UUID(3)
        let storage = makeStorage(initialSources: [
            CustomMetricsSource(
                id: existingID,
                displayName: "Doomed",
                fileURL: URL(filePath: "/tmp/doomed.json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let sut = MetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsSettingsTests"))
        await sut.send(.removeCustomMetricsSourceButtonTapped(existingID))
        await sut.send(.removingCustomMetricsSourceConfirmed)
        #expect(sut.customMetricsSources.isEmpty)
        #expect(sut.pendingRemovalSourceID == nil)
    }

    @MainActor @Test
    func send_removingCustomMetricsSourceConfirmed_with_no_pending_is_noop() async {
        let existingID = UUID(4)
        let storage = makeStorage(initialSources: [
            CustomMetricsSource(
                id: existingID,
                displayName: "Safe",
                fileURL: URL(filePath: "/tmp/safe.json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let sut = MetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsSettingsTests"))
        await sut.send(.removingCustomMetricsSourceConfirmed)
        #expect(sut.customMetricsSources.count == 1)
    }

    @MainActor @Test
    func send_removingCustomMetricsSourceCancelled_clears_pending_without_removing() async {
        let existingID = UUID(5)
        let storage = makeStorage(initialSources: [
            CustomMetricsSource(
                id: existingID,
                displayName: "Spared",
                fileURL: URL(filePath: "/tmp/spared.json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let sut = MetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsSettingsTests"))
        await sut.send(.removeCustomMetricsSourceButtonTapped(existingID))
        await sut.send(.removingCustomMetricsSourceCancelled)
        #expect(sut.pendingRemovalSourceID == nil)
        #expect(sut.customMetricsSources.count == 1)
    }

    @MainActor @Test
    func send_customMetricsSourceLinkTapped_activates_file_viewer_with_resolved_url() async {
        let resolvedURL = URL(filePath: "/tmp/resolved.json")
        let activatedURLs = AllocatedUnfairLock<[URL]>(initialState: [])
        let source = CustomMetricsSource(
            id: UUID(6),
            displayName: "Linked",
            fileURL: URL(filePath: "/tmp/linked.json"),
            bookmark: Data([0xAA]),
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let urlClient = testDependency(of: URLClient.self) {
            $0.create = { _, _ in (false, resolvedURL) }
            $0.startAccessingSecurityScopedResource = { _ in true }
            $0.stopAccessingSecurityScopedResource = { _ in }
        }
        let nsWorkspaceClient = testDependency(of: NSWorkspaceClient.self) {
            $0.activateFileViewerSelecting = { urls in
                activatedURLs.withLock { $0 = urls }
            }
        }
        let sut = MetricsSettings(.testDependencies(
            nsWorkspaceClient: nsWorkspaceClient,
            urlClient: urlClient
        ))
        await sut.send(.customMetricsSourceLinkTapped(source))
        #expect(activatedURLs.withLock(\.self) == [resolvedURL])
    }

    @MainActor @Test
    func send_customMetricsSourceLinkTapped_persists_refreshed_bookmark_when_stale() async {
        let resolvedURL = URL(filePath: "/tmp/resolved.json")
        let refreshedBookmark = Data([0xBB, 0xCC])
        let existingID = UUID(7)
        let storage = makeStorage(initialSources: [
            CustomMetricsSource(
                id: existingID,
                displayName: "Stale",
                fileURL: URL(filePath: "/tmp/stale.json"),
                bookmark: Data([0xAA]),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let source = CustomMetricsSource(
            id: existingID,
            displayName: "Stale",
            fileURL: URL(filePath: "/tmp/stale.json"),
            bookmark: Data([0xAA]),
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let urlClient = testDependency(of: URLClient.self) {
            $0.create = { _, _ in (true, resolvedURL) }
            $0.bookmarkData = { _, _ in refreshedBookmark }
            $0.startAccessingSecurityScopedResource = { _ in true }
            $0.stopAccessingSecurityScopedResource = { _ in }
        }
        let nsWorkspaceClient = testDependency(of: NSWorkspaceClient.self) {
            $0.activateFileViewerSelecting = { _ in }
        }
        let sut = MetricsSettings(.testDependencies(
            nsWorkspaceClient: nsWorkspaceClient,
            urlClient: urlClient,
            userDefaultsClient: storage.client
        ))
        await sut.send(.customMetricsSourceLinkTapped(source))
        let configuration = storage.currentConfiguration()
        #expect(configuration?.sources.first?.bookmark == refreshedBookmark)
    }

    @MainActor @Test
    func send_customMetricsSourceLinkTapped_does_not_activate_when_create_throws() async {
        let activatedURLs = AllocatedUnfairLock<[URL]>(initialState: [])
        let source = CustomMetricsSource(
            id: UUID(8),
            displayName: "Broken",
            fileURL: URL(filePath: "/tmp/broken.json"),
            bookmark: Data(),
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let urlClient = testDependency(of: URLClient.self) {
            $0.create = { _, _ in throw URLError(.unknown) }
        }
        let nsWorkspaceClient = testDependency(of: NSWorkspaceClient.self) {
            $0.activateFileViewerSelecting = { urls in
                activatedURLs.withLock { $0 = urls }
            }
        }
        let sut = MetricsSettings(.testDependencies(
            nsWorkspaceClient: nsWorkspaceClient,
            urlClient: urlClient
        ))
        await sut.send(.customMetricsSourceLinkTapped(source))
        #expect(activatedURLs.withLock(\.self).isEmpty)
    }

    private struct Storage {
        let lock: AllocatedUnfairLock<[String: Data]>
        let client: UserDefaultsClient

        func currentConfiguration() -> CustomMetricsConfiguration? {
            guard let data = lock.withLock({ $0["CUSTOM_METRICS_CONFIGURATION"] }) else {
                return nil
            }
            return try? JSONDecoder().decode(CustomMetricsConfiguration.self, from: data)
        }
    }

    private func makeStorage(initialSources: [CustomMetricsSource] = []) -> Storage {
        var initial: [String: Data] = [:]
        if !initialSources.isEmpty,
           let encoded = try? JSONEncoder().encode(CustomMetricsConfiguration(sources: initialSources)) {
            initial["CUSTOM_METRICS_CONFIGURATION"] = encoded
        }
        let lock = AllocatedUnfairLock<[String: Data]>(initialState: initial)
        let client = testDependency(of: UserDefaultsClient.self) {
            $0.data = { key in lock.withLock { $0[key] } }
            $0.set = { rawValue, key in
                let dataValue = rawValue as? Data
                lock.withLock { storage in
                    if let dataValue {
                        storage[key] = dataValue
                    } else {
                        storage[key] = nil
                    }
                }
            }
            $0.removeObject = { key in
                lock.withLock { $0[key] = nil }
            }
        }
        return Storage(lock: lock, client: client)
    }
}
