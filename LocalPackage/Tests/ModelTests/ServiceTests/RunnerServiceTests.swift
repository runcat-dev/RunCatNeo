import AllocatedUnfairLock
import Foundation
import SystemInfoKit
import Testing

@testable import DataSource
@testable import Model

struct RunnerServiceTests {
    @Test
    func update_preset_runner_sends_bundle_with_preset_frames_and_stores_runnerID() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let setCallStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerService(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.set = { value, key in
                    let entry = "set: \(key) = \(value ?? "nil")"
                    setCallStack.withLock { $0.append(entry) }
                }
            }
        ))
        try sut.update(runner: Runner(kind: .cat))
        let expected = RunnerBundle(
            runner: .default,
            frames: [
                .preset("cat-frame-0"),
                .preset("cat-frame-1"),
                .preset("cat-frame-2"),
                .preset("cat-frame-3"),
                .preset("cat-frame-4"),
            ]
        )
        #expect(appState.withLock(\.runnerBundles.latestValue) == expected)
        #expect(setCallStack.withLock(\.self) == ["set: RUNNER_ID = cat"])
    }

    @Test
    func update_custom_runner_sends_bundle_with_loaded_frame_data() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let runner = Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0]))
        let sut = RunnerService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data("frame".utf8) }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { _ in true }
            }
        ))
        try sut.update(runner: runner)
        #expect(appState.withLock(\.runnerBundles.latestValue) == RunnerBundle(runner: runner, frames: [.custom(Data("frame".utf8))]))
    }

    @Test
    func update_custom_runner_throws_when_frame_data_is_missing() {
        let runner = Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0]))
        let sut = RunnerService(.testDependencies(
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { $0.hasSuffix("RunCatNeo/") }
            }
        ))
        #expect(throws: RCNError.customRunner(.loadingFailed)) {
            try sut.update(runner: runner)
        }
    }

    @Test
    func loadRunnerBundleList_sends_thumbnail_bundles_of_all_preset_runners() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerService(.testDependencies(appStateClient: .testDependency(appState)))
        sut.loadRunnerBundleList()
        let bundleList = appState.withLock(\.runnerBundleLists.latestValue)
        #expect(bundleList?.count == RunnerKind.allCases.count)
        #expect(bundleList?.first == RunnerBundle(runner: .default, frame: .preset("cat-frame-0")))
    }

    @Test
    func loadRunnerBundleList_appends_custom_runners_after_presets() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let json = """
            [
              {
                "id": "custom-runner",
                "name": "Custom Runner",
                "isTemplate": false,
                "frameOrder": [0]
              }
            ]
            """
        let sut = RunnerService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { url in
                    url.hasPathSuffix("CUSTOM_RUNNERS.json") ? Data(json.utf8) : Data("frame".utf8)
                }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { _ in true }
            }
        ))
        sut.loadRunnerBundleList()
        let bundleList = appState.withLock(\.runnerBundleLists.latestValue)
        #expect(bundleList?.count == RunnerKind.allCases.count + 1)
        #expect(bundleList?.last == RunnerBundle(
            runner: Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0])),
            frame: .custom(Data("frame".utf8))
        ))
    }

    @Test
    func loadRunnerBundleList_marks_custom_runner_as_broken_when_frame_data_is_missing() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let json = """
            [
              {
                "id": "custom-runner",
                "name": "Custom Runner",
                "isTemplate": false,
                "frameOrder": [0]
              }
            ]
            """
        let sut = RunnerService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data(json.utf8) }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { $0.hasSuffix("RunCatNeo/") || $0.hasSuffix("CUSTOM_RUNNERS.json") }
            }
        ))
        sut.loadRunnerBundleList()
        #expect(appState.withLock(\.runnerBundleLists.latestValue)?.last == RunnerBundle(
            runner: Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0])),
            frame: .broken
        ))
    }

    @Test
    func setup_uses_preset_runner_stored_in_user_defaults() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerService(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.string = { _ in "parrot" }
            }
        ))
        try sut.setup()
        #expect(appState.withLock(\.runnerBundles.latestValue)?.runner == Runner(kind: .parrot))
        #expect(appState.withLock(\.runnerBundleLists.latestValue)?.count == RunnerKind.allCases.count)
    }

    @Test
    func setup_uses_custom_runner_stored_in_user_defaults() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let json = """
            [
              {
                "id": "custom-runner",
                "name": "Custom Runner",
                "isTemplate": false,
                "frameOrder": [0]
              }
            ]
            """
        let sut = RunnerService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { url in
                    url.hasPathSuffix("CUSTOM_RUNNERS.json") ? Data(json.utf8) : Data("frame".utf8)
                }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { _ in true }
            },
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.string = { _ in "custom-runner" }
            }
        ))
        try sut.setup()
        #expect(appState.withLock(\.runnerBundles.latestValue) == RunnerBundle(
            runner: Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0])),
            frames: [.custom(Data("frame".utf8))]
        ))
    }

    @Test
    func setup_falls_back_to_default_runner_when_custom_frames_are_missing() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let json = """
            [
              {
                "id": "custom-runner",
                "name": "Custom Runner",
                "isTemplate": false,
                "frameOrder": [0]
              }
            ]
            """
        let sut = RunnerService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data(json.utf8) }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { $0.hasSuffix("RunCatNeo/") || $0.hasSuffix("CUSTOM_RUNNERS.json") }
            },
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.string = { _ in "custom-runner" }
            }
        ))
        try sut.setup()
        #expect(appState.withLock(\.runnerBundles.latestValue)?.runner == Runner.default)
    }

    @Test
    func setup_falls_back_to_default_runner_when_stored_runnerID_is_unknown() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerService(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.string = { _ in "unknown" }
            }
        ))
        try sut.setup()
        #expect(appState.withLock(\.runnerBundles.latestValue)?.runner == Runner.default)
    }

    @Test
    func updateRunnerSpeed_sends_speed_proportional_to_cpu_usage() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerService(.testDependencies(appStateClient: .testDependency(appState)))
        sut.updateRunnerSpeed(from: CPUInfo(percentage: Percentage(rawValue: 0.5), system: .zero, user: .zero, idle: .zero))
        #expect(appState.withLock(\.runnerSpeeds.latestValue) == 10.0)
    }

    @Test
    func updateRunnerSpeed_sends_minimum_speed_when_cpuInfo_is_nil() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerService(.testDependencies(appStateClient: .testDependency(appState)))
        sut.updateRunnerSpeed(from: nil)
        #expect(appState.withLock(\.runnerSpeeds.latestValue) == 1.0)
    }

    @Test
    func updateRunnerSpeed_clamps_speed_at_full_cpu_usage() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerService(.testDependencies(appStateClient: .testDependency(appState)))
        sut.updateRunnerSpeed(from: CPUInfo(percentage: Percentage(rawValue: 1.0), system: .zero, user: .zero, idle: .zero))
        #expect(appState.withLock(\.runnerSpeeds.latestValue) == 20.0)
    }

    @Test
    func updateRunnerSpeed_inverts_speed_when_speedDecreasesUnderLoad_is_enabled() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerService(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.bool = { _ in true }
            }
        ))
        sut.updateRunnerSpeed(from: CPUInfo(percentage: Percentage(rawValue: 0.5), system: .zero, user: .zero, idle: .zero))
        #expect(appState.withLock(\.runnerSpeeds.latestValue) == 5.5)
    }

    @Test
    func resendCurrentRunnerBundle_resends_latest_bundle() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let bundle = RunnerBundle(runner: .default, frame: .preset("cat-frame-0"))
        appState.withLock { $0.runnerBundles.send(bundle) }
        let sut = RunnerService(.testDependencies(appStateClient: .testDependency(appState)))
        let received = AllocatedUnfairLock<[RunnerBundle]>(initialState: [])
        let task = Task {
            let stream = appState.withLock(\.runnerBundles.stream)
            for await value in stream {
                received.withLock { $0.append(value) }
            }
        }
        try? await Task.sleep(for: .milliseconds(50))
        sut.resendCurrentRunnerBundle()
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        #expect(received.withLock(\.self) == [bundle, bundle])
    }

    @Test
    func resendCurrentRunnerBundle_does_nothing_when_no_bundle_was_sent() {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let sut = RunnerService(.testDependencies(appStateClient: .testDependency(appState)))
        sut.resendCurrentRunnerBundle()
        #expect(appState.withLock(\.runnerBundles.latestValue) == nil)
    }

    @Test
    func validate_returns_false_when_custom_runner_name_already_exists() {
        let json = """
            [
              {
                "id": "custom-runner",
                "name": "Custom Runner",
                "isTemplate": false,
                "frameOrder": [0]
              }
            ]
            """
        let sut = RunnerService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { _ in Data(json.utf8) }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { _ in true }
            }
        ))
        #expect(sut.validate(customRunnerName: "Custom Runner") == false)
    }

    @Test
    func validate_returns_true_when_custom_runner_name_is_not_used() {
        let sut = RunnerService(.testDependencies())
        #expect(sut.validate(customRunnerName: "Custom Runner") == true)
    }

    @Test
    func convertToCustomFrame_returns_custom_frame_with_converted_data() throws {
        let sut = RunnerService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.convert = { _, _ in Data("png".utf8) }
            }
        ))
        #expect(try sut.convertToCustomFrame(from: FrameImage.dummy()) == .custom(Data("png".utf8)))
    }

    @Test
    func convertToCustomFrame_throws_when_conversion_fails() {
        let sut = RunnerService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.convert = { _, _ in throw URLError(.unknown) }
            }
        ))
        #expect(throws: URLError.self) {
            try sut.convertToCustomFrame(from: FrameImage.dummy())
        }
    }

    @Test
    func save_customRunner_writes_frame_files_and_appended_custom_runners_file() throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let written = AllocatedUnfairLock<[(data: Data, url: URL)]>(initialState: [])
        let sut = RunnerService(.testDependencies(
            appStateClient: .testDependency(appState),
            dataClient: testDependency(of: DataClient.self) {
                $0.convert = { _, _ in Data("png".utf8) }
                $0.write = { data, url in
                    written.withLock { $0.append((data, url)) }
                }
            }
        ))
        let runner = Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0, 1]))
        try sut.save(customRunner: runner, with: [FrameImage.dummy(), FrameImage.dummy()])
        let writtenFiles = written.withLock(\.self)
        #expect(writtenFiles.map(\.url.lastPathComponent) == ["frame-0.png", "frame-1.png", "CUSTOM_RUNNERS.json"])
        #expect(writtenFiles.first?.data == Data("png".utf8))
        let expectedJSON = #"[{"frameOrder":[0,1],"id":"custom-runner","isTemplate":false,"name":"Custom Runner"}]"#
        #expect(writtenFiles.last.map { String(decoding: $0.data, as: UTF8.self) } == expectedJSON)
        #expect(appState.withLock(\.runnerBundleLists.latestValue) != nil)
    }

    @Test
    func delete_customRunner_removes_runner_and_its_directory() throws {
        let json = """
            [
              {
                "id": "custom-runner",
                "name": "Custom Runner",
                "isTemplate": false,
                "frameOrder": [0]
              },
              {
                "id": "other-runner",
                "name": "Other Runner",
                "isTemplate": false,
                "frameOrder": [0]
              }
            ]
            """
        let writtenJSON = AllocatedUnfairLock<String?>(initialState: nil)
        let removedURL = AllocatedUnfairLock<URL?>(initialState: nil)
        let sut = RunnerService(.testDependencies(
            dataClient: testDependency(of: DataClient.self) {
                $0.read = { url in
                    url.hasPathSuffix("CUSTOM_RUNNERS.json") ? Data(json.utf8) : Data("frame".utf8)
                }
                $0.write = { data, _ in
                    writtenJSON.withLock { $0 = String(decoding: data, as: UTF8.self) }
                }
            },
            fileManagerClient: testDependency(of: FileManagerClient.self) {
                $0.fileExists = { _ in true }
                $0.removeItem = { url in
                    removedURL.withLock { $0 = url }
                }
            }
        ))
        try sut.delete(customRunner: Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0])))
        let expectedJSON = #"[{"frameOrder":[0],"id":"other-runner","isTemplate":false,"name":"Other Runner"}]"#
        #expect(writtenJSON.withLock(\.self) == expectedJSON)
        #expect(removedURL.withLock(\.self)?.hasPathSuffix("RunCatNeo/custom-runner") == true)
    }
}
