import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct CustomMetricsSettingsTests {
    private func errorRecorder() -> (
        lock: AllocatedUnfairLock<RCNError?>,
        action: (CustomMetricsSettings.Action) async -> Void
    ) {
        let lock = AllocatedUnfairLock<RCNError?>(initialState: nil)
        let action: (CustomMetricsSettings.Action) async -> Void = { action in
            if case let .onError(error) = action {
                lock.withLock { $0 = error }
            }
        }
        return (lock, action)
    }

    @MainActor @Test
    func send_task_refreshes_failed_source_ids_when_metrics_change() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let snapshot = CustomMetricsSnapshot(title: "Card", lastUpdatedDate: Date(timeIntervalSince1970: 0))
        let failedBundle = CustomMetricsBundle(id: UUID(1), snapshot: snapshot, isFailed: true)
        appState.withLock { $0.metrics.send(Metrics(customMetricsBundles: [failedBundle])) }
        let sut = CustomMetricsSettings(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task)
        #expect(sut.failedCustomMetricsSourceIDs == [UUID(1)])
        let recoveredBundle = CustomMetricsBundle(id: UUID(1), snapshot: snapshot, isFailed: false)
        appState.withLock { $0.metrics.send(Metrics(customMetricsBundles: [recoveredBundle])) }
        await waitUntil { sut.failedCustomMetricsSourceIDs.isEmpty }
        #expect(sut.failedCustomMetricsSourceIDs.isEmpty)
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_task_reloads_customMetricsSources_from_user_defaults() async {
        let storage = UserDefaultsClient.storage(initialSources: [
            CustomMetricsSource(
                id: UUID(1),
                displayName: "Existing",
                fileURL: URL(filePath: "/tmp/existing.json"),
                bookmark: Data([0x42]),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let sut = CustomMetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.task)
        #expect(sut.customMetricsSources.count == 1)
        #expect(sut.customMetricsSources.first?.displayName == "Existing")
    }

    @MainActor @Test
    func send_addCustomMetricsSourceButtonTapped_shows_file_importer() async {
        let sut = CustomMetricsSettings(.testDependencies())
        await sut.send(.addCustomMetricsSourceButtonTapped)
        #expect(sut.showingFileImporter == true)
    }

    @MainActor @Test
    func send_onCompletionFileImporter_success_appends_source_and_emits_change() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage()
        let fileURL = URL(filePath: "/tmp/metrics.json")
        let json = #"{ "title": "Imported", "metrics": [], "lastUpdatedDate": "2026-06-05T04:50:40Z" }"#
        let dataClient = testDependency(of: DataClient.self) {
            $0.read = { _ in Data(json.utf8) }
        }
        let urlClient = testDependency(of: URLClient.self) {
            $0.startAccessingSecurityScopedResource = { _ in true }
            $0.stopAccessingSecurityScopedResource = { _ in }
            $0.bookmarkData = { _, _ in Data([0xAB]) }
        }
        let sut = CustomMetricsSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: dataClient,
            urlClient: urlClient,
            userDefaultsClient: storage.client
        ))
        await sut.send(.onCompletionFileImporter(.success(fileURL)))
        #expect(sut.customMetricsSources.count == 1)
        #expect(sut.customMetricsSources.first?.displayName == "Imported")
        #expect(sut.customMetricsSources.first?.bookmark == Data([0xAB]))
        #expect(appState.withLock(\.customMetricsConfigurationChanges.latestValue) != nil)
    }

    @MainActor @Test
    func send_helpButtonTapped_shows_help_popover() async {
        let sut = CustomMetricsSettings(.testDependencies())
        await sut.send(.helpButtonTapped)
        #expect(sut.showingHelpPopover == true)
    }

    @MainActor @Test
    func send_onCompletionFileImporter_forwards_error_when_file_is_unreadable() async {
        let storage = UserDefaultsClient.storage()
        let recorder = errorRecorder()
        let sut = CustomMetricsSettings(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.read = { _ in throw URLError(.unknown) }
                },
                urlClient: testDependency(of: URLClient.self) {
                    $0.startAccessingSecurityScopedResource = { _ in true }
                },
                userDefaultsClient: storage.client
            ),
            action: recorder.action
        )
        await sut.send(.onCompletionFileImporter(.success(URL(filePath: "/tmp/metrics.json"))))
        #expect(recorder.lock.withLock(\.self) == .customMetrics(.fileUnreadable))
        #expect(sut.customMetricsSources.isEmpty)
    }

    @MainActor @Test
    func send_onCompletionFileImporter_forwards_error_when_json_is_invalid() async {
        let storage = UserDefaultsClient.storage()
        let recorder = errorRecorder()
        let sut = CustomMetricsSettings(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.read = { _ in Data("not json".utf8) }
                },
                urlClient: testDependency(of: URLClient.self) {
                    $0.startAccessingSecurityScopedResource = { _ in true }
                },
                userDefaultsClient: storage.client
            ),
            action: recorder.action
        )
        await sut.send(.onCompletionFileImporter(.success(URL(filePath: "/tmp/metrics.json"))))
        #expect(recorder.lock.withLock(\.self) == .customMetrics(.invalidFormat))
        #expect(sut.customMetricsSources.isEmpty)
    }

    @MainActor @Test
    func send_onCompletionFileImporter_failure_does_not_throw() async {
        struct DummyError: Error {}
        let storage = UserDefaultsClient.storage()
        let sut = CustomMetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.onCompletionFileImporter(.failure(DummyError())))
        #expect(sut.customMetricsSources.isEmpty)
    }

    @MainActor @Test
    func send_removeCustomMetricsSourceButtonTapped_marks_pending_and_shows_dialog() async {
        let existingID = UUID(2)
        let storage = UserDefaultsClient.storage(initialSources: [
            CustomMetricsSource(
                id: existingID,
                displayName: "Pending",
                fileURL: URL(filePath: "/tmp/pending.json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let sut = CustomMetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.task)
        await sut.send(.removeCustomMetricsSourceButtonTapped(existingID))
        #expect(sut.pendingRemovalSourceID == existingID)
        #expect(sut.showingConfirmationDialog == true)
        #expect(sut.customMetricsSources.count == 1)
    }

    @MainActor @Test
    func send_removingCustomMetricsSourceConfirmed_removes_pending_source() async {
        let existingID = UUID(3)
        let storage = UserDefaultsClient.storage(initialSources: [
            CustomMetricsSource(
                id: existingID,
                displayName: "Doomed",
                fileURL: URL(filePath: "/tmp/doomed.json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let sut = CustomMetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.task)
        await sut.send(.removeCustomMetricsSourceButtonTapped(existingID))
        await sut.send(.removingCustomMetricsSourceConfirmed)
        #expect(sut.customMetricsSources.isEmpty)
        #expect(sut.pendingRemovalSourceID == nil)
    }

    @MainActor @Test
    func send_removingCustomMetricsSourceConfirmed_with_no_pending_is_noop() async {
        let existingID = UUID(4)
        let storage = UserDefaultsClient.storage(initialSources: [
            CustomMetricsSource(
                id: existingID,
                displayName: "Safe",
                fileURL: URL(filePath: "/tmp/safe.json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let sut = CustomMetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.task)
        await sut.send(.removingCustomMetricsSourceConfirmed)
        #expect(sut.customMetricsSources.count == 1)
    }

    @MainActor @Test
    func send_removingCustomMetricsSourceCancelled_clears_pending_without_removing() async {
        let existingID = UUID(5)
        let storage = UserDefaultsClient.storage(initialSources: [
            CustomMetricsSource(
                id: existingID,
                displayName: "Spared",
                fileURL: URL(filePath: "/tmp/spared.json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let sut = CustomMetricsSettings(.testDependencies(
            userDefaultsClient: storage.client
        ))
        await sut.send(.task)
        await sut.send(.removeCustomMetricsSourceButtonTapped(existingID))
        await sut.send(.removingCustomMetricsSourceCancelled)
        #expect(sut.pendingRemovalSourceID == nil)
        #expect(sut.customMetricsSources.count == 1)
    }

    @MainActor @Test
    func send_customMetricsSourcesMoved_reorders_sources_persists_and_emits_change() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sources = (1...3).map {
            CustomMetricsSource(
                id: UUID($0),
                displayName: "Source \($0)",
                fileURL: URL(filePath: "/tmp/source-\($0).json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            )
        }
        let storage = UserDefaultsClient.storage(initialSources: sources)
        let sut = CustomMetricsSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.customMetricsSourcesMoved([0], 3))
        let expectedSources = [sources[1], sources[2], sources[0]]
        #expect(sut.customMetricsSources == expectedSources)
        #expect(storage.currentConfiguration()?.sources == expectedSources)
        #expect(appState.withLock(\.customMetricsConfigurationChanges.latestValue) != nil)
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
        let sut = CustomMetricsSettings(.testDependencies(
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
        let storage = UserDefaultsClient.storage(initialSources: [
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
        let sut = CustomMetricsSettings(.testDependencies(
            nsWorkspaceClient: nsWorkspaceClient,
            urlClient: urlClient,
            userDefaultsClient: storage.client
        ))
        await sut.send(.customMetricsSourceLinkTapped(source))
        let configuration = storage.currentConfiguration()
        #expect(configuration?.sources.first?.bookmark == refreshedBookmark)
    }

    @MainActor @Test
    func send_customMetricsSourceLinkTapped_forwards_error_when_create_throws() async {
        let activatedURLs = AllocatedUnfairLock<[URL]>(initialState: [])
        let recorder = errorRecorder()
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
        let sut = CustomMetricsSettings(
            .testDependencies(
                nsWorkspaceClient: nsWorkspaceClient,
                urlClient: urlClient
            ),
            action: recorder.action
        )
        await sut.send(.customMetricsSourceLinkTapped(source))
        #expect(activatedURLs.withLock(\.self).isEmpty)
        #expect(recorder.lock.withLock(\.self) == .customMetrics(.fileUnreadable))
    }
}
