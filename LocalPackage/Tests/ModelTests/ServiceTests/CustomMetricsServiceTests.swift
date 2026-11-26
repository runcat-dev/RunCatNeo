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
    func makeSource_returns_source_and_snapshot_built_from_file_and_clients() throws {
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data(snapshotJSON.utf8) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.bookmarkData = { _, _ in Data("bookmark".utf8) }
                $0.startAccessingSecurityScopedResource = { _ in true }
            }
        ))
        let (source, snapshot) = try sut.makeSource(of: URL(filePath: "/tmp/card.json"))
        #expect(source == CustomMetricsSource(
            id: UUID(0),
            displayName: "Card",
            symbol: "staroflife",
            fileURL: URL(filePath: "/tmp/card.json"),
            bookmark: Data("bookmark".utf8),
            createdAt: .distantPast
        ))
        #expect(snapshot == (try self.snapshot))
    }

    @Test
    func makeSource_does_not_persist_source() throws {
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
        _ = try sut.makeSource(of: URL(filePath: "/tmp/card.json"))
        #expect(storage.currentConfiguration() == nil)
    }

    @Test
    func makeSource_throws_when_security_scoped_access_is_denied() {
        let sut = CustomMetricsService(.testDependencies())
        #expect(throws: RCNError.customMetrics(.fileUnreadable)) {
            try sut.makeSource(of: URL(filePath: "/tmp/card.json"))
        }
    }

    @Test
    func makeSource_throws_fileUnreadable_when_read_fails() {
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in throw URLError(.unknown) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.startAccessingSecurityScopedResource = { _ in true }
            }
        ))
        #expect(throws: RCNError.customMetrics(.fileUnreadable)) {
            try sut.makeSource(of: URL(filePath: "/tmp/card.json"))
        }
    }

    @Test
    func makeSource_throws_invalidFormat_when_snapshot_decode_fails() {
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data("not json".utf8) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.startAccessingSecurityScopedResource = { _ in true }
            }
        ))
        #expect(throws: RCNError.customMetrics(.invalidFormat)) {
            try sut.makeSource(of: URL(filePath: "/tmp/card.json"))
        }
    }

    @Test
    func loadSymbolImageData_returns_data_of_48px_png_with_alpha() throws {
        let imageData = Data.image(width: 48, height: 48)
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in imageData }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.startAccessingSecurityScopedResource = { _ in true }
            }
        ))
        #expect(try sut.loadSymbolImageData(of: URL(filePath: "/tmp/symbol.png")) == imageData)
    }

    @Test(arguments: [
        Data.image(width: 32, height: 32),
        Data.image(width: 48, height: 36),
        Data.image(width: 96, height: 96),
        Data.image(width: 48, height: 48, hasAlpha: false),
        Data.image(width: 48, height: 48, type: .gif),
        Data("not image".utf8),
    ])
    func loadSymbolImageData_throws_invalidSymbolImage_when_image_does_not_meet_requirements(imageData: Data) {
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in imageData }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.startAccessingSecurityScopedResource = { _ in true }
            }
        ))
        #expect(throws: RCNError.customMetrics(.invalidSymbolImage)) {
            try sut.loadSymbolImageData(of: URL(filePath: "/tmp/symbol.png"))
        }
    }

    @Test
    func loadSymbolImageData_throws_when_security_scoped_access_is_denied() {
        let sut = CustomMetricsService(.testDependencies())
        #expect(throws: RCNError.customMetrics(.fileUnreadable)) {
            try sut.loadSymbolImageData(of: URL(filePath: "/tmp/symbol.png"))
        }
    }

    @Test
    func loadSymbolImageData_throws_fileUnreadable_when_read_fails() {
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in throw URLError(.unknown) }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.startAccessingSecurityScopedResource = { _ in true }
            }
        ))
        #expect(throws: RCNError.customMetrics(.fileUnreadable)) {
            try sut.loadSymbolImageData(of: URL(filePath: "/tmp/symbol.png"))
        }
    }

    @Test
    func add_appends_source_without_saving_image_when_symbol_image_is_absent() throws {
        let writtenURLs = AllocatedUnfairLock<[URL]>(initialState: [])
        let storage = UserDefaultsClient.storage()
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.write = { _, url in writtenURLs.withLock { $0.append(url) } }
            },
            userDefaultsClient: storage.client
        ))
        try sut.add(source: makeSource(), symbolImageData: nil)
        #expect(storage.currentConfiguration() == CustomMetricsConfiguration(sources: [makeSource()]))
        #expect(writtenURLs.withLock(\.self).isEmpty)
    }

    @Test
    func add_saves_symbol_image_in_source_directory_and_appends_source() throws {
        let writtenFiles = AllocatedUnfairLock<[String: Data]>(initialState: [:])
        let imageData = Data.image(width: 48, height: 48)
        let storage = UserDefaultsClient.storage()
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.write = { data, url in writtenFiles.withLock { $0[url.path(percentEncoded: false)] = data } }
            },
            userDefaultsClient: storage.client
        ))
        try sut.add(source: makeSource(id: UUID(1)), symbolImageData: imageData)
        #expect(writtenFiles.withLock(\.self) == [
            "/Users/user/Library/Application Support/RunCatNeo/CustomMetrics/\(UUID(1).uuidString)/symbol.png": imageData,
        ])
        #expect(storage.currentConfiguration() == CustomMetricsConfiguration(sources: [makeSource(id: UUID(1))]))
    }

    @Test
    func add_throws_savingFailed_and_does_not_append_source_when_saving_image_fails() {
        let storage = UserDefaultsClient.storage()
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.write = { _, _ in throw URLError(.unknown) }
            },
            userDefaultsClient: storage.client
        ))
        #expect(throws: RCNError.customMetrics(.savingFailed)) {
            try sut.add(source: makeSource(), symbolImageData: Data.image(width: 48, height: 48))
        }
        #expect(storage.currentConfiguration() == nil)
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
    func removeSource_deletes_source_directory() {
        let removedURLs = AllocatedUnfairLock<[URL]>(initialState: [])
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(1))])
        let sut = CustomMetricsService(.testDependencies(
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.urls = { _, _ in [URL(filePath: "/Users/user/Library/Application Support/")] }
                $0.fileExists = { _ in true }
                $0.removeItem = { url in removedURLs.withLock { $0.append(url) } }
            },
            userDefaultsClient: storage.client
        ))
        sut.removeSource(of: UUID(1))
        #expect(removedURLs.withLock(\.self).map { $0.path(percentEncoded: false) } == [
            "/Users/user/Library/Application Support/RunCatNeo/CustomMetrics/\(UUID(1).uuidString)",
        ])
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
    func moveSources_reorders_sources_in_configuration() {
        let firstSource = makeSource(id: UUID(1))
        let secondSource = makeSource(id: UUID(2))
        let storage = UserDefaultsClient.storage(initialSources: [firstSource, secondSource])
        let sut = CustomMetricsService(.testDependencies(userDefaultsClient: storage.client))
        sut.moveSources(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        #expect(storage.currentConfiguration() == CustomMetricsConfiguration(sources: [secondSource, firstSource]))
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
    func perform_does_not_overwrite_bookmark_replaced_by_edit() throws {
        var replacedSource = makeSource()
        replacedSource.bookmark = Data("replaced".utf8)
        let storage = UserDefaultsClient.storage(initialSources: [replacedSource])
        let sut = CustomMetricsService(.testDependencies(
            urlClient: testDependency(of: URLClient.self) {
                $0.create = { _, _ in (true, URL(filePath: "/tmp/resolved.json")) }
                $0.bookmarkData = { _, _ in Data("refreshed".utf8) }
                $0.startAccessingSecurityScopedResource = { _ in true }
            },
            userDefaultsClient: storage.client
        ))
        try sut.perform(action: { _ in }, for: makeSource())
        #expect(storage.currentConfiguration()?.sources.first?.bookmark == Data("replaced".utf8))
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
        let metrics = try #require(appState.withLock { $0.metrics.latestValue })
        #expect(metrics.customMetricsBundles.isEmpty)
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
    func startMonitoring_attaches_saved_symbol_image_to_bundle() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let imageData = Data.image(width: 48, height: 48)
        let source = makeSource()
        let storage = UserDefaultsClient.storage(initialSources: [source])
        let sut = CustomMetricsService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { url in
                    url.path(percentEncoded: false) == "/Users/user/Library/Application Support/RunCatNeo/CustomMetrics/\(UUID(1).uuidString)/symbol.png"
                        ? imageData
                        : Data(snapshotJSON.utf8)
                }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.urls = { _, _ in [URL(filePath: "/Users/user/Library/Application Support/")] }
                $0.fileExists = { _ in true }
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
            CustomMetricsBundle(id: UUID(1), snapshot: try snapshot, symbolImageData: imageData),
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
        let metrics = try #require(appState.withLock { $0.metrics.latestValue })
        #expect(metrics.customMetricsBundles.isEmpty)
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
        let failedBundle = try #require(appState.withLock { $0.metrics.latestValue }?.customMetricsBundles.first)
        #expect(failedBundle.isFailed)
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
    func startMonitoring_sorts_existing_bundles_by_source_order() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let firstBundle = CustomMetricsBundle(id: UUID(1), snapshot: try snapshot)
        let secondBundle = CustomMetricsBundle(id: UUID(2), snapshot: try snapshot)
        appState.withLock {
            $0.metrics.send(Metrics(customMetricsBundles: [secondBundle, firstBundle]))
        }
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(1)), makeSource(id: UUID(2))])
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
        #expect(appState.withLock(\.metrics.latestValue)?.customMetricsBundles.map(\.id) == [UUID(1), UUID(2)])
        sut.stopMonitoring()
    }

    @Test
    func startMonitoring_emits_late_loaded_bundle_at_source_position() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let secondBundle = CustomMetricsBundle(id: UUID(2), snapshot: try snapshot)
        appState.withLock {
            $0.metrics.send(Metrics(customMetricsBundles: [secondBundle]))
        }
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(1)), makeSource(id: UUID(2))])
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
        await waitUntil { appState.withLock(\.metrics.latestValue)?.customMetricsBundles.count == 2 }
        #expect(appState.withLock(\.metrics.latestValue)?.customMetricsBundles.map(\.id) == [UUID(1), UUID(2)])
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

    @Test
    func savedSymbolImageData_returns_image_in_source_directory() {
        let imageData = Data.image(width: 48, height: 48)
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { url in
                    url.path(percentEncoded: false) == "/Users/user/Library/Application Support/RunCatNeo/CustomMetrics/\(UUID(1).uuidString)/symbol.png"
                        ? imageData
                        : Data()
                }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.urls = { _, _ in [URL(filePath: "/Users/user/Library/Application Support/")] }
                $0.fileExists = { _ in true }
            }
        ))
        #expect(sut.savedSymbolImageData(of: UUID(1)) == imageData)
    }

    @Test
    func update_replaces_source_in_place_and_saves_symbol_image() throws {
        let writtenFiles = AllocatedUnfairLock<[String: Data]>(initialState: [:])
        let imageData = Data.image(width: 48, height: 48)
        let other = makeSource(id: UUID(2))
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(1)), other])
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.write = { data, url in writtenFiles.withLock { $0[url.path(percentEncoded: false)] = data } }
            },
            userDefaultsClient: storage.client
        ))
        var updated = makeSource(id: UUID(1))
        updated.displayName = "Updated"
        try sut.update(source: updated, symbolImageData: imageData)
        #expect(storage.currentConfiguration() == CustomMetricsConfiguration(sources: [updated, other]))
        #expect(writtenFiles.withLock(\.self) == [
            "/Users/user/Library/Application Support/RunCatNeo/CustomMetrics/\(UUID(1).uuidString)/symbol.png": imageData,
        ])
    }

    @Test
    func update_deletes_source_directory_when_symbol_image_is_absent() throws {
        let removedURLs = AllocatedUnfairLock<[URL]>(initialState: [])
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(1))])
        let sut = CustomMetricsService(.testDependencies(
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.urls = { _, _ in [URL(filePath: "/Users/user/Library/Application Support/")] }
                $0.fileExists = { _ in true }
                $0.removeItem = { url in removedURLs.withLock { $0.append(url) } }
            },
            userDefaultsClient: storage.client
        ))
        try sut.update(source: makeSource(id: UUID(1)), symbolImageData: nil)
        #expect(removedURLs.withLock(\.self).map { $0.path(percentEncoded: false) } == [
            "/Users/user/Library/Application Support/RunCatNeo/CustomMetrics/\(UUID(1).uuidString)",
        ])
    }

    @Test
    func update_throws_savingFailed_when_source_does_not_exist() {
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(2))])
        let sut = CustomMetricsService(.testDependencies(userDefaultsClient: storage.client))
        #expect(throws: RCNError.customMetrics(.savingFailed)) {
            try sut.update(source: makeSource(id: UUID(1)), symbolImageData: nil)
        }
        #expect(storage.currentConfiguration() == CustomMetricsConfiguration(sources: [makeSource(id: UUID(2))]))
    }

    @Test
    func update_throws_savingFailed_and_keeps_source_when_saving_image_fails() {
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(1))])
        let sut = CustomMetricsService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.write = { _, _ in throw URLError(.unknown) }
            },
            userDefaultsClient: storage.client
        ))
        var updated = makeSource(id: UUID(1))
        updated.displayName = "Updated"
        #expect(throws: RCNError.customMetrics(.savingFailed)) {
            try sut.update(source: updated, symbolImageData: Data.image(width: 48, height: 48))
        }
        #expect(storage.currentConfiguration() == CustomMetricsConfiguration(sources: [makeSource(id: UUID(1))]))
    }

    @Test
    func update_while_monitoring_reloads_new_file_and_applies_symbol_image() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let writtenFiles = AllocatedUnfairLock<[String: Data]>(initialState: [:])
        let updatedSnapshotJSON = snapshotJSON.replacingOccurrences(of: #""Card""#, with: #""Updated""#)
        let imageData = Data.image(width: 48, height: 48)
        let storage = UserDefaultsClient.storage(initialSources: [makeSource()])
        let sut = CustomMetricsService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { url in
                    let path = url.path(percentEncoded: false)
                    if let data = writtenFiles.withLock({ $0[path] }) {
                        return data
                    }
                    return Data((path == "/tmp/updated.json" ? updatedSnapshotJSON : snapshotJSON).utf8)
                }
                $0.write = { data, url in
                    writtenFiles.withLock { $0[url.path(percentEncoded: false)] = data }
                }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.urls = { _, _ in [URL(filePath: "/Users/user/Library/Application Support/")] }
                $0.fileExists = { path in
                    !path.hasSuffix(".png") || writtenFiles.withLock { $0[path] != nil }
                }
            },
            urlClient: testDependency(of: URLClient.self) {
                $0.create = { bookmark, _ in
                    (false, URL(filePath: bookmark == Data("updated".utf8) ? "/tmp/updated.json" : "/tmp/card.json"))
                }
                $0.startAccessingSecurityScopedResource = { _ in true }
            },
            userDefaultsClient: storage.client
        ))
        sut.startMonitoring()
        await waitUntil { appState.withLock(\.metrics.latestValue)?.customMetricsBundles.first?.snapshot.title == "Card" }
        var updatedSource = makeSource()
        updatedSource.fileURL = URL(filePath: "/tmp/updated.json")
        updatedSource.bookmark = Data("updated".utf8)
        try sut.update(source: updatedSource, symbolImageData: imageData)
        sut.emitConfigurationChange()
        var updatedSnapshot = try snapshot
        updatedSnapshot.title = "Updated"
        let expectedBundle = CustomMetricsBundle(id: UUID(1), snapshot: updatedSnapshot, symbolImageData: imageData)
        await waitUntil { appState.withLock(\.metrics.latestValue)?.customMetricsBundles == [expectedBundle] }
        #expect(appState.withLock(\.metrics.latestValue)?.customMetricsBundles == [expectedBundle])
        sut.stopMonitoring()
    }

}
