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
    func send_viewAppeared_loads_customMetricsSources_from_user_defaults() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let source = makeSource(id: UUID(1))
        let storage = UserDefaultsClient.storage(initialSources: [source])
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.viewAppeared("MetricsBarSettingsTests"))
        #expect(sut.customMetricsSources == [source])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_refreshes_sources_when_custom_metrics_configuration_change_is_emitted() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage()
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.viewAppeared("MetricsBarSettingsTests"))
        #expect(sut.customMetricsSources.isEmpty)
        let source = makeSource(id: UUID(1))
        let encodedConfiguration = try? JSONEncoder().encode(CustomMetricsConfiguration(sources: [source]))
        storage.lock.withLock { $0[.customMetricsConfiguration] = encodedConfiguration }
        appState.withLock { $0.customMetricsConfigurationChanges.send() }
        await waitUntil { sut.customMetricsSources == [source] }
        #expect(sut.customMetricsSources == [source])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_showBatteryToggleSwitched_persists_configurations_and_activates() async throws {
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
        await sut.send(.showBatteryToggleSwitched(true))
        #expect(sut.metricsBarConfiguration.showsBattery)
        let storedBarConfiguration = try #require(storage.currentMetricsBarConfiguration())
        #expect(storedBarConfiguration.showsBattery)
        let storedConfiguration = try JSONDecoder().decode(
            SystemMetricsConfiguration.self,
            from: try #require(storage.lock.withLock { $0[.systemMetricsConfiguration] })
        )
        #expect(storedConfiguration.monitorsBattery)
        #expect(activationRequests.withLock(\.self) == [.battery: true])
        #expect(appState.withLock(\.systemMetricsConfigurationChanges.latestValue) != nil)
    }

    @MainActor @Test
    func send_showNetworkToggleSwitched_false_hides_network_without_toggling_activation() async throws {
        let activationCount = AllocatedUnfairLock<Int>(initialState: 0)
        let initialBarConfiguration = MetricsBarConfiguration(
            showsCPU: true,
            showsMemory: false,
            showsStorage: false,
            showsBattery: false,
            showsNetwork: true,
            visibleCustomMetricsSourceIDs: []
        )
        let storage = UserDefaultsClient.storage(initialMetricsBarConfiguration: initialBarConfiguration)
        let sut = MetricsBarSettings(.testDependencies(
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { _ in activationCount.withLock { $0 += 1 } }
            },
            userDefaultsClient: storage.client
        ))
        await sut.send(.showNetworkToggleSwitched(false))
        #expect(!sut.metricsBarConfiguration.showsNetwork)
        let storedBarConfiguration = try #require(storage.currentMetricsBarConfiguration())
        #expect(!storedBarConfiguration.showsNetwork)
        #expect(activationCount.withLock(\.self) == 0)
    }

    @MainActor @Test
    func send_cpuStylePickerSelected_does_not_toggle_activation() async {
        let activationCount = AllocatedUnfairLock<Int>(initialState: 0)
        let storage = UserDefaultsClient.storage()
        let sut = MetricsBarSettings(.testDependencies(
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { _ in activationCount.withLock { $0 += 1 } }
            },
            userDefaultsClient: storage.client
        ))
        await sut.send(.cpuStylePickerSelected(.percentage))
        #expect(sut.metricsBarConfiguration.showsCPU)
        #expect(activationCount.withLock(\.self) == 0)
    }

    @MainActor @Test
    func send_cpuStylePickerSelected_persists_style_and_emits_change() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage()
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.cpuStylePickerSelected(.circularGauge))
        #expect(sut.metricsBarConfiguration.cpuStyle == .circularGauge)
        let storedBarConfiguration = try #require(storage.currentMetricsBarConfiguration())
        #expect(storedBarConfiguration.cpuStyle == .circularGauge)
        #expect(appState.withLock(\.systemMetricsConfigurationChanges.latestValue) != nil)
    }

    @MainActor @Test
    func send_memoryStylePickerSelected_persists_style_and_emits_change() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage()
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.memoryStylePickerSelected(.linearGauge))
        #expect(sut.metricsBarConfiguration.memoryStyle == .linearGauge)
        let storedBarConfiguration = try #require(storage.currentMetricsBarConfiguration())
        #expect(storedBarConfiguration.memoryStyle == .linearGauge)
        #expect(appState.withLock(\.systemMetricsConfigurationChanges.latestValue) != nil)
    }

    @MainActor @Test
    func send_storageStylePickerSelected_persists_style_and_emits_change() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage()
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.storageStylePickerSelected(.availableCapacity))
        #expect(sut.metricsBarConfiguration.storageStyle == .availableCapacity)
        let storedBarConfiguration = try #require(storage.currentMetricsBarConfiguration())
        #expect(storedBarConfiguration.storageStyle == .availableCapacity)
        #expect(appState.withLock(\.systemMetricsConfigurationChanges.latestValue) != nil)
    }

    @MainActor @Test
    func send_cpuStylePickerSelected_nil_hides_cpu_and_keeps_style() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let initialBarConfiguration = MetricsBarConfiguration(
            showsCPU: true,
            cpuStyle: .circularGauge,
            showsMemory: false,
            showsStorage: false,
            showsBattery: false,
            showsNetwork: false,
            visibleCustomMetricsSourceIDs: []
        )
        let storage = UserDefaultsClient.storage(initialMetricsBarConfiguration: initialBarConfiguration)
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.cpuStylePickerSelected(nil))
        #expect(!sut.metricsBarConfiguration.showsCPU)
        #expect(sut.metricsBarConfiguration.cpuStyle == .circularGauge)
        let storedBarConfiguration = try #require(storage.currentMetricsBarConfiguration())
        #expect(!storedBarConfiguration.showsCPU)
        #expect(storedBarConfiguration.cpuStyle == .circularGauge)
        #expect(appState.withLock(\.systemMetricsConfigurationChanges.latestValue) != nil)
    }

    @MainActor @Test
    func send_memoryStylePickerSelected_shows_hidden_memory_and_activates_monitoring() async throws {
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
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { requests in
                    activationRequests.withLock { $0 = requests }
                }
            },
            userDefaultsClient: storage.client
        ))
        await sut.send(.memoryStylePickerSelected(.linearGauge))
        #expect(sut.metricsBarConfiguration.showsMemory)
        #expect(sut.metricsBarConfiguration.memoryStyle == .linearGauge)
        let storedConfiguration = try JSONDecoder().decode(
            SystemMetricsConfiguration.self,
            from: try #require(storage.lock.withLock { $0[.systemMetricsConfiguration] })
        )
        #expect(storedConfiguration.monitorsMemory)
        #expect(activationRequests.withLock(\.self) == [.memory: true])
    }

    @MainActor @Test
    func send_storageStylePickerSelected_nil_does_not_toggle_activation() async {
        let activationCount = AllocatedUnfairLock<Int>(initialState: 0)
        let initialBarConfiguration = MetricsBarConfiguration(
            showsCPU: true,
            showsMemory: false,
            showsStorage: true,
            storageStyle: .usedCapacity,
            showsBattery: false,
            showsNetwork: false,
            visibleCustomMetricsSourceIDs: []
        )
        let storage = UserDefaultsClient.storage(initialMetricsBarConfiguration: initialBarConfiguration)
        let sut = MetricsBarSettings(.testDependencies(
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { _ in activationCount.withLock { $0 += 1 } }
            },
            userDefaultsClient: storage.client
        ))
        await sut.send(.storageStylePickerSelected(nil))
        #expect(!sut.metricsBarConfiguration.showsStorage)
        #expect(sut.metricsBarConfiguration.storageStyle == .usedCapacity)
        #expect(activationCount.withLock(\.self) == 0)
    }

    @MainActor @Test
    func send_showCustomMetricsToggleSwitched_persists_visibility_and_emits_change() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage(initialSources: [makeSource(id: UUID(1))])
        let sut = MetricsBarSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.showCustomMetricsToggleSwitched(UUID(1), true))
        #expect(sut.metricsBarConfiguration.visibleCustomMetricsSourceIDs == [UUID(1)])
        #expect(storage.currentMetricsBarConfiguration()?.visibleCustomMetricsSourceIDs == [UUID(1)])
        #expect(appState.withLock(\.systemMetricsConfigurationChanges.latestValue) != nil)
        await sut.send(.showCustomMetricsToggleSwitched(UUID(1), false))
        #expect(sut.metricsBarConfiguration.visibleCustomMetricsSourceIDs.isEmpty)
        let storedBarConfiguration = try #require(storage.currentMetricsBarConfiguration())
        #expect(storedBarConfiguration.visibleCustomMetricsSourceIDs.isEmpty)
    }
}
