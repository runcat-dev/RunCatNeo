import AllocatedUnfairLock
import Testing

@testable import DataSource

struct UserDefaultsRepositoryTests {
    @Test
    func resetToDefaults_removes_all_known_keys() async {
        let removedKeys = AllocatedUnfairLock<[String]>(initialState: [])
        let userDefaultsClient = testDependency(of: UserDefaultsClient.self) {
            $0.removeObject = { key in
                removedKeys.withLock { $0.append(key) }
            }
        }
        let sut = UserDefaultsRepository(userDefaultsClient)
        sut.resetToDefaults()
        #expect(removedKeys.withLock(\.self) == [
            .runnerID,
            .speedDecreasesUnderLoad,
            .isFlippedHorizontally,
            .updateInterval,
            .systemMetricsConfiguration,
            .showsMetricsBar,
            .metricsBarConfiguration,
        ])
    }
}
