import AllocatedUnfairLock
import Foundation
import SystemInfoKit
import Testing

@testable import DataSource
@testable import Model

struct MetricsSettingsTests {
    @MainActor @Test
    func send_task_refreshes_configuration_when_change_event_is_emitted() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage()
        let sut = MetricsSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsSettingsTests"))
        #expect(sut.systemMetricsConfiguration == .default)
        let updatedConfiguration = SystemMetricsConfiguration(
            monitorsMemory: false,
            monitorsStorage: false,
            monitorsBattery: false,
            monitorsNetwork: false
        )
        let encodedConfiguration = try JSONEncoder().encode(updatedConfiguration)
        storage.lock.withLock { $0[.systemMetricsConfiguration] = encodedConfiguration }
        appState.withLock { $0.systemMetricsConfigurationChanges.send() }
        await waitUntil { sut.systemMetricsConfiguration == updatedConfiguration }
        #expect(sut.systemMetricsConfiguration == updatedConfiguration)
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_onDisappear_stops_observing_configuration_changes() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let storage = UserDefaultsClient.storage()
        let sut = MetricsSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: storage.client
        ))
        await sut.send(.task("MetricsSettingsTests"))
        await sut.send(.onDisappear)
        let updatedConfiguration = SystemMetricsConfiguration(
            monitorsMemory: false,
            monitorsStorage: false,
            monitorsBattery: false,
            monitorsNetwork: false
        )
        let encodedConfiguration = try JSONEncoder().encode(updatedConfiguration)
        storage.lock.withLock { $0[.systemMetricsConfiguration] = encodedConfiguration }
        appState.withLock { $0.systemMetricsConfigurationChanges.send() }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sut.systemMetricsConfiguration == .default)
    }

    @MainActor @Test
    func send_monitorsSystemMetricsToggleSwitched_persists_configurations_and_notifies() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let activationRequests = AllocatedUnfairLock<[SystemInfoType: Bool]?>(initialState: nil)
        let storage = UserDefaultsClient.storage()
        let initialBarConfiguration = MetricsBarConfiguration(
            showsCPU: true,
            showsMemory: true,
            showsStorage: false,
            showsBattery: false,
            showsNetwork: false,
            visibleCustomMetricsSourceIDs: []
        )
        let encodedBarConfiguration = try JSONEncoder().encode(initialBarConfiguration)
        storage.lock.withLock { $0[.metricsBarConfiguration] = encodedBarConfiguration }
        let sut = MetricsSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { requests in
                    activationRequests.withLock { $0 = requests }
                }
            },
            userDefaultsClient: storage.client
        ))
        await sut.send(.monitorsSystemMetricsToggleSwitched(.memory, false))
        #expect(sut.systemMetricsConfiguration.monitorsMemory == false)
        let storedConfigurationData = storage.lock.withLock { $0[.systemMetricsConfiguration] }
        let storedConfiguration = try JSONDecoder().decode(
            SystemMetricsConfiguration.self,
            from: try #require(storedConfigurationData)
        )
        #expect(storedConfiguration.monitorsMemory == false)
        let storedBarConfigurationData = storage.lock.withLock { $0[.metricsBarConfiguration] }
        let storedBarConfiguration = try JSONDecoder().decode(
            MetricsBarConfiguration.self,
            from: try #require(storedBarConfigurationData)
        )
        #expect(storedBarConfiguration.showsMemory == false)
        #expect(activationRequests.withLock(\.self) == [.memory: false])
        #expect(appState.withLock(\.systemMetricsConfigurationChanges.latestValue) != nil)
    }

    @MainActor @Test
    func send_monitorsSystemMetricsToggleSwitched_cpu_is_noop() async {
        let toggleActivationCount = AllocatedUnfairLock<Int>(initialState: 0)
        let sut = MetricsSettings(.testDependencies(
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { _ in
                    toggleActivationCount.withLock { $0 += 1 }
                }
            }
        ))
        await sut.send(.monitorsSystemMetricsToggleSwitched(.cpu, false))
        #expect(toggleActivationCount.withLock(\.self) == 0)
    }

    @MainActor @Test
    func send_showMetricsBarToggleSwitched_persists_flag() async {
        let setCallStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = MetricsSettings(.testDependencies(
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.set = { value, key in
                    let entry = "set: \(key) = \(value ?? "nil")"
                    setCallStack.withLock { $0.append(entry) }
                }
            }
        ))
        await sut.send(.showMetricsBarToggleSwitched(true))
        #expect(sut.showsMetricsBar == true)
        #expect(setCallStack.withLock(\.self) == ["set: SHOWS_METRICS_BAR = true"])
    }
}
