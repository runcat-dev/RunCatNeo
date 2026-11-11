import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct RunnerRotationServiceTests {
    private let runners = [Runner(kind: .cat), Runner(kind: .dog), Runner(kind: .slime)]

    private func makeUserDefaultsClient(configuration: RunnerRotationConfiguration) -> UserDefaultsClient {
        let data = try? JSONEncoder().encode(configuration)
        return testDependency(of: UserDefaultsClient.self) {
            $0.data = { key in key == .runnerRotationConfiguration ? data : nil }
        }
    }

    @Test
    func nextRunner_sequential_returns_runner_after_current() {
        let sut = RunnerRotationService(.testDependencies())
        #expect(sut.nextRunner(in: runners, after: "dog", order: .sequential) == Runner(kind: .slime))
    }

    @Test
    func nextRunner_sequential_wraps_to_first_after_last() {
        let sut = RunnerRotationService(.testDependencies())
        #expect(sut.nextRunner(in: runners, after: "slime", order: .sequential) == Runner(kind: .cat))
    }

    @Test
    func nextRunner_sequential_returns_first_when_current_is_not_in_list() {
        let sut = RunnerRotationService(.testDependencies())
        #expect(sut.nextRunner(in: runners, after: "mochi", order: .sequential) == Runner(kind: .cat))
    }

    @Test
    func nextRunner_random_picks_from_runners_other_than_current() {
        let requestedRange = AllocatedUnfairLock<Range<Int>?>(initialState: nil)
        let sut = RunnerRotationService(.testDependencies(
            randomClient: testDependency(of: RandomClient.self) {
                $0.int = { range in
                    requestedRange.withLock { $0 = range }
                    return range.upperBound - 1
                }
            }
        ))
        #expect(sut.nextRunner(in: runners, after: "cat", order: .random) == Runner(kind: .slime))
        #expect(requestedRange.withLock(\.self) == 0 ..< 2)
    }

    @Test
    func nextRunner_returns_nil_when_no_runner_is_available() {
        let sut = RunnerRotationService(.testDependencies())
        #expect(sut.nextRunner(in: [], after: "cat", order: .sequential) == nil)
        #expect(sut.nextRunner(in: [Runner(kind: .cat)], after: "cat", order: .random) == nil)
    }

    @Test
    func startRotation_does_not_start_task_when_disabled() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerRotationService(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: makeUserDefaultsClient(configuration: .init(
                isEnabled: false,
                order: .sequential,
                interval: .oneMinute,
                runnerIDs: ["cat", "dog"]
            ))
        ))
        sut.startRotation()
        #expect(appState.withLock(\.runnerRotationTask) == nil)
    }

    @Test
    func startRotation_does_not_start_task_with_fewer_than_two_runners() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerRotationService(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: makeUserDefaultsClient(configuration: .init(
                isEnabled: true,
                order: .sequential,
                interval: .oneMinute,
                runnerIDs: ["cat"]
            ))
        ))
        sut.startRotation()
        #expect(appState.withLock(\.runnerRotationTask) == nil)
    }

    @Test
    func startRotation_switches_to_next_runner_after_interval() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock { $0.runnerBundles.send(RunnerBundle(runner: .default, frame: .preset("cat-frame-0"))) }
        let sleptDurations = AllocatedUnfairLock<[Duration]>(initialState: [])
        let sut = RunnerRotationService(.testDependencies(
            appStateClient: .testDependency(appState),
            clockClient: testDependency(of: ClockClient.self) {
                $0.sleep = { duration in
                    let count = sleptDurations.withLock {
                        $0.append(duration)
                        return $0.count
                    }
                    if count > 1 {
                        throw CancellationError()
                    }
                }
            },
            userDefaultsClient: makeUserDefaultsClient(configuration: .init(
                isEnabled: true,
                order: .sequential,
                interval: .fiveMinutes,
                runnerIDs: ["cat", "dog"]
            ))
        ))
        sut.startRotation()
        await waitUntil { sleptDurations.withLock(\.count) == 2 }
        #expect(appState.withLock(\.runnerBundles.latestValue)?.runner == Runner(kind: .dog))
        #expect(sleptDurations.withLock(\.self) == [.seconds(300), .seconds(300)])
    }

    @Test
    func stopRotation_cancels_running_task() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let task = Task<Void, Never> {
            try? await Task.sleep(for: .seconds(60))
        }
        appState.withLock { $0.runnerRotationTask = task }
        let sut = RunnerRotationService(.testDependencies(appStateClient: .testDependency(appState)))
        sut.stopRotation()
        #expect(task.isCancelled)
        #expect(appState.withLock(\.runnerRotationTask) == nil)
    }
}
