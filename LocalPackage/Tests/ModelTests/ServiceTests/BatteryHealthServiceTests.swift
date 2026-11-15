import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct BatteryHealthServiceTests {
    private static let report = Data("""
        {"SPPowerDataType":[{"sppower_battery_health_info":{"sppower_battery_health_maximum_capacity":"90%"}}]}
        """.utf8)

    @Test
    func maximumCapacityPercent_caches_success_for_five_minutes() async {
        let now = AllocatedUnfairLock(initialState: Date(timeIntervalSince1970: 1_000))
        let readCount = AllocatedUnfairLock(initialState: 0)
        let sut = BatteryHealthService(.testDependencies(
            dateClient: testDependency(of: DateClient.self) {
                $0.now = { now.withLock(\.self) }
            },
            processClient: testDependency(of: ProcessClient.self) {
                $0.readToEnd = { _ in
                    readCount.withLock { $0 += 1 }
                    return Self.report
                }
            }
        ))
        #expect(await sut.maximumCapacityPercent() == 90)
        now.withLock { $0 += 299 }
        #expect(await sut.maximumCapacityPercent() == 90)
        #expect(readCount.withLock(\.self) == 1)
        now.withLock { $0 += 1 }
        #expect(await sut.maximumCapacityPercent() == 90)
        #expect(readCount.withLock(\.self) == 2)
    }

    @Test
    func maximumCapacityPercent_retries_missing_health_after_thirty_seconds() async {
        let now = AllocatedUnfairLock(initialState: Date(timeIntervalSince1970: 1_000))
        let report = AllocatedUnfairLock(initialState: Data())
        let sut = BatteryHealthService(.testDependencies(
            dateClient: testDependency(of: DateClient.self) {
                $0.now = { now.withLock(\.self) }
            },
            processClient: testDependency(of: ProcessClient.self) {
                $0.readToEnd = { _ in report.withLock(\.self) }
            }
        ))
        #expect(await sut.maximumCapacityPercent() == nil)
        report.withLock { $0 = Self.report }
        now.withLock { $0 += 29 }
        #expect(await sut.maximumCapacityPercent() == nil)
        now.withLock { $0 += 1 }
        #expect(await sut.maximumCapacityPercent() == 90)
    }

    @Test
    func maximumCapacityPercent_discards_expired_health_when_refresh_fails() async {
        let now = AllocatedUnfairLock(initialState: Date(timeIntervalSince1970: 1_000))
        let report = AllocatedUnfairLock<Data?>(initialState: Self.report)
        let sut = BatteryHealthService(.testDependencies(
            dateClient: testDependency(of: DateClient.self) {
                $0.now = { now.withLock(\.self) }
            },
            processClient: testDependency(of: ProcessClient.self) {
                $0.readToEnd = { _ in report.withLock(\.self) }
            }
        ))
        #expect(await sut.maximumCapacityPercent() == 90)
        report.withLock { $0 = nil }
        now.withLock { $0 += 300 }
        #expect(await sut.maximumCapacityPercent() == nil)
    }

    @Test
    func maximumCapacityPercent_shares_concurrent_report_reads() async {
        let readCount = AllocatedUnfairLock(initialState: 0)
        let releaseRead = DispatchSemaphore(value: 0)
        let sut = BatteryHealthService(.testDependencies(
            processClient: testDependency(of: ProcessClient.self) {
                $0.readToEnd = { _ in
                    readCount.withLock { $0 += 1 }
                    _ = releaseRead.wait(timeout: .now() + 2)
                    return Self.report
                }
            }
        ))
        async let first = sut.maximumCapacityPercent()
        await waitUntil { readCount.withLock(\.self) == 1 }
        async let second = sut.maximumCapacityPercent()
        releaseRead.signal()
        #expect(await [first, second] == [90, 90])
        #expect(readCount.withLock(\.self) == 1)
    }
}
