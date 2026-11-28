import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct StepCountServiceTests {
    private let now = Date(timeIntervalSince1970: 1_000_000_000)
    private let frameCount = 5

    private func makeService(
        appState: AllocatedUnfairLock<AppState>,
        dataClient: DataClient = .testValue,
        fileManagerClient: FileManagerClient = .testValue,
        isStepCounterEnabled: Bool = true
    ) -> StepCountService {
        let fixedNow = now
        return StepCountService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: dataClient,
            dateClient: testDependency(of: DateClient.self) {
                $0.now = { fixedNow }
            },
            fileManagerClient: fileManagerClient,
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.bool = { _ in isStepCounterEnabled }
            }
        ))
    }

    private func statistics(withSteps steps: Int, at date: Date) -> StepStatistics {
        let dayKey = StepCountService.dayKey(for: date)
        return StepStatistics(
            records: [StepRecord(dayKey: dayKey, steps: steps)],
            todayKey: dayKey,
            stepsInLastMinute: steps
        )
    }

    @Test
    func steps_returns_zero_when_interval_is_not_positive() {
        #expect(StepCountService.steps(speed: 5, frameCount: frameCount, interval: 0) == 0)
        #expect(StepCountService.steps(speed: 5, frameCount: frameCount, interval: -1) == 0)
    }

    @Test
    func steps_returns_zero_when_the_runner_cannot_animate() {
        #expect(StepCountService.steps(speed: 5, frameCount: 0, interval: 10) == 0)
        #expect(StepCountService.steps(speed: 5, frameCount: 1, interval: 10) == 0)
    }

    @Test
    func steps_counts_one_step_per_animation_cycle() {
        #expect(StepCountService.steps(speed: 5, frameCount: 5, interval: 10) == 20)
        #expect(StepCountService.steps(speed: 1, frameCount: 5, interval: 10) == 4)
    }

    @Test
    func interval_clamps_to_the_allowed_range() {
        #expect(StepCountService.interval(from: nil, to: now) == 0)
        #expect(StepCountService.interval(from: now, to: now.addingTimeInterval(-1)) == 0)
        #expect(StepCountService.interval(from: now, to: now.addingTimeInterval(600)) == 60)
        #expect(StepCountService.interval(from: now, to: now.addingTimeInterval(5)) == 5)
    }

    @Test
    func dayKey_formats_the_date_in_the_given_calendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        #expect(StepCountService.dayKey(for: now, calendar: calendar) == "2001-09-09")
    }

    @Test
    func pruned_keeps_only_the_most_recent_records() {
        let records = (0 ..< 400).map { StepRecord(dayKey: String(format: "2026-%03d", $0), steps: 1) }
        let pruned = StepCountService.pruned(records)
        #expect(pruned.count == StepCountService.retentionDays)
        #expect(pruned.first?.dayKey == "2026-034")
        #expect(pruned.last?.dayKey == "2026-399")
    }

    @Test
    func bootstrap_publishes_persisted_records_for_today() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let todayKey = StepCountService.dayKey(for: now)
        let records = [
            StepRecord(dayKey: "2026-11-27", steps: 120),
            StepRecord(dayKey: todayKey, steps: 42),
        ]
        let data = try JSONEncoder().encode(records)
        let sut = makeService(
            appState: appState,
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in data }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { _ in true }
            }
        )
        sut.bootstrap()
        #expect(appState.withLock(\.stepStatistics.latestValue) == StepStatistics(records: records, todayKey: todayKey))
    }

    @Test
    func accumulate_adds_steps_for_the_elapsed_time() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = makeService(appState: appState)
        let date = now.addingTimeInterval(5)
        sut.bootstrap()
        sut.accumulate(speed: 5, frameCount: frameCount, at: date)
        #expect(appState.withLock(\.stepStatistics.latestValue) == statistics(withSteps: 10, at: date))
    }

    @Test
    func accumulate_carries_fractional_steps_over_to_the_next_sample() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = makeService(appState: appState)
        sut.bootstrap()
        sut.accumulate(speed: 2, frameCount: frameCount, at: now.addingTimeInterval(2))
        #expect(appState.withLock(\.stepStatistics.latestValue) == statistics(withSteps: 1, at: now))
        sut.accumulate(speed: 2, frameCount: frameCount, at: now.addingTimeInterval(4))
        #expect(appState.withLock(\.stepStatistics.latestValue) == statistics(withSteps: 3, at: now))
    }

    @Test
    func accumulate_creates_a_new_record_on_the_next_day() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = makeService(appState: appState)
        let firstDay = now.addingTimeInterval(5)
        let nextDay = now.addingTimeInterval(86_400)
        let firstDayKey = StepCountService.dayKey(for: firstDay)
        let nextDayKey = StepCountService.dayKey(for: nextDay)
        sut.bootstrap()
        sut.accumulate(speed: 1, frameCount: frameCount, at: firstDay)
        sut.accumulate(speed: 1, frameCount: frameCount, at: nextDay)
        #expect(appState.withLock(\.stepStatistics.latestValue) == StepStatistics(
            records: [
                StepRecord(dayKey: firstDayKey, steps: 2),
                StepRecord(dayKey: nextDayKey, steps: 24),
            ],
            todayKey: nextDayKey,
            stepsInLastMinute: 24
        ))
    }

    @Test
    func accumulate_does_not_count_more_than_the_maximum_sample_interval() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = makeService(appState: appState)
        let date = now.addingTimeInterval(3_600)
        sut.bootstrap()
        sut.accumulate(speed: 1, frameCount: frameCount, at: date)
        #expect(appState.withLock(\.stepStatistics.latestValue) == statistics(withSteps: 24, at: date))
    }

    @Test
    func accumulate_saves_the_records_after_the_save_interval() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let writes = AllocatedUnfairLock<[Data]>(initialState: [])
        let sut = makeService(
            appState: appState,
            dataClient: testDependency(of: DataClient.self) {
                $0.write = { data, _ in
                    writes.withLock { $0.append(data) }
                }
            }
        )
        sut.bootstrap()
        sut.accumulate(speed: 1, frameCount: frameCount, at: now.addingTimeInterval(5))
        #expect(writes.withLock(\.self).isEmpty)
        sut.accumulate(speed: 1, frameCount: frameCount, at: now.addingTimeInterval(40))
        let data = try #require(writes.withLock { $0.first })
        #expect(try JSONDecoder().decode([StepRecord].self, from: data).map(\.steps) == [16])
    }

    @Test
    func flush_writes_the_records_that_have_not_been_saved_yet() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let writes = AllocatedUnfairLock<[Data]>(initialState: [])
        let sut = makeService(
            appState: appState,
            dataClient: testDependency(of: DataClient.self) {
                $0.write = { data, _ in
                    writes.withLock { $0.append(data) }
                }
            }
        )
        sut.bootstrap()
        sut.accumulate(speed: 1, frameCount: frameCount, at: now.addingTimeInterval(5))
        sut.flush()
        let data = try #require(writes.withLock { $0.first })
        #expect(try JSONDecoder().decode([StepRecord].self, from: data).map(\.steps) == [2])
        sut.flush()
        #expect(writes.withLock(\.self).count == 1)
    }

    @Test
    func bootstrap_publishes_empty_statistics_when_step_counter_is_disabled() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let data = try JSONEncoder().encode([StepRecord(dayKey: StepCountService.dayKey(for: now), steps: 42)])
        let sut = makeService(
            appState: appState,
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in data }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { _ in true }
            },
            isStepCounterEnabled: false
        )
        sut.bootstrap()
        #expect(appState.withLock(\.stepStatistics.latestValue) == StepStatistics.empty)
    }

    @Test
    func accumulate_does_not_add_steps_when_step_counter_is_disabled() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = makeService(appState: appState, isStepCounterEnabled: false)
        sut.bootstrap()
        sut.accumulate(speed: 5, frameCount: frameCount, at: now.addingTimeInterval(5))
        #expect(appState.withLock(\.stepStatistics.latestValue) == StepStatistics.empty)
        #expect(appState.withLock(\.stepLedger.records).isEmpty)
    }

    @Test
    func accumulate_resumes_from_the_pause_point_when_step_counter_is_enabled_again() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let isEnabled = AllocatedUnfairLock<Bool>(initialState: false)
        let todayKey = StepCountService.dayKey(for: now)
        let fixedNow = now
        let data = try JSONEncoder().encode([StepRecord(dayKey: todayKey, steps: 100)])
        let sut = StepCountService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in data }
            },
            dateClient: testDependency(of: DateClient.self) {
                $0.now = { fixedNow }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { _ in true }
            },
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.bool = { _ in isEnabled.withLock { $0 } }
            }
        ))
        sut.bootstrap()
        sut.accumulate(speed: 1, frameCount: frameCount, at: now.addingTimeInterval(60))
        #expect(appState.withLock(\.stepStatistics.latestValue) == StepStatistics.empty)
        isEnabled.withLock { $0 = true }
        sut.accumulate(speed: 1, frameCount: frameCount, at: now.addingTimeInterval(65))
        #expect(appState.withLock(\.stepStatistics.latestValue) == StepStatistics(
            records: [StepRecord(dayKey: todayKey, steps: 102)],
            todayKey: todayKey,
            stepsInLastMinute: 2
        ))
    }

    @Test
    func accumulate_forgets_steps_that_are_older_than_one_minute() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = makeService(appState: appState)
        sut.bootstrap()
        sut.accumulate(speed: 5, frameCount: frameCount, at: now.addingTimeInterval(5))
        sut.accumulate(speed: 5, frameCount: frameCount, at: now.addingTimeInterval(30))
        #expect(appState.withLock(\.stepStatistics.latestValue)?.stepsInLastMinute == 60)
        sut.accumulate(speed: 5, frameCount: frameCount, at: now.addingTimeInterval(70))
        #expect(appState.withLock(\.stepStatistics.latestValue)?.stepsInLastMinute == 130)
        sut.accumulate(speed: 5, frameCount: frameCount, at: now.addingTimeInterval(95))
        #expect(appState.withLock(\.stepStatistics.latestValue)?.stepsInLastMinute == 130)
    }
}
