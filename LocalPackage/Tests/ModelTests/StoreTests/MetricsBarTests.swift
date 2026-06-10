import AllocatedUnfairLock
import Foundation
import SystemInfoKit
import Testing

@testable import DataSource
@testable import Model

struct MetricsBarTests {
    private func makeSource(id: UUID) -> CustomMetricsSource {
        CustomMetricsSource(
            id: id,
            displayName: "Card",
            symbol: "staroflife",
            fileURL: URL(filePath: "/tmp/card.json"),
            bookmark: Data("bookmark".utf8),
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeBundle(id: UUID, title: String) -> CustomMetricsBundle {
        CustomMetricsBundle(
            id: id,
            snapshot: CustomMetricsSnapshot(
                title: title,
                lastUpdatedDate: Date(timeIntervalSince1970: 0)
            )
        )
    }

    @MainActor @Test
    func send_task_loads_latest_metrics_and_observes_stream() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock { $0.metrics.send(Metrics.dummy(cpuRawValue: 0.1)) }
        let sut = MetricsBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("MetricsBarTests"))
        #expect(sut.systemInfoBundle.cpuInfo?.percentage.value == 10.0)
        appState.withLock { $0.metrics.send(Metrics.dummy(cpuRawValue: 0.2)) }
        await waitUntil { sut.systemInfoBundle.cpuInfo?.percentage.value == 20.0 }
        #expect(sut.systemInfoBundle.cpuInfo?.percentage.value == 20.0)
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_task_refreshes_configuration_when_change_event_is_emitted() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let configurationData = AllocatedUnfairLock<Data?>(initialState: nil)
        let sut = MetricsBar(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.data = { _ in configurationData.withLock(\.self) }
            }
        ))
        await sut.send(.task("MetricsBarTests"))
        #expect(sut.metricsBarConfiguration == .default)
        let updatedConfiguration = MetricsBarConfiguration(
            showsCPU: true,
            showsMemory: true,
            showsStorage: true,
            showsBattery: false,
            showsNetwork: false,
            visibleCustomMetricsSourceIDs: []
        )
        let encodedConfiguration = try JSONEncoder().encode(updatedConfiguration)
        configurationData.withLock { $0 = encodedConfiguration }
        appState.withLock { $0.systemMetricsConfigurationChanges.send() }
        await waitUntil { sut.metricsBarConfiguration == updatedConfiguration }
        #expect(sut.metricsBarConfiguration == updatedConfiguration)
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_task_publishes_custom_bundles_ordered_by_source_order() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(1)), makeSource(id: UUID(2))])
        let firstBundle = makeBundle(id: UUID(1), title: "First")
        let secondBundle = makeBundle(id: UUID(2), title: "Second")
        appState.withLock { $0.metrics.send(Metrics(customMetricsBundles: [secondBundle, firstBundle])) }
        let sut = MetricsBar(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsBarTests"))
        #expect(sut.customMetricsBundles == [firstBundle, secondBundle])
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_task_drops_bundle_and_visibility_after_source_removal() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        var initialMetricsBarConfiguration = MetricsBarConfiguration.default
        initialMetricsBarConfiguration.visibleCustomMetricsSourceIDs = [UUID(1)]
        let storage = UserDefaultsClient.storage(
            initialSources: [makeSource(id: UUID(1))],
            initialMetricsBarConfiguration: initialMetricsBarConfiguration
        )
        let bundle = makeBundle(id: UUID(1), title: "Card")
        appState.withLock { $0.metrics.send(Metrics(customMetricsBundles: [bundle])) }
        let sut = MetricsBar(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsBarTests"))
        #expect(sut.customMetricsBundles == [bundle])
        let service = CustomMetricsService(.testDependencies(userDefaultsClient: storage.client))
        service.removeSource(of: UUID(1))
        appState.withLock { $0.customMetricsConfigurationChanges.send() }
        await waitUntil { sut.customMetricsBundles.isEmpty }
        #expect(sut.customMetricsBundles.isEmpty)
        #expect(sut.metricsBarConfiguration.visibleCustomMetricsSourceIDs.isEmpty)
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_onDisappear_stops_observing_streams() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = MetricsBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("MetricsBarTests"))
        await sut.send(.onDisappear)
        appState.withLock { $0.metrics.send(Metrics.dummy(cpuRawValue: 0.3)) }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sut.systemInfoBundle.cpuInfo == nil)
    }
}
