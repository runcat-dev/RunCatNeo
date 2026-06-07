import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct DonationSettingsTests {
    @MainActor @Test
    func send_task_forwards_action_to_parent() async {
        let receivedActionCount = AllocatedUnfairLock<Int>(initialState: 0)
        let sut = DonationSettings(.testDependencies()) { _ in
            receivedActionCount.withLock { $0 += 1 }
        }
        await sut.send(.task("DonationSettingsTests"))
        #expect(receivedActionCount.withLock(\.self) == 1)
    }

    @MainActor @Test
    func send_donationFailed_completes_and_forwards_action() async {
        let receivedActionCount = AllocatedUnfairLock<Int>(initialState: 0)
        let sut = DonationSettings(.testDependencies()) { _ in
            receivedActionCount.withLock { $0 += 1 }
        }
        await sut.send(.donationFailed(CocoaError(.fileReadUnknown)))
        #expect(receivedActionCount.withLock(\.self) == 1)
    }
}
