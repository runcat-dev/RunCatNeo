import AllocatedUnfairLock
import ServiceManagement
import Testing

@testable import DataSource

struct LaunchAtLoginRepositoryTests {
    @Test
    func switchStatus_success_register() async {
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
    func switchStatus_success_unregister() async {
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
    func switchStatus_failure_register() async {
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
    func switchStatus_failure_unregister() async {
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
