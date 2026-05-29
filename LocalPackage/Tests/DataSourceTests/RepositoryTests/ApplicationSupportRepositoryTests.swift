import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource

struct ApplicationSupportRepositoryTests {
    @Test
    func init_if_ApplicationSupport_directory_does_not_exist_it_will_be_created() {
        let createDirectoryCount = AllocatedUnfairLock<Int>(initialState: 0)
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in false }
            $0.createDirectory = { _, _ in
                createDirectoryCount.withLock { $0 += 1 }
            }
        }
        let _ = ApplicationSupportRepository(.testValue, fileManagerClient)
        let actual = createDirectoryCount.withLock(\.self)
        #expect(actual == 1)
    }

    @Test
    func init_if_ApplicationSupport_directory_exists_nothing_happens() {
        let createDirectoryCount = AllocatedUnfairLock<Int>(initialState: 0)
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
            $0.createDirectory = { _, _ in
                createDirectoryCount.withLock { $0 += 1 }
            }
        }
        let _ = ApplicationSupportRepository(.testValue, fileManagerClient)
        let actual = createDirectoryCount.withLock(\.self)
        #expect(actual == 0)
    }
}
