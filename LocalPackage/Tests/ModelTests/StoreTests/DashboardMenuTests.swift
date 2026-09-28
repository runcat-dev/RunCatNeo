import AllocatedUnfairLock
import AppKit
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct DashboardMenuTests {
    @MainActor @Test
    func send_viewAppeared_loads_current_runner_and_runner_bundle_list_then_observes_streams() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: .default, frame: .preset("cat-frame-0")))
            $0.runnerBundleLists.send([RunnerBundle(runner: .default, frame: .preset("cat-frame-0"))])
        }
        let sut = DashboardMenu(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared)
        #expect(sut.currentRunner == Runner.default)
        #expect(sut.runnerBundleList.map(\.runner) == [Runner.default])
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: Runner(kind: .dog), frame: .preset("dog-frame-0")))
            $0.runnerBundleLists.send([RunnerBundle(runner: Runner(kind: .dog), frame: .preset("dog-frame-0"))])
        }
        await waitUntil { sut.currentRunner == Runner(kind: .dog) }
        #expect(sut.currentRunner == Runner(kind: .dog))
        #expect(sut.runnerBundleList.map(\.runner) == [Runner(kind: .dog)])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewDisappeared_stops_observing_runner_streams() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = DashboardMenu(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared)
        await sut.send(.viewDisappeared)
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: .default, frame: .preset("cat-frame-0")))
        }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sut.currentRunner == nil)
    }

    @MainActor @Test
    func send_runnerKindPickerSelected_updates_current_runner() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = DashboardMenu(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.runnerKindPickerSelected(Runner(kind: .dog)))
        #expect(sut.currentRunner == Runner(kind: .dog))
        #expect(appState.withLock(\.runnerBundles.latestValue)?.runner == Runner(kind: .dog))
    }

    @MainActor @Test
    func send_runnerKindPickerSelected_keeps_current_runner_when_custom_runner_frames_are_missing() async {
        let runner = Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0]))
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = DashboardMenu(
            .testDependencies(
                appStateClient: .testDependency(appState),
                fileManagerClient: testDependency(of: FileManagerClient.self) {
                    $0.fileExists = { $0.hasSuffix("RunCatNeo/") }
                }
            ),
            currentRunner: .default
        )
        await sut.send(.runnerKindPickerSelected(runner))
        #expect(sut.currentRunner == Runner.default)
        #expect(appState.withLock(\.runnerBundles.latestValue) == nil)
    }

    @MainActor @Test
    func send_settingsButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = DashboardMenu(.testDependencies(
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
        let sut = DashboardMenu(.testDependencies(
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
    func send_aboutButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = DashboardMenu(.testDependencies(
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
    func send_openSourceLicenseButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = DashboardMenu(.testDependencies(
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
    func send_reportIssueButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = DashboardMenu(.testDependencies(
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
    func send_quitButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = DashboardMenu(.testDependencies(
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
        let sut = DashboardMenu(.testDependencies(
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
        let sut = DashboardMenu(.testDependencies(
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
