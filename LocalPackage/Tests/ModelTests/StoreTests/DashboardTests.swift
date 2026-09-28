import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct DashboardTests {
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
}
