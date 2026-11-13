import AllocatedUnfairLock
import Testing

@testable import DataSource
@testable import Model

struct DonationSettingsTests {
    @MainActor @Test
    func send_viewAppeared_forwards_action_to_parent() async {
        let receivedActionCount = AllocatedUnfairLock<Int>(initialState: 0)
        let sut = DonationSettings(.testDependencies()) { _ in
            receivedActionCount.withLock { $0 += 1 }
        }
        await sut.send(.viewAppeared("DonationSettingsTests"))
        #expect(receivedActionCount.withLock(\.self) == 1)
    }

    @MainActor @Test
    func init_reads_distributionChannel_from_app_state() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init(distributionChannel: .direct))
        let sut = DonationSettings(.testDependencies(appStateClient: .testDependency(appState)))
        #expect(sut.distributionChannel == .direct)
    }
}
