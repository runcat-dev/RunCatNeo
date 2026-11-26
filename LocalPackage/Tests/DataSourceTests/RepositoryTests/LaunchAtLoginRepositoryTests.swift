import AllocatedUnfairLock
import ServiceManagement
import Testing

@testable import DataSource

struct LaunchAtLoginRepositoryTests {
    @Test
    func switchStatus_true_succeeds_when_register_succeeds() async {
        let status = AllocatedUnfairLock(initialState: false)
        let smAppServiceClient = testDependency(of: SMAppServiceClient.self) {
            $0.status = {
                status.withLock(\.self) ? .enabled : .notRegistered
            }
            $0.register = {
                status.withLock { $0 = true }
            }
        }
        let sut = LaunchAtLoginRepository(smAppServiceClient)
        #expect(throws: Never.self) {
            try sut.switchStatus(true).get()
        }
    }

    @Test
    func switchStatus_false_succeeds_when_unregister_succeeds() async {
        let status = AllocatedUnfairLock(initialState: true)
        let smAppServiceClient = testDependency(of: SMAppServiceClient.self) {
            $0.status = {
                status.withLock(\.self) ? .enabled : .notRegistered
            }
            $0.unregister = {
                status.withLock { $0 = false }
            }
        }
        let sut = LaunchAtLoginRepository(smAppServiceClient)
        #expect(throws: Never.self) {
            try sut.switchStatus(false).get()
        }
    }

    @Test
    func switchStatus_true_fails_with_current_status_when_register_throws() async {
        let status = AllocatedUnfairLock(initialState: false)
        let smAppServiceClient = testDependency(of: SMAppServiceClient.self) {
            $0.status = {
                status.withLock(\.self) ? .enabled : .notRegistered
            }
            $0.register = {
                throw NSError(
                    domain: SMAppServiceErrorDomain,
                    code: kSMErrorAuthorizationFailure
                )
            }
        }
        let sut = LaunchAtLoginRepository(smAppServiceClient)
        #expect(throws: LaunchAtLoginRepository.OperationError.switchFailed(false)) {
            try sut.switchStatus(true).get()
        }
    }

    @Test
    func switchStatus_false_fails_with_current_status_when_unregister_throws() async {
        let status = AllocatedUnfairLock(initialState: true)
        let smAppServiceClient = testDependency(of: SMAppServiceClient.self) {
            $0.status = {
                status.withLock(\.self) ? .enabled : .notRegistered
            }
            $0.unregister = {
                throw NSError(
                    domain: SMAppServiceErrorDomain,
                    code: kSMErrorAuthorizationFailure
                )
            }
        }
        let sut = LaunchAtLoginRepository(smAppServiceClient)
        #expect(throws: LaunchAtLoginRepository.OperationError.switchFailed(true)) {
            try sut.switchStatus(false).get()
        }
    }
}
