import AllocatedUnfairLock
import Foundation
import SystemInfoKit
import Testing

@testable import DataSource
@testable import Model

struct MetricsBarSettingsTests {
    private func makeSource(id: UUID, displayName: String = "Card") -> CustomMetricsSource {
        CustomMetricsSource(
            id: id,
            displayName: displayName,
            symbol: "staroflife",
            fileURL: URL(filePath: "/tmp/card.json"),
            bookmark: Data("bookmark".utf8),
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    @MainActor @Test
    func send_task_loads_customMetricsSources_from_user_defaults() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let source = makeSource(id: UUID(1))
        let storage = UserDefaultsClient.storage(initialSources: [source])
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsBarSettingsTests"))
        #expect(sut.customMetricsSources == [source])
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_showsCustomMetricsToggleSwitched_persists_visibility_and_emits_change() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(1))])
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.showsCustomMetricsToggleSwitched(UUID(1), true))
        #expect(sut.metricsBarConfiguration.visibleCustomMetricsSourceIDs == [UUID(1)])
        #expect(storage.currentMetricsBarConfiguration()?.visibleCustomMetricsSourceIDs == [UUID(1)])
        #expect(appState.withLock(\.systemMetricsConfigurationChanges.latestValue) != nil)
        await sut.send(.showsCustomMetricsToggleSwitched(UUID(1), false))
        #expect(sut.metricsBarConfiguration.visibleCustomMetricsSourceIDs.isEmpty)
        #expect(storage.currentMetricsBarConfiguration()?.visibleCustomMetricsSourceIDs.isEmpty == true)
    }

    @MainActor @Test
    func send_task_refreshes_sources_when_custom_metrics_configuration_change_is_emitted() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage()
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsBarSettingsTests"))
        #expect(sut.customMetricsSources.isEmpty)
        let source = makeSource(id: UUID(1))
        let encodedConfiguration = try? JSONEncoder().encode(CustomMetricsConfiguration(sources: [source]))
        storage.lock.withLock { $0[.customMetricsConfiguration] = encodedConfiguration }
        appState.withLock { $0.customMetricsConfigurationChanges.send() }
        await waitUntil { sut.customMetricsSources == [source] }
        #expect(sut.customMetricsSources == [source])
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_showsSystemMetricsToggleSwitched_persists_configurations_and_activates() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let activationRequests = AllocatedUnfairLock<[SystemInfoType: Bool]?>(initialState: nil)
        let initialBarConfiguration = MetricsBarConfiguration(
            showsCPU: true,
            showsMemory: false,
            showsStorage: false,
            showsBattery: false,
            showsNetwork: false,
            visibleCustomMetricsSourceIDs: []
        )
        let storage = UserDefaultsClient.storage(initialMetricsBarConfiguration: initialBarConfiguration)
        let systemMetricsConfiguration = SystemMetricsConfiguration(
            monitorsMemory: false,
            monitorsStorage: false,
            monitorsBattery: false,
            monitorsNetwork: false
        )
        storage.lock.withLock {
            $0[.systemMetricsConfiguration] = try? JSONEncoder().encode(systemMetricsConfiguration)
        }
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { requests in
                    activationRequests.withLock { $0 = requests }
                }
            },
            userDefaultsClient: storage.client
        ))
        await sut.send(.showsSystemMetricsToggleSwitched(.memory, true))
        #expect(sut.metricsBarConfiguration.showsMemory == true)
        #expect(storage.currentMetricsBarConfiguration()?.showsMemory == true)
        let storedConfiguration = try JSONDecoder().decode(
            SystemMetricsConfiguration.self,
            from: try #require(storage.lock.withLock { $0[.systemMetricsConfiguration] })
        )
        #expect(storedConfiguration.monitorsMemory == true)
        #expect(activationRequests.withLock(\.self) == [.memory: true])
        #expect(appState.withLock(\.systemMetricsConfigurationChanges.latestValue) != nil)
    }

    @MainActor @Test
    func send_showsSystemMetricsToggleSwitched_cpu_does_not_toggle_activation() async {
        let activationCount = AllocatedUnfairLock<Int>(initialState: 0)
        let storage = UserDefaultsClient.storage()
        let sut = MetricsBarSettings(.testDependencies(
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { _ in activationCount.withLock { $0 += 1 } }
            },
            userDefaultsClient: storage.client
        ))
        await sut.send(.showsSystemMetricsToggleSwitched(.cpu, true))
        #expect(sut.metricsBarConfiguration.showsCPU == true)
        #expect(activationCount.withLock(\.self) == 0)
    }
}
