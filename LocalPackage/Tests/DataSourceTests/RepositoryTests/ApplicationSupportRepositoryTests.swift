import AllocatedUnfairLock
import Foundation
import Testing
import UniformTypeIdentifiers

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
        #expect(createDirectoryCount.withLock(\.self) == 1)
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
        #expect(createDirectoryCount.withLock(\.self) == 0)
    }

    @Test
    func loadCustomRunners_returns_empty_when_file_does_not_exist() {
        let sut = ApplicationSupportRepository(.testValue, .testValue)
        #expect(sut.loadCustomRunners().isEmpty)
    }

    @Test
    func loadCustomRunners_returns_empty_when_read_fails() {
        let dataClient = testDependency(of: DataClient.self) {
            $0.read = { _ in throw URLError(.unknown) }
        }
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
        }
        let sut = ApplicationSupportRepository(dataClient, fileManagerClient)
        #expect(sut.loadCustomRunners().isEmpty)
    }

    @Test
    func loadCustomRunners_returns_empty_when_decode_fails() {
        let dataClient = testDependency(of: DataClient.self) {
            $0.read = { _ in Data("not json".utf8) }
        }
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
        }
        let sut = ApplicationSupportRepository(dataClient, fileManagerClient)
        #expect(sut.loadCustomRunners().isEmpty)
    }

    @Test
    func loadCustomRunners_reads_runners_from_customRunners_file() {
        let readURL = AllocatedUnfairLock<URL?>(initialState: nil)
        let json = """
            [
              {
                "id": "custom",
                "name": "Custom",
                "isTemplate": false,
                "frameOrder": [0, 1]
              }
            ]
            """
        let dataClient = testDependency(of: DataClient.self) {
            $0.read = { url in
                readURL.withLock { $0 = url }
                return Data(json.utf8)
            }
        }
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
        }
        let sut = ApplicationSupportRepository(dataClient, fileManagerClient)
        #expect(sut.loadCustomRunners() == [Runner(id: "custom", name: "Custom", isTemplate: false, frameOrder: .custom([0, 1]))])
        #expect(readURL.withLock(\.self)?.hasPathSuffix("RunCatNeo/CUSTOM_RUNNERS.json") == true)
    }

    @Test
    func loadCustomRunner_returns_runner_matching_id() {
        let json = """
            [
              {
                "id": "alpha",
                "name": "Alpha",
                "isTemplate": false,
                "frameOrder": [0, 1]
              },
              {
                "id": "beta",
                "name": "Beta",
                "isTemplate": false,
                "frameOrder": [0, 1]
              }
            ]
            """
        let dataClient = testDependency(of: DataClient.self) {
            $0.read = { _ in Data(json.utf8) }
        }
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
        }
        let sut = ApplicationSupportRepository(dataClient, fileManagerClient)
        #expect(sut.loadCustomRunner(of: "beta") == Runner(id: "beta", name: "Beta", isTemplate: false, frameOrder: .custom([0, 1])))
    }

    @Test
    func loadCustomRunner_returns_nil_when_id_is_not_found() {
        let json = """
            [
              {
                "id": "alpha",
                "name": "Alpha",
                "isTemplate": false,
                "frameOrder": [0, 1]
              }
            ]
            """
        let dataClient = testDependency(of: DataClient.self) {
            $0.read = { _ in Data(json.utf8) }
        }
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
        }
        let sut = ApplicationSupportRepository(dataClient, fileManagerClient)
        #expect(sut.loadCustomRunner(of: "missing") == nil)
    }

    @Test
    func saveCustomRunners_writes_sorted_json_to_customRunners_file() throws {
        let written = AllocatedUnfairLock<(data: Data, url: URL)?>(initialState: nil)
        let dataClient = testDependency(of: DataClient.self) {
            $0.write = { data, url in
                written.withLock { $0 = (data, url) }
            }
        }
        let sut = ApplicationSupportRepository(dataClient, .testValue)
        try sut.saveCustomRunners([Runner(id: "custom", name: "Custom", isTemplate: false, frameOrder: .custom([0, 1]))])
        let (data, url) = try #require(written.withLock { $0 })
        #expect(url.hasPathSuffix("RunCatNeo/CUSTOM_RUNNERS.json"))
        let expectedJSON = #"[{"frameOrder":[0,1],"id":"custom","isTemplate":false,"name":"Custom"}]"#
        #expect(String(decoding: data, as: UTF8.self) == expectedJSON)
    }

    @Test
    func saveCustomRunners_throws_when_write_fails() {
        let dataClient = testDependency(of: DataClient.self) {
            $0.write = { _, _ in throw URLError(.unknown) }
        }
        let sut = ApplicationSupportRepository(dataClient, .testValue)
        #expect(throws: URLError.self) {
            try sut.saveCustomRunners([])
        }
    }

    @Test
    func loadData_returns_nil_when_file_does_not_exist() {
        let sut = ApplicationSupportRepository(.testValue, .testValue)
        #expect(sut.loadData(directory: "alpha", fileName: "frame-0", fileType: .png) == nil)
    }

    @Test
    func loadData_returns_nil_when_read_fails() {
        let dataClient = testDependency(of: DataClient.self) {
            $0.read = { _ in throw URLError(.unknown) }
        }
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
        }
        let sut = ApplicationSupportRepository(dataClient, fileManagerClient)
        #expect(sut.loadData(directory: "alpha", fileName: "frame-0", fileType: .png) == nil)
    }

    @Test
    func loadData_returns_file_contents_when_file_exists() {
        let readURL = AllocatedUnfairLock<URL?>(initialState: nil)
        let dataClient = testDependency(of: DataClient.self) {
            $0.read = { url in
                readURL.withLock { $0 = url }
                return Data("image".utf8)
            }
        }
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
        }
        let sut = ApplicationSupportRepository(dataClient, fileManagerClient)
        #expect(sut.loadData(directory: "alpha", fileName: "frame-0", fileType: .png) == Data("image".utf8))
        #expect(readURL.withLock(\.self)?.hasPathSuffix("RunCatNeo/alpha/frame-0.png") == true)
    }

    @Test
    func saveData_creates_container_directory_when_it_does_not_exist() throws {
        let createdDirectoryURL = AllocatedUnfairLock<URL?>(initialState: nil)
        let writtenURL = AllocatedUnfairLock<URL?>(initialState: nil)
        let dataClient = testDependency(of: DataClient.self) {
            $0.write = { _, url in
                writtenURL.withLock { $0 = url }
            }
        }
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { $0.hasSuffix("RunCatNeo/") }
            $0.createDirectory = { url, _ in
                createdDirectoryURL.withLock { $0 = url }
            }
        }
        let sut = ApplicationSupportRepository(dataClient, fileManagerClient)
        try sut.saveData(directory: "alpha", fileName: "frame-0", fileType: .png, data: Data())
        #expect(createdDirectoryURL.withLock(\.self)?.hasPathSuffix("RunCatNeo/alpha") == true)
        #expect(writtenURL.withLock(\.self)?.hasPathSuffix("RunCatNeo/alpha/frame-0.png") == true)
    }

    @Test
    func saveData_does_not_create_container_directory_when_it_exists() throws {
        let createDirectoryCount = AllocatedUnfairLock<Int>(initialState: 0)
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
            $0.createDirectory = { _, _ in
                createDirectoryCount.withLock { $0 += 1 }
            }
        }
        let sut = ApplicationSupportRepository(.testValue, fileManagerClient)
        try sut.saveData(directory: "alpha", fileName: "frame-0", fileType: .png, data: Data())
        #expect(createDirectoryCount.withLock(\.self) == 0)
    }

    @Test
    func saveData_throws_when_write_fails() {
        let dataClient = testDependency(of: DataClient.self) {
            $0.write = { _, _ in throw URLError(.unknown) }
        }
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
        }
        let sut = ApplicationSupportRepository(dataClient, fileManagerClient)
        #expect(throws: URLError.self) {
            try sut.saveData(directory: "alpha", fileName: "frame-0", fileType: .png, data: Data())
        }
    }

    @Test
    func delete_removes_container_directory_when_it_exists() {
        let removedURL = AllocatedUnfairLock<URL?>(initialState: nil)
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in true }
            $0.removeItem = { url in
                removedURL.withLock { $0 = url }
            }
        }
        let sut = ApplicationSupportRepository(.testValue, fileManagerClient)
        sut.delete(directory: "alpha")
        #expect(removedURL.withLock(\.self)?.hasPathSuffix("RunCatNeo/alpha") == true)
    }

    @Test
    func delete_does_nothing_when_container_directory_does_not_exist() {
        let removeItemCount = AllocatedUnfairLock<Int>(initialState: 0)
        let fileManagerClient = testDependency(of: FileManagerClient.self) {
            $0.fileExists = { _ in false }
            $0.removeItem = { _ in
                removeItemCount.withLock { $0 += 1 }
            }
        }
        let sut = ApplicationSupportRepository(.testValue, fileManagerClient)
        sut.delete(directory: "alpha")
        #expect(removeItemCount.withLock(\.self) == 0)
    }
}

private extension URL {
    func hasPathSuffix(_ suffix: String) -> Bool {
        path(percentEncoded: false).hasSuffix(suffix)
    }
}
