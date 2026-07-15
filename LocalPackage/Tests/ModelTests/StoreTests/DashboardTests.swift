import AllocatedUnfairLock
import AppKit
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct DashboardTests {
    @MainActor @Test
    func send_task_loads_latest_metrics_and_observes_stream() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let initialMetrics = Metrics.dummy(customMetricsTitle: "Initial")
        appState.withLock { $0.metrics.send(initialMetrics) }
        let sut = Dashboard(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("DashboardTests"))
        #expect(sut.customMetricsBundles == initialMetrics.customMetricsBundles)
        let updatedMetrics = Metrics.dummy(customMetricsTitle: "Updated")
        appState.withLock { $0.metrics.send(updatedMetrics) }
        await waitUntil { sut.customMetricsBundles == updatedMetrics.customMetricsBundles }
        #expect(sut.customMetricsBundles == updatedMetrics.customMetricsBundles)
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_onDisappear_stops_observing_metrics() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = Dashboard(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("DashboardTests"))
        await sut.send(.onDisappear)
        appState.withLock { $0.metrics.send(.dummy(customMetricsTitle: "Ignored")) }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sut.customMetricsBundles.isEmpty)
    }

    @MainActor @Test
    func send_settingsButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsAppClient: testDependency(of: NSAppClient.self) {
                $0.activate = { value in
                    callStack.withLock { $0.append("activate: \(value)") }
                }
            }
        ))
        await sut.send(.settingsButtonTapped)
        #expect(callStack.withLock(\.self) == ["activate: true"])
    }

    @MainActor @Test
    func send_activityMonitorButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsWorkspaceClient: testDependency(of: NSWorkspaceClient.self) {
                $0.urlForApplication = { _ in
                    URL(filePath: "/System/Applications/Utilities/Activity Monitor.app/")
                }
                $0.openApplication = { value, _ in
                    callStack.withLock { $0.append("openApplication: \(value.absoluteString)") }
                }
            }
        ))
        await sut.send(.activityMonitorButtonTapped)
        #expect(callStack.withLock(\.self) == [
            "openApplication: file:///System/Applications/Utilities/Activity%20Monitor.app/",
        ])
    }

    @MainActor @Test
    func send_openSourceLicenseButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsAppClient: testDependency(of: NSAppClient.self) {
                $0.activate = { value in
                    callStack.withLock { $0.append("activate: \(value)") }
                }
            }
        ))
        let openWindow = OpenWindowActionWrapper { id, value in
            callStack.withLock { $0.append("openWindow: \(id), \(value)") }
        }
        await sut.send(.openSourceLicenseButtonTapped(openWindow))
        #expect(callStack.withLock(\.self) == [
            "activate: true",
            "openWindow: OPEN_SOURCE_LICENSE, 0",
        ])
    }

    @MainActor @Test
    func send_aboutButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsAppClient: testDependency(of: NSAppClient.self) {
                $0.activate = { value in
                    callStack.withLock { $0.append("activate: \(value)") }
                }
                $0.orderFrontStandardAboutPanel = { _ in
                    callStack.withLock { $0.append("orderFrontStandardAboutPanel") }
                }
            }
        ))
        await sut.send(.aboutButtonTapped(.init()))
        #expect(callStack.withLock(\.self) == [
            "activate: true",
            "orderFrontStandardAboutPanel",
        ])
    }

    @MainActor @Test
    func send_reportIssueButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsWorkspaceClient: testDependency(of: NSWorkspaceClient.self) {
                $0.open = { value in
                    callStack.withLock { $0.append("open: \(value.absoluteString)") }
                    return true
                }
            }
        ))
        await sut.send(.reportIssueButtonTapped)
        #expect(callStack.withLock(\.self) == [
            "open: https://github.com/runcat-dev/RunCatNeo/issues",
        ])
    }


    @MainActor @Test
    func send_pauseButtonTapped_toggles_isPaused_and_sends_runnerPauses() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let setCallStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.set = { value, key in
                    let entry = "set: \(key) = \(value ?? "nil")"
                    setCallStack.withLock { $0.append(entry) }
                }
            }
        ))
        #expect(sut.isPaused == false)
        await sut.send(.pauseButtonTapped)
        #expect(sut.isPaused == true)
        #expect(appState.withLock(\.runnerPauses.latestValue) == true)
        #expect(setCallStack.withLock(\.self) == ["set: IS_RUNNER_PAUSED = true"])
        await sut.send(.pauseButtonTapped)
        #expect(sut.isPaused == false)
        #expect(appState.withLock(\.runnerPauses.latestValue) == false)
    }

    @MainActor @Test
    func send_quitButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsAppClient: testDependency(of: NSAppClient.self) {
                $0.terminate = { _ in
                    callStack.withLock { $0.append("terminate") }
                }
            }
        ))
        await sut.send(.quitButtonTapped)
        #expect(callStack.withLock(\.self) == ["terminate"])
    }

    @MainActor @Test
    func send_debugSleepButtonTapped_posts_willSleepNotification() async {
        let postedNames = AllocatedUnfairLock<[Notification.Name]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsWorkspaceClient: testDependency(of: NSWorkspaceClient.self) {
                $0.post = { name, _ in
                    postedNames.withLock { $0.append(name) }
                }
            }
        ))
        await sut.send(.debugSleepButtonTapped)
        #expect(postedNames.withLock(\.self) == [NSWorkspace.willSleepNotification])
    }

    @MainActor @Test
    func send_debugWakeUpButtonTapped_posts_didWakeNotification() async {
        let postedNames = AllocatedUnfairLock<[Notification.Name]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsWorkspaceClient: testDependency(of: NSWorkspaceClient.self) {
                $0.post = { name, _ in
                    postedNames.withLock { $0.append(name) }
                }
            }
        ))
        await sut.send(.debugWakeUpButtonTapped)
        #expect(postedNames.withLock(\.self) == [NSWorkspace.didWakeNotification])
    }
}
