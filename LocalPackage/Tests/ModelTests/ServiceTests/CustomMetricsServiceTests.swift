import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct CustomMetricsServiceTests {
    private let snapshotJSON = """
        {
          "title": "Card",
          "symbol": "staroflife",
          "metrics": [],
          "lastUpdatedDate": "2026-06-05T04:50:40Z"
        }
        """

    private var snapshot: CustomMetricsSnapshot {
        get throws {
            CustomMetricsSnapshot(
                title: "Card",
                symbol: "staroflife",
                lastUpdatedDate: try #require(ISO8601DateFormatter().date(from: "2026-06-05T04:50:40Z"))
            )
        }
    }

    private func makeSource(id: UUID = UUID(1)) -> CustomMetricsSource {
        CustomMetricsSource(
            id: id,
            displayName: "Card",
            symbol: "staroflife",
            fileURL: URL(filePath: "/tmp/card.json"),
            bookmark: Data("bookmark".utf8),
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test
    func addSource_appends_source_built_from_snapshot_and_clients() throws {
        let storage = UserDefaultsClient.storage()
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data(snapshotJSON.utf8) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.bookmarkData = { _, _ in Data("bookmark".utf8) }
                $0.startAccessingSecurityScopedResource = { _ in true }
            },
            userDefaultsClient: storage.client
        ))
        try sut.addSource(of: URL(filePath: "/tmp/card.json"))
        #expect(storage.currentConfiguration() == CustomMetricsConfiguration(sources: [
            CustomMetricsSource(
                id: UUID(0),
                displayName: "Card",
                symbol: "staroflife",
                fileURL: URL(filePath: "/tmp/card.json"),
                bookmark: Data("bookmark".utf8),
                createdAt: .distantPast
            ),
        ]))
    }

    @Test
    func addSource_throws_when_security_scoped_access_is_denied() {
        let sut = CustomMetricsService(.testDependencies())
        #expect(throws: RCNError.customMetrics(.fileUnreadable)) {
            try sut.addSource(of: URL(filePath: "/tmp/card.json"))
        }
    }

    @Test
    func addSource_throws_fileUnreadable_when_read_fails() {
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in throw URLError(.unknown) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.startAccessingSecurityScopedResource = { _ in true }
            }
        ))
        #expect(throws: RCNError.customMetrics(.fileUnreadable)) {
            try sut.addSource(of: URL(filePath: "/tmp/card.json"))
        }
    }

    @Test
    func addSource_throws_invalidFormat_when_snapshot_decode_fails() {
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data("not json".utf8) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.startAccessingSecurityScopedResource = { _ in true }
            }
        ))
        #expect(throws: RCNError.customMetrics(.invalidFormat)) {
            try sut.addSource(of: URL(filePath: "/tmp/card.json"))
        }
    }

    @Test
    func removeSource_removes_matching_source_from_configuration() {
        let remaining = makeSource(id: UUID(2))
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(1)), remaining])
        let sut = CustomMetricsService(.testDependencies(userDefaultsClient: storage.client))
        sut.removeSource(of: UUID(1))
        #expect(storage.currentConfiguration() == CustomMetricsConfiguration(sources: [remaining]))
    }

    @Test
    func removeSource_removes_visibility_entry_from_metricsBarConfiguration() {
        var initialMetricsBarConfiguration = MetricsBarConfiguration.default
        initialMetricsBarConfiguration.visibleCustomMetricsSourceIDs = [UUID(1), UUID(2)]
        let storage = UserDefaultsClient.storage(
            initialSources: [makeSource(id: UUID(1)), makeSource(id: UUID(2))],
            initialMetricsBarConfiguration: initialMetricsBarConfiguration
        )
        let sut = CustomMetricsService(.testDependencies(userDefaultsClient: storage.client))
        sut.removeSource(of: UUID(1))
        var expected = MetricsBarConfiguration.default
        expected.visibleCustomMetricsSourceIDs = [UUID(2)]
        #expect(storage.currentMetricsBarConfiguration() == expected)
    }

    @Test
    func perform_passes_resolved_security_scoped_url_to_action() throws {
        let receivedURLs = AllocatedUnfairLock<[URL]>(initialState: [])
        let sut = CustomMetricsService(.testDependencies(
            urlClient: testDependency(of: URLClient.self) {
                $0.create = { _, _ in (false, URL(filePath: "/tmp/resolved.json")) }
                $0.startAccessingSecurityScopedResource = { _ in true }
            }
        ))
        try sut.perform(
            action: { url in
                receivedURLs.withLock { $0.append(url) }
            },
            for: makeSource()
        )
        #expect(receivedURLs.withLock(\.self) == [URL(filePath: "/tmp/resolved.json")])
    }

    @Test
    func perform_persists_refreshed_bookmark_when_stale() throws {
        let source = makeSource()
        let storage = UserDefaultsClient.storage(initialSources: [source])
        let sut = CustomMetricsService(.testDependencies(
            urlClient: testDependency(of: URLClient.self) {
                $0.create = { _, _ in (true, URL(filePath: "/tmp/resolved.json")) }
                $0.bookmarkData = { _, _ in Data("refreshed".utf8) }
                $0.startAccessingSecurityScopedResource = { _ in true }
            },
            userDefaultsClient: storage.client
        ))
        try sut.perform(action: { _ in }, for: source)
        #expect(storage.currentConfiguration()?.sources.first?.bookmark == Data("refreshed".utf8))
    }

    @Test
    func perform_throws_when_security_scoped_access_is_denied() {
        let sut = CustomMetricsService(.testDependencies(
            urlClient: testDependency(of: URLClient.self) {
                $0.create = { _, _ in (false, URL(filePath: "/tmp/resolved.json")) }
            }
        ))
        #expect(throws: RCNError.customMetrics(.fileUnreadable)) {
            try sut.perform(action: { _ in }, for: makeSource())
        }
    }

    @Test
    func emitConfigurationChange_sends_change_event() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = CustomMetricsService(.testDependencies(appStateClient: .testDependency(appState)))
        sut.emitConfigurationChange()
        #expect(appState.withLock(\.customMetricsConfigurationChanges.latestValue) != nil)
    }

    @Test
    func stopMonitoring_cancels_observers_and_clears_custom_bundles() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let reconcileObserver = Task<Void, Never> {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
            }
        }
        let sourceObserver = Task<Void, Never> {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
            }
        }
        appState.withLock {
            $0.customMetricsReconcileObserver = reconcileObserver
            $0.customMetricsObservers = [UUID(1): sourceObserver]
        }
        let existingBundle = CustomMetricsBundle(id: UUID(1), snapshot: try snapshot)
        appState.withLock {
            $0.metrics.send(Metrics(customMetricsBundles: [existingBundle]))
        }
        let sut = CustomMetricsService(.testDependencies(appStateClient: .testDependency(appState)))
        sut.stopMonitoring()
        #expect(appState.withLock(\.customMetricsReconcileObserver) == nil)
        #expect(appState.withLock(\.customMetricsObservers).isEmpty)
        #expect(appState.withLock(\.metrics.latestValue)?.customMetricsBundles.isEmpty == true)
        #expect(reconcileObserver.isCancelled)
        #expect(sourceObserver.isCancelled)
    }

    @Test
    func startMonitoring_observes_configured_source_and_emits_snapshot() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let source = makeSource()
        let storage = UserDefaultsClient.storage(initialSources: [source])
        let sut = CustomMetricsService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data(snapshotJSON.utf8) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.create = { _, _ in (false, URL(filePath: "/tmp/card.json")) }
                $0.startAccessingSecurityScopedResource = { _ in true }
            },
            userDefaultsClient: storage.client
        ))
        sut.startMonitoring()
        await waitUntil { appState.withLock(\.metrics.latestValue)?.customMetricsBundles.isEmpty == false }
        #expect(appState.withLock(\.customMetricsReconcileObserver) != nil)
        #expect(Set(appState.withLock(\.customMetricsObservers).keys) == [UUID(1)])
        #expect(appState.withLock(\.metrics.latestValue)?.customMetricsBundles == [
            CustomMetricsBundle(id: UUID(1), snapshot: try snapshot),
        ])
        sut.stopMonitoring()
    }

    @Test
    func startMonitoring_removes_stale_observer_when_configuration_change_is_emitted() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let source = makeSource()
        let storage = UserDefaultsClient.storage(initialSources: [source])
        let sut = CustomMetricsService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data(snapshotJSON.utf8) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.create = { _, _ in (false, URL(filePath: "/tmp/card.json")) }
                $0.startAccessingSecurityScopedResource = { _ in true }
            },
            userDefaultsClient: storage.client
        ))
        sut.startMonitoring()
        await waitUntil { appState.withLock(\.metrics.latestValue)?.customMetricsBundles.isEmpty == false }
        sut.removeSource(of: UUID(1))
        sut.emitConfigurationChange()
        await waitUntil { appState.withLock(\.customMetricsObservers).isEmpty }
        #expect(appState.withLock(\.customMetricsObservers).isEmpty)
        #expect(appState.withLock(\.metrics.latestValue)?.customMetricsBundles.isEmpty == true)
        sut.stopMonitoring()
    }

    @Test
    func startMonitoring_marks_bundle_as_failed_when_read_fails() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let existingBundle = CustomMetricsBundle(id: UUID(1), snapshot: try snapshot, isFailed: false)
        appState.withLock {
            $0.metrics.send(Metrics(customMetricsBundles: [existingBundle]))
        }
        let source = makeSource()
        let storage = UserDefaultsClient.storage(initialSources: [source])
        let sut = CustomMetricsService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in throw URLError(.unknown) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.create = { _, _ in (false, URL(filePath: "/tmp/card.json")) }
                $0.startAccessingSecurityScopedResource = { _ in true }
            },
            userDefaultsClient: storage.client
        ))
        sut.startMonitoring()
        await waitUntil { appState.withLock(\.metrics.latestValue)?.customMetricsBundles.first?.isFailed == true }
        #expect(appState.withLock(\.metrics.latestValue)?.customMetricsBundles.first?.isFailed == true)
        sut.stopMonitoring()
    }

    @Test
    func startMonitoring_reloads_snapshot_when_file_changes() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let updatedJSON = """
            {
              "title": "Updated Card",
              "symbol": "staroflife",
              "metrics": [],
              "lastUpdatedDate": "2026-06-05T04:50:40Z"
            }
            """
        let readCount = AllocatedUnfairLock<Int>(initialState: 0)
        let source = makeSource()
        let storage = UserDefaultsClient.storage(initialSources: [source])
        let sut = CustomMetricsService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in
                    let isFirstRead = readCount.withLock { count in
                        count += 1
                        return count == 1
                    }
                    return Data((isFirstRead ? snapshotJSON : updatedJSON).utf8)
                }
            },
            fileWatcherClient: testDependency(of: FileWatcherClient.self) {
                $0.watch = { _ in
                    AsyncStream { $0.yield(Date(timeIntervalSince1970: 0)) }
                }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.create = { _, _ in (false, URL(filePath: "/tmp/card.json")) }
                $0.startAccessingSecurityScopedResource = { _ in true }
            },
            userDefaultsClient: storage.client
        ))
        sut.startMonitoring()
        await waitUntil {
            appState.withLock(\.metrics.latestValue)?.customMetricsBundles.first?.snapshot.title == "Updated Card"
        }
        #expect(appState.withLock(\.metrics.latestValue)?.customMetricsBundles == [
            CustomMetricsBundle(
                id: UUID(1),
                snapshot: CustomMetricsSnapshot(
                    title: "Updated Card",
                    symbol: "staroflife",
                    lastUpdatedDate: try #require(ISO8601DateFormatter().date(from: "2026-06-05T04:50:40Z"))
                )
            ),
        ])
        sut.stopMonitoring()
    }

    @Test
    func startMonitoring_appends_failed_placeholder_bundle_when_source_has_never_loaded() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let source = makeSource()
        let storage = UserDefaultsClient.storage(initialSources: [source])
        let sut = CustomMetricsService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in throw URLError(.unknown) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.create = { _, _ in (false, URL(filePath: "/tmp/card.json")) }
                $0.startAccessingSecurityScopedResource = { _ in true }
            },
            userDefaultsClient: storage.client
        ))
        sut.startMonitoring()
        await waitUntil { appState.withLock(\.metrics.latestValue)?.customMetricsBundles.isEmpty == false }
        #expect(appState.withLock(\.metrics.latestValue)?.customMetricsBundles == [
            CustomMetricsBundle(
                id: UUID(1),
                snapshot: CustomMetricsSnapshot(
                    title: "Card",
                    symbol: "staroflife",
                    lastUpdatedDate: Date(timeIntervalSince1970: 0)
                ),
                isFailed: true
            ),
        ])
        sut.stopMonitoring()
    }

}
