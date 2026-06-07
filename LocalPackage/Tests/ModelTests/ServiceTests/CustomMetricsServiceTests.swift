import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct CustomMetricsServiceTests {
    private let snapshotJSON = """
        {
          "title": "Card",
          "metrics": [],
          "lastUpdatedDate": "2026-06-05T04:50:40Z"
        }
        """

    private var snapshot: CustomMetricsSnapshot {
        get throws {
            CustomMetricsSnapshot(
                title: "Card",
                lastUpdatedDate: try #require(ISO8601DateFormatter().date(from: "2026-06-05T04:50:40Z"))
            )
        }
    }

    private func makeSource(id: UUID = UUID(1)) -> CustomMetricsSource {
        CustomMetricsSource(
            id: id,
            displayName: "Card",
            fileURL: URL(filePath: "/tmp/card.json"),
            bookmark: Data("bookmark".utf8),
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test
    func addSource_appends_source_built_from_snapshot_and_clients() throws {
        let storage = makeStorage()
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
    func addSource_throws_when_snapshot_decode_fails() {
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data("not json".utf8) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.startAccessingSecurityScopedResource = { _ in true }
            }
        ))
        #expect(throws: DecodingError.self) {
            try sut.addSource(of: URL(filePath: "/tmp/card.json"))
        }
    }

    @Test
    func removeSource_removes_matching_source_from_configuration() {
        let remaining = makeSource(id: UUID(2))
        let storage = makeStorage(initialSources: [makeSource(id: UUID(1)), remaining])
        let sut = CustomMetricsService(.testDependencies(userDefaultsClient: storage.client))
        sut.removeSource(of: UUID(1))
        #expect(storage.currentConfiguration() == CustomMetricsConfiguration(sources: [remaining]))
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
        let storage = makeStorage(initialSources: [source])
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
        let storage = makeStorage(initialSources: [source])
        let sut = CustomMetricsService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data(snapshotJSON.utf8) }
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
        try? await Task.sleep(for: .milliseconds(100))
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
        let storage = makeStorage(initialSources: [source])
        let sut = CustomMetricsService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data(snapshotJSON.utf8) }
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
        try? await Task.sleep(for: .milliseconds(100))
        sut.removeSource(of: UUID(1))
        sut.emitConfigurationChange()
        try? await Task.sleep(for: .milliseconds(100))
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
        let storage = makeStorage(initialSources: [source])
        let sut = CustomMetricsService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in throw URLError(.unknown) }
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
        try? await Task.sleep(for: .milliseconds(100))
        #expect(appState.withLock(\.metrics.latestValue)?.customMetricsBundles.first?.isFailed == true)
        sut.stopMonitoring()
    }

    private struct Storage {
        let lock: AllocatedUnfairLock<[String: Data]>
        let client: UserDefaultsClient

        func currentConfiguration() -> CustomMetricsConfiguration? {
            guard let data = lock.withLock({ $0[.customMetricsConfiguration] }) else {
                return nil
            }
            return try? JSONDecoder().decode(CustomMetricsConfiguration.self, from: data)
        }
    }

    private func makeStorage(initialSources: [CustomMetricsSource] = []) -> Storage {
        var initial = [String: Data]()
        if !initialSources.isEmpty,
           let encoded = try? JSONEncoder().encode(CustomMetricsConfiguration(sources: initialSources)) {
            initial[.customMetricsConfiguration] = encoded
        }
        let lock = AllocatedUnfairLock<[String: Data]>(initialState: initial)
        let client = testDependency(of: UserDefaultsClient.self) {
            $0.data = { key in lock.withLock { $0[key] } }
            $0.set = { rawValue, key in
                let dataValue = rawValue as? Data
                lock.withLock { $0[key] = dataValue }
            }
            $0.removeObject = { key in
                lock.withLock { $0[key] = nil }
            }
        }
        return Storage(lock: lock, client: client)
    }
}
