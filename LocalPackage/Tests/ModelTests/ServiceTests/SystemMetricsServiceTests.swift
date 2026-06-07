import AllocatedUnfairLock
import Foundation
import SystemInfoKit
import Testing

@testable import DataSource
@testable import Model

struct SystemMetricsServiceTests {
    @Test
    func currentSystemInfoBundle_returns_value_from_observer() {
        let sut = SystemMetricsService(.testDependencies(
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.currentSystemInfo = {
                    var bundle = SystemInfoBundle()
                    bundle.cpuInfo = CPUInfo(percentage: Percentage(rawValue: 0.42), system: .zero, user: .zero, idle: .zero)
                    return bundle
                }
            }
        ))
        #expect(sut.currentSystemInfoBundle.cpuInfo?.percentage.value == 42.0)
    }

    @Test
    func stopMonitoring_stops_observer() {
        let stopMonitoringCount = AllocatedUnfairLock<Int>(initialState: 0)
        let sut = SystemMetricsService(.testDependencies(
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.stopMonitoring = {
                    stopMonitoringCount.withLock { $0 += 1 }
                }
            }
        ))
        sut.stopMonitoring()
        #expect(stopMonitoringCount.withLock(\.self) == 1)
    }

    @Test
    func startMonitoring_activates_configured_monitors_and_starts_observer() throws {
        let activationRequests = AllocatedUnfairLock<[SystemInfoType: Bool]?>(initialState: nil)
        let monitorInterval = AllocatedUnfairLock<Double?>(initialState: nil)
        let configuration = SystemMetricsConfiguration(
            monitorsMemory: true,
            monitorsStorage: false,
            monitorsBattery: true,
            monitorsNetwork: false
        )
        let configurationData = try JSONEncoder().encode(configuration)
        let sut = SystemMetricsService(.testDependencies(
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { requests in
                    activationRequests.withLock { $0 = requests }
                }
                $0.startMonitoring = { interval in
                    monitorInterval.withLock { $0 = interval }
                }
            },
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.data = { _ in configurationData }
            }
        ))
        sut.startMonitoring()
        #expect(activationRequests.withLock(\.self) == [
            .cpu: true,
            .memory: true,
            .storage: false,
            .battery: true,
            .network: false,
        ])
        #expect(monitorInterval.withLock(\.self) == 5.0)
    }

    @Test
    func startMonitoring_activates_all_monitors_when_no_configuration_is_stored() {
        let activationRequests = AllocatedUnfairLock<[SystemInfoType: Bool]?>(initialState: nil)
        let sut = SystemMetricsService(.testDependencies(
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { requests in
                    activationRequests.withLock { $0 = requests }
                }
            }
        ))
        sut.startMonitoring()
        #expect(activationRequests.withLock(\.self) == [
            .cpu: true,
            .memory: true,
            .storage: true,
            .battery: true,
            .network: true,
        ])
    }

    @Test
    func toggleSystemInfoActivation_passes_single_request_to_observer() {
        let activationRequests = AllocatedUnfairLock<[SystemInfoType: Bool]?>(initialState: nil)
        let sut = SystemMetricsService(.testDependencies(
            systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                $0.toggleActivation = { requests in
                    activationRequests.withLock { $0 = requests }
                }
            }
        ))
        sut.toggleSystemInfoActivation(type: .network, isOn: false)
        #expect(activationRequests.withLock(\.self) == [.network: false])
    }

    @Test
    func updateMetrics_sends_metrics_with_appended_ring_buffer_values() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = SystemMetricsService(.testDependencies(appStateClient: .testDependency(appState)))
        var systemInfoBundle = SystemInfoBundle()
        systemInfoBundle.cpuInfo = CPUInfo(percentage: Percentage(rawValue: 0.5), system: .zero, user: .zero, idle: .zero)
        systemInfoBundle.memoryInfo = .zero
        sut.updateMetrics(from: systemInfoBundle)
        let metrics = appState.withLock(\.metrics.latestValue)
        #expect(metrics?.systemInfoBundle.cpuInfo?.percentage.value == 50.0)
        #expect(metrics?.cpuRingBuffer.values.last == 50.0)
        #expect(metrics?.memoryRingBuffer.values.last == 0.0)
    }

    @Test
    func updateMetrics_keeps_ring_buffers_when_info_is_missing() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = SystemMetricsService(.testDependencies(appStateClient: .testDependency(appState)))
        sut.updateMetrics(from: SystemInfoBundle())
        let metrics = appState.withLock(\.metrics.latestValue)
        #expect(metrics?.cpuRingBuffer.values == RingBuffer().values)
        #expect(metrics?.memoryRingBuffer.values == RingBuffer().values)
    }

    @Test
    func updateMetrics_accumulates_values_across_calls() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = SystemMetricsService(.testDependencies(appStateClient: .testDependency(appState)))
        var firstBundle = SystemInfoBundle()
        firstBundle.cpuInfo = CPUInfo(percentage: Percentage(rawValue: 0.1), system: .zero, user: .zero, idle: .zero)
        var secondBundle = SystemInfoBundle()
        secondBundle.cpuInfo = CPUInfo(percentage: Percentage(rawValue: 0.2), system: .zero, user: .zero, idle: .zero)
        sut.updateMetrics(from: firstBundle)
        sut.updateMetrics(from: secondBundle)
        #expect(appState.withLock(\.metrics.latestValue)?.cpuRingBuffer.values.suffix(2) == [10.0, 20.0])
    }

    @Test
    func emitConfigurationChange_sends_change_event() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = SystemMetricsService(.testDependencies(appStateClient: .testDependency(appState)))
        sut.emitConfigurationChange()
        #expect(appState.withLock(\.systemMetricsConfigurationChanges.latestValue) != nil)
    }
}
