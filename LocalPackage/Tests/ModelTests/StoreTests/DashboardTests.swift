import AllocatedUnfairLock
import Foundation
import SystemInfoKit
import Testing

@testable import DataSource
@testable import Model

struct DashboardTests {
    private static let powerReport = Data("""
        {"SPPowerDataType":[{"sppower_battery_health_info":{"sppower_battery_health_maximum_capacity":"90%"}}]}
        """.utf8)

    @MainActor @Test
    func send_viewAppeared_loads_battery_health_and_clears_it_when_monitoring_is_disabled() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let metrics = Metrics(systemInfoBundle: batteryBundle())
        appState.withLock { $0.metrics.send(metrics) }
        let sut = Dashboard(.testDependencies(
            appStateClient: .testDependency(appState),
            processClient: testDependency(of: ProcessClient.self) {
                $0.readToEnd = { _ in Self.powerReport }
            }
        ))
        await sut.send(.viewAppeared("DashboardTests"))
        await waitUntil { sut.maximumBatteryCapacityPercent == 90 }
        #expect(sut.maximumBatteryCapacityPercent == 90)
        appState.withLock { $0.metrics.send(Metrics(systemInfoBundle: .cpuZero())) }
        await waitUntil { sut.maximumBatteryCapacityPercent == nil }
        #expect(sut.maximumBatteryCapacityPercent == nil)
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test(arguments: [true, false])
    func send_viewAppeared_skips_health_reads_for_previews_and_desktops(_ isPreview: Bool) async {
        let readCount = AllocatedUnfairLock(initialState: 0)
        let sut = Dashboard(
            .testDependencies(processClient: testDependency(of: ProcessClient.self) {
                $0.readToEnd = { _ in
                    readCount.withLock { $0 += 1 }
                    return Self.powerReport
                }
            }),
            systemInfoBundle: batteryBundle(isInstalled: isPreview),
            isPreview: isPreview
        )
        await sut.send(.viewAppeared("DashboardTests"))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(readCount.withLock(\.self) == 0)
        #expect(sut.maximumBatteryCapacityPercent == nil)
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewDisappeared_does_not_publish_a_late_battery_read() async {
        let readStarted = AllocatedUnfairLock(initialState: false)
        let releaseRead = DispatchSemaphore(value: 0)
        let sut = Dashboard(
            .testDependencies(processClient: testDependency(of: ProcessClient.self) {
                $0.readToEnd = { _ in
                    readStarted.withLock { $0 = true }
                    _ = releaseRead.wait(timeout: .now() + 2)
                    return Self.powerReport
                }
            }),
            systemInfoBundle: batteryBundle()
        )
        await sut.send(.viewAppeared("DashboardTests"))
        await waitUntil { readStarted.withLock(\.self) }
        await sut.send(.viewDisappeared)
        releaseRead.signal()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sut.maximumBatteryCapacityPercent == nil)
    }

    @MainActor @Test
    func send_viewAppeared_loads_latest_metrics_and_observes_stream() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let initialMetrics = Metrics.dummy(customMetricsTitle: "Initial")
        appState.withLock { $0.metrics.send(initialMetrics) }
        let sut = Dashboard(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("DashboardTests"))
        #expect(sut.customMetricsBundles == initialMetrics.customMetricsBundles)
        let updatedMetrics = Metrics.dummy(customMetricsTitle: "Updated")
        appState.withLock { $0.metrics.send(updatedMetrics) }
        await waitUntil { sut.customMetricsBundles == updatedMetrics.customMetricsBundles }
        #expect(sut.customMetricsBundles == updatedMetrics.customMetricsBundles)
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_refreshes_displayedDate_every_time_it_is_sent() async {
        let dates = AllocatedUnfairLock<[Date]>(initialState: [
            Date(timeIntervalSince1970: 1_000),
            Date(timeIntervalSince1970: 2_000),
        ])
        let sut = Dashboard(
            .testDependencies(
                dateClient: testDependency(of: DateClient.self) {
                    $0.now = { dates.withLock { $0.removeFirst() } }
                }
            ),
            displayedDate: .distantPast
        )
        #expect(sut.displayedDate == .distantPast)
        await sut.send(.viewAppeared("DashboardTests"))
        #expect(sut.displayedDate == Date(timeIntervalSince1970: 1_000))
        await sut.send(.viewDisappeared)
        await sut.send(.viewAppeared("DashboardTests"))
        #expect(sut.displayedDate == Date(timeIntervalSince1970: 2_000))
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewDisappeared_stops_observing_metrics() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = Dashboard(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("DashboardTests"))
        await sut.send(.viewDisappeared)
        appState.withLock { $0.metrics.send(.dummy(customMetricsTitle: "Ignored")) }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sut.customMetricsBundles.isEmpty)
    }

    private func batteryBundle(isInstalled: Bool = true) -> SystemInfoBundle {
        var bundle = SystemInfoBundle.cpuZero()
        bundle.batteryInfo = BatteryInfo(
            percentage: .init(rawValue: 1),
            isInstalled: isInstalled,
            isCharging: false,
            adapterName: nil,
            maxCapacity: .init(rawValue: 1),
            cycleCount: 127,
            temperature: .init(value: 37)
        )
        return bundle
    }
}
