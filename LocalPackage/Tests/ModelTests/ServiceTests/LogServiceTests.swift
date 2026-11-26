import AllocatedUnfairLock
import Testing

@testable import DataSource
@testable import Model

struct LogServiceTests {
    @Test
    func bootstrap_bootstraps_logging_system_only_once() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let count = AllocatedUnfairLock(initialState: 0)
        let sut = LogService(.testDependencies(
            appStateClient: .testDependency(appState),
            loggingSystemClient: testDependency(of: LoggingSystemClient.self) {
                $0.bootstrap = { _ in count.withLock { $0 += 1 } }
            }
        ))
        sut.bootstrap()
        sut.bootstrap()
        #expect(count.withLock(\.self) == 1)
    }
}
