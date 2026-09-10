import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct CustomRunnerSettingsTests {
    private var customRunner: Runner {
        Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0]))
    }

    @MainActor @Test
    func send_viewAppeared_filters_custom_runners() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let customBundle = RunnerBundle(runner: customRunner, frame: .custom(Data()))
        appState.withLock {
            $0.runnerBundleLists.send([
                RunnerBundle(runner: .default, frame: .preset("cat-frame-0")),
                customBundle,
            ])
        }
        let sut = CustomRunnerSettings(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared)
        #expect(sut.customRunnerBundleList == [customBundle])
    }

    @MainActor @Test
    func send_deleteButtonTapped_keeps_list_when_runner_is_in_use() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let bundle = RunnerBundle(runner: customRunner, frame: .custom(Data()))
        appState.withLock { $0.runnerBundles.send(bundle) }
        let sut = CustomRunnerSettings(
            .testDependencies(appStateClient: .testDependency(appState)),
            customRunnerBundleList: [bundle]
        )
        await sut.send(.deleteButtonTapped(customRunner))
        #expect(sut.customRunnerBundleList == [bundle])
    }

    @MainActor @Test
    func send_deleteButtonTapped_removes_selected_runner() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: .default, frame: .preset("cat-frame-0")))
        }
        let sut = CustomRunnerSettings(
            .testDependencies(appStateClient: .testDependency(appState)),
            customRunnerBundleList: [RunnerBundle(runner: customRunner, frame: .custom(Data()))]
        )
        await sut.send(.deleteButtonTapped(customRunner))
        #expect(sut.customRunnerBundleList.isEmpty)
    }

    @MainActor @Test
    func send_customRunnerRowMoved_reorders_list_and_persists_new_order() async {
        let json = """
            [
              {
                "id": "first-runner",
                "name": "First Runner",
                "isTemplate": false,
                "frameOrder": [0]
              },
              {
                "id": "second-runner",
                "name": "Second Runner",
                "isTemplate": false,
                "frameOrder": [0]
              }
            ]
            """
        let writtenJSON = AllocatedUnfairLock<String?>(initialState: nil)
        let firstBundle = RunnerBundle(
            runner: Runner(id: "first-runner", name: "First Runner", isTemplate: false, frameOrder: .custom([0])),
            frame: .custom(Data())
        )
        let secondBundle = RunnerBundle(
            runner: Runner(id: "second-runner", name: "Second Runner", isTemplate: false, frameOrder: .custom([0])),
            frame: .custom(Data())
        )
        let sut = CustomRunnerSettings(
            .testDependencies(
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
                }
            ),
            customRunnerBundleList: [firstBundle, secondBundle]
        )
        await sut.send(.customRunnerRowMoved(IndexSet(integer: 1), 0))
        #expect(sut.customRunnerBundleList == [secondBundle, firstBundle])
        let expectedJSON = #"[{"frameOrder":[0],"id":"second-runner","isTemplate":false,"name":"Second Runner"},"#
            + #"{"frameOrder":[0],"id":"first-runner","isTemplate":false,"name":"First Runner"}]"#
        #expect(writtenJSON.withLock(\.self) == expectedJSON)
    }

    @MainActor @Test
    func send_addCustomRunnerButtonTapped_creates_editor() async {
        let sut = CustomRunnerSettings(.testDependencies())
        await sut.send(.addCustomRunnerButtonTapped(.testDependencies()))
        #expect(sut.customRunnerEditor != nil)
    }

    @MainActor @Test
    func send_customRunnerEditor_cancelButtonTapped_closes_editor() async {
        let sut = CustomRunnerSettings(
            .testDependencies(),
            customRunnerEditor: CustomRunnerEditor(.testDependencies(), id: .init())
        )
        await sut.send(.customRunnerEditor(.cancelButtonTapped))
        #expect(sut.customRunnerEditor == nil)
    }

    @MainActor @Test
    func send_customRunnerEditor_customRunnerAdded_appends_bundle_and_closes_editor() async {
        let bundle = RunnerBundle(runner: customRunner, frame: .custom(Data()))
        let sut = CustomRunnerSettings(
            .testDependencies(),
            customRunnerEditor: CustomRunnerEditor(.testDependencies(), id: .init())
        )
        await sut.send(.customRunnerEditor(.customRunnerAdded(bundle)))
        #expect(sut.customRunnerBundleList == [bundle])
        #expect(sut.customRunnerEditor == nil)
    }

    @MainActor @Test
    func send_guidanceButtonTapped_shows_guidance_popover() async {
        let sut = CustomRunnerSettings(.testDependencies())
        await sut.send(.guidanceButtonTapped)
        #expect(sut.showingGuidancePopover)
    }
}
