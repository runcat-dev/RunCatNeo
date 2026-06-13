import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct RunnerSettingsTests {
    private func makeSetRecorder() -> (lock: AllocatedUnfairLock<[String]>, client: UserDefaultsClient) {
        let setCallStack = AllocatedUnfairLock<[String]>(initialState: [])
        let client = testDependency(of: UserDefaultsClient.self) {
            $0.set = { value, key in
                let entry = "set: \(key) = \(value ?? "nil")"
                setCallStack.withLock { $0.append(entry) }
            }
        }
        return (setCallStack, client)
    }

    @MainActor @Test
    func send_task_loads_current_runner_and_observes_streams() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: .default, frame: .preset("cat-frame-0")))
        }
        let sut = RunnerSettings(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("RunnerSettingsTests"))
        #expect(sut.currentRunner == Runner.default)
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: Runner(kind: .dog), frame: .preset("dog-frame-0")))
            $0.runnerBundleLists.send([RunnerBundle(runner: Runner(kind: .dog), frame: .preset("dog-frame-0"))])
        }
        await waitUntil { sut.currentRunner == Runner(kind: .dog) && !sut.runnerBundleList.isEmpty }
        #expect(sut.currentRunner == Runner(kind: .dog))
        #expect(sut.runnerBundleList.map(\.runner) == [Runner(kind: .dog)])
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_onDisappear_stops_observing_streams() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerSettings(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("RunnerSettingsTests"))
        await sut.send(.onDisappear)
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: .default, frame: .preset("cat-frame-0")))
        }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sut.currentRunner == nil)
    }

    @MainActor @Test
    func send_selectRunner_updates_current_runner() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerSettings(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.selectRunner(Runner(kind: .dog)))
        #expect(sut.currentRunner == Runner(kind: .dog))
        #expect(appState.withLock(\.runnerBundles.latestValue)?.runner == Runner(kind: .dog))
    }

    @MainActor @Test
    func send_selectRunner_shows_alert_when_custom_runner_frames_are_missing() async {
        let runner = Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0]))
        let sut = RunnerSettings(.testDependencies(
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { $0.hasSuffix("RunCatNeo/") }
            }
        ))
        await sut.send(.selectRunner(runner))
        #expect(sut.error == .customRunner(.loadingFailed))
        #expect(sut.showingAlert == true)
        #expect(sut.currentRunner == nil)
    }

    @MainActor @Test
    func send_slowDownUnderLoadToggleSwitched_persists_and_updates_runner_speed() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let recorder = makeSetRecorder()
        let sut = RunnerSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: recorder.client
        ))
        await sut.send(.slowDownUnderLoadToggleSwitched(true))
        #expect(sut.speedDecreasesUnderLoad == true)
        #expect(recorder.lock.withLock(\.self) == ["set: SPEED_DECREASES_UNDER_LOAD = true"])
        #expect(appState.withLock(\.runnerSpeeds.latestValue) == 1.0)
    }

    @MainActor @Test
    func send_flipHorizontallyToggleSwitched_persists_and_resends_current_bundle() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let bundle = RunnerBundle(runner: .default, frame: .preset("cat-frame-0"))
        appState.withLock { $0.runnerBundles.send(bundle) }
        let recorder = makeSetRecorder()
        let sut = RunnerSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: recorder.client
        ))
        await sut.send(.flipHorizontallyToggleSwitched(true))
        #expect(sut.isFlippedHorizontally == true)
        #expect(recorder.lock.withLock(\.self) == ["set: IS_FLIPPED_HORIZONTALLY = true"])
        #expect(appState.withLock(\.runnerBundles.latestValue) == bundle)
    }

    @MainActor @Test
    func send_customRunnerSettings_onError_shows_alert() async {
        let sut = RunnerSettings(.testDependencies())
        await sut.send(.customRunnerSettings(.onError(.customRunner(.loadingFailed))))
        #expect(sut.error == .customRunner(.loadingFailed))
        #expect(sut.showingAlert == true)
    }
}
