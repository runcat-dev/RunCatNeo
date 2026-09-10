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
    func send_slowDownUnderLoadToggleSwitched_persists_and_updates_runner_speed() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let recorder = makeSetRecorder()
        let sut = RunnerSettings(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: recorder.client
        ))
        await sut.send(.slowDownUnderLoadToggleSwitched(true))
        #expect(sut.speedDecreasesUnderLoad)
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
        #expect(sut.isFlippedHorizontally)
        #expect(recorder.lock.withLock(\.self) == ["set: IS_FLIPPED_HORIZONTALLY = true"])
        #expect(appState.withLock(\.runnerBundles.latestValue) == bundle)
    }
}
