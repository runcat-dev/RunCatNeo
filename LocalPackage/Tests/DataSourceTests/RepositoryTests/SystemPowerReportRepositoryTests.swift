import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource

struct SystemPowerReportRepositoryTests {
    @Test
    func read_requests_only_a_bounded_power_report() {
        let command = AllocatedUnfairLock<[String]>(initialState: [])
        let data = Data("report".utf8)
        let sut = SystemPowerReportRepository(testDependency(of: ProcessClient.self) {
            $0.run = { process in
                command.withLock {
                    $0 = [process.executableURL?.path ?? ""] + (process.arguments ?? [])
                        + [process.environment?["LC_ALL"] ?? ""]
                }
            }
            $0.readToEnd = { _ in data }
        })
        #expect(sut.read() == data)
        #expect(command.withLock(\.self) == [
            "/usr/sbin/system_profiler", "SPPowerDataType", "-json",
            "-detailLevel", "mini", "-timeout", "10", "C",
        ])
    }

    @Test
    func read_discards_output_from_a_failed_process() {
        let sut = SystemPowerReportRepository(testDependency(of: ProcessClient.self) {
            $0.readToEnd = { _ in Data("partial report".utf8) }
            $0.terminationStatus = { _ in 1 }
        })
        #expect(sut.read() == nil)
    }

    @Test
    func read_returns_nil_when_process_launch_fails() {
        let sut = SystemPowerReportRepository(testDependency(of: ProcessClient.self) {
            $0.run = { _ in throw CocoaError(.executableNotLoadable) }
        })
        #expect(sut.read() == nil)
    }

    @Test
    func read_terminates_a_running_child_when_output_reading_fails() {
        let terminationCount = AllocatedUnfairLock(initialState: 0)
        let sut = SystemPowerReportRepository(testDependency(of: ProcessClient.self) {
            $0.readToEnd = { _ in throw CocoaError(.fileReadUnknown) }
            $0.isRunning = { _ in true }
            $0.terminate = { _ in terminationCount.withLock { $0 += 1 } }
        })
        #expect(sut.read() == nil)
        #expect(terminationCount.withLock(\.self) == 1)
    }
}
