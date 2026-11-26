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
            if case let .errorOccurred(error) = action {
                lock.withLock { $0 = error }
            }
        }
        return (lock, action)
    }

    @MainActor @Test
    func send_viewAppeared_refreshes_failed_source_ids_when_metrics_change() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let snapshot = CustomMetricsSnapshot(title: "Card", lastUpdatedDate: Date(timeIntervalSince1970: 0))
        let failedBundle = CustomMetricsBundle(id: UUID(1), snapshot: snapshot, isFailed: true)
        appState.withLock { $0.metrics.send(Metrics(customMetricsBundles: [failedBundle])) }
        let sut = CustomMetricsSettings(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared)
        #expect(sut.failedCustomMetricsSourceIDs == [UUID(1)])
        let recoveredBundle = CustomMetricsBundle(id: UUID(1), snapshot: snapshot, isFailed: false)
        appState.withLock { $0.metrics.send(Metrics(customMetricsBundles: [recoveredBundle])) }
        await waitUntil { sut.failedCustomMetricsSourceIDs.isEmpty }
        #expect(sut.failedCustomMetricsSourceIDs.isEmpty)
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_reloads_customMetricsSources_from_user_defaults() async {
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
        await sut.send(.viewAppeared)
        #expect(sut.customMetricsSources.count == 1)
        #expect(sut.customMetricsSources.first?.displayName == "Existing")
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
        await sut.send(.viewAppeared)
        await sut.send(.removeCustomMetricsSourceButtonTapped(existingID))
        #expect(sut.pendingRemovalSourceID == existingID)
        #expect(sut.showingConfirmationDialog)
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

    @MainActor @Test
    func send_customMetricsSourceRowMoved_reorders_sources_and_emits_change() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage(initialSources: [
            CustomMetricsSource(
                id: UUID(9),
                displayName: "First",
                fileURL: URL(filePath: "/tmp/first.json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            ),
            CustomMetricsSource(
                id: UUID(10),
                displayName: "Second",
                fileURL: URL(filePath: "/tmp/second.json"),
                bookmark: Data(),
                createdAt: Date(timeIntervalSince1970: 0)
            ),
        ])
        let sut = CustomMetricsSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.customMetricsSourceRowMoved(IndexSet(integer: 1), 0))
        #expect(sut.customMetricsSources.map(\.id) == [UUID(10), UUID(9)])
        #expect(storage.currentConfiguration()?.sources.map(\.id) == [UUID(10), UUID(9)])
        #expect(appState.withLock(\.customMetricsConfigurationChanges.latestValue) != nil)
    }

    @MainActor @Test
    func send_addCustomMetricsSourceButtonTapped_presents_customMetricsSourceEditor() async {
        let sut = CustomMetricsSettings(.testDependencies())
        await sut.send(.addCustomMetricsSourceButtonTapped)
        #expect(sut.customMetricsSourceEditor?.id == UUID(0))
    }

    @MainActor @Test
    func send_guidanceButtonTapped_shows_guidance_popover() async {
        let sut = CustomMetricsSettings(.testDependencies())
        await sut.send(.guidanceButtonTapped)
        #expect(sut.showingGuidancePopover)
    }

    @MainActor @Test
    func send_customMetricsSourceEditor_cancelButtonTapped_dismisses_editor() async {
        let sut = CustomMetricsSettings(.testDependencies())
        await sut.send(.addCustomMetricsSourceButtonTapped)
        await sut.send(.customMetricsSourceEditor(.cancelButtonTapped))
        #expect(sut.customMetricsSourceEditor == nil)
    }

    @MainActor @Test
    func send_customMetricsSourceEditor_customMetricsSourceAdded_reloads_sources_emits_change_and_dismisses_editor() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let addedSource = CustomMetricsSource(
            id: UUID(11),
            displayName: "Added",
            fileURL: URL(filePath: "/tmp/added.json"),
            bookmark: Data(),
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let storage = UserDefaultsClient.storage(initialSources: [addedSource])
        let sut = CustomMetricsSettings(
            .testDependencies(
                appStateClient: .testDependency(appState),
                userDefaultsClient: storage.client
            ),
            customMetricsSources: []
        )
        await sut.send(.addCustomMetricsSourceButtonTapped)
        await sut.send(.customMetricsSourceEditor(.customMetricsSourceAdded))
        #expect(sut.customMetricsSources == [addedSource])
        #expect(appState.withLock(\.customMetricsConfigurationChanges.latestValue) != nil)
        #expect(sut.customMetricsSourceEditor == nil)
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
        await sut.send(.viewAppeared)
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
        await sut.send(.viewAppeared)
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
        await sut.send(.viewAppeared)
        await sut.send(.removeCustomMetricsSourceButtonTapped(existingID))
        await sut.send(.removingCustomMetricsSourceCancelled)
        #expect(sut.pendingRemovalSourceID == nil)
        #expect(sut.customMetricsSources.count == 1)
    }

    @MainActor @Test
    func send_errorOccurred_shows_alert() async {
        let sut = CustomMetricsSettings(.testDependencies())
        await sut.send(.errorOccurred(.customMetrics(.fileUnreadable)))
        #expect(sut.error == .customMetrics(.fileUnreadable))
        #expect(sut.showingAlert)
    }
}
