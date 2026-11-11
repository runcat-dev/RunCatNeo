import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct RunnerRotationSettingsTests {
    private let runnerBundleList = [
        RunnerBundle(runner: Runner(kind: .cat), frame: .preset("cat-frame-0")),
        RunnerBundle(runner: Runner(kind: .dog), frame: .preset("dog-frame-0")),
        RunnerBundle(runner: Runner(kind: .slime), frame: .preset("slime-frame-0")),
    ]

    private func makeStorage() -> (lock: AllocatedUnfairLock<[String: Data]>, client: UserDefaultsClient) {
        let lock = AllocatedUnfairLock<[String: Data]>(initialState: [:])
        let client = testDependency(of: UserDefaultsClient.self) {
            $0.data = { key in lock.withLock { $0[key] } }
            $0.set = { value, key in
                let data = value as? Data
                lock.withLock { $0[key] = data }
            }
        }
        return (lock, client)
    }

    private func savedConfiguration(in lock: AllocatedUnfairLock<[String: Data]>) -> RunnerRotationConfiguration? {
        guard let data = lock.withLock({ $0[.runnerRotationConfiguration] }) else {
            return nil
        }
        return try? JSONDecoder().decode(RunnerRotationConfiguration.self, from: data)
    }

    @MainActor @Test
    func send_viewAppeared_loads_runner_bundle_list() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock { $0.runnerBundleLists.send(runnerBundleList) }
        let sut = RunnerRotationSettings(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared)
        #expect(sut.runnerBundleList == runnerBundleList)
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_rotationToggleSwitched_persists_configuration() async {
        let storage = makeStorage()
        let sut = RunnerRotationSettings(.testDependencies(userDefaultsClient: storage.client))
        await sut.send(.rotationToggleSwitched(true))
        #expect(sut.isEnabled)
        #expect(savedConfiguration(in: storage.lock) == .init(
            isEnabled: true,
            order: .sequential,
            interval: .fiveMinutes,
            runnerIDs: []
        ))
    }

    @MainActor @Test
    func send_orderPickerSelected_and_intervalPickerSelected_persist_configuration() async {
        let storage = makeStorage()
        let sut = RunnerRotationSettings(.testDependencies(userDefaultsClient: storage.client))
        await sut.send(.orderPickerSelected(.random))
        await sut.send(.intervalPickerSelected(.thirtyMinutes))
        #expect(savedConfiguration(in: storage.lock) == .init(
            isEnabled: false,
            order: .random,
            interval: .thirtyMinutes,
            runnerIDs: []
        ))
    }

    @MainActor @Test
    func send_runnerToggleSwitched_keeps_runner_list_order() async {
        let storage = makeStorage()
        let sut = RunnerRotationSettings(
            .testDependencies(userDefaultsClient: storage.client),
            configuration: .init(isEnabled: true, order: .sequential, interval: .oneMinute, runnerIDs: ["slime"]),
            runnerBundleList: runnerBundleList
        )
        await sut.send(.runnerToggleSwitched(Runner(kind: .cat), true))
        #expect(sut.runnerIDs == ["cat", "slime"])
        #expect(savedConfiguration(in: storage.lock)?.runnerIDs == ["cat", "slime"])
    }

    @MainActor @Test
    func send_runnerToggleSwitched_off_removes_runner() async {
        let sut = RunnerRotationSettings(
            .testDependencies(),
            configuration: .init(isEnabled: true, order: .sequential, interval: .oneMinute, runnerIDs: ["cat", "dog"]),
            runnerBundleList: runnerBundleList
        )
        await sut.send(.runnerToggleSwitched(Runner(kind: .cat), false))
        #expect(sut.runnerIDs == ["dog"])
        #expect(sut.needsMoreRunners)
    }

    @MainActor @Test
    func needsMoreRunners_is_false_when_rotation_is_disabled() {
        let sut = RunnerRotationSettings(
            .testDependencies(),
            configuration: .init(isEnabled: false, order: .sequential, interval: .oneMinute, runnerIDs: [])
        )
        #expect(!sut.needsMoreRunners)
    }
}
