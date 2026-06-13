import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct CustomRunnerSettingsTests {
    private var customRunner: Runner {
        Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0]))
    }

    private func errorRecorder() -> (
        lock: AllocatedUnfairLock<RCNError?>,
        action: (CustomRunnerSettings.Action) async -> Void
    ) {
        let lock = AllocatedUnfairLock<RCNError?>(initialState: nil)
        let action: (CustomRunnerSettings.Action) async -> Void = { action in
            if case let .onError(error) = action {
                lock.withLock { $0 = error }
            }
        }
        return (lock, action)
    }

    @MainActor @Test
    func send_task_filters_custom_runners_and_starts_frame_preview() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let customBundle = RunnerBundle(runner: customRunner, frame: .custom(Data()))
        appState.withLock {
            $0.runnerBundleLists.send([
                RunnerBundle(runner: .default, frame: .preset("cat-frame-0")),
                customBundle,
            ])
        }
        let frameImages = [FrameImage.dummy(), FrameImage.dummy()]
        let sut = CustomRunnerSettings(
            .testDependencies(appStateClient: .testDependency(appState)),
            frameImages: frameImages
        )
        await sut.send(.task)
        let previewedSecondFrameImage = await waitUntil { sut.previewingFrameImage == frameImages[1] }
        #expect(sut.customRunnerBundleList == [customBundle])
        #expect(previewedSecondFrameImage)
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_deleteButtonTapped_forwards_error_when_runner_is_in_use() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let bundle = RunnerBundle(runner: customRunner, frame: .custom(Data()))
        appState.withLock { $0.runnerBundles.send(bundle) }
        let recorder = errorRecorder()
        let sut = CustomRunnerSettings(
            .testDependencies(appStateClient: .testDependency(appState)),
            customRunnerBundleList: [bundle],
            action: recorder.action
        )
        await sut.send(.deleteButtonTapped(customRunner))
        #expect(recorder.lock.withLock(\.self) == .customRunner(.runnerInUse))
        #expect(sut.customRunnerBundleList == [bundle])
    }

    @MainActor @Test
    func send_deleteButtonTapped_removes_selected_runner() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: .default, frame: .preset("cat-frame-0")))
        }
        let recorder = errorRecorder()
        let sut = CustomRunnerSettings(
            .testDependencies(appStateClient: .testDependency(appState)),
            customRunnerBundleList: [RunnerBundle(runner: customRunner, frame: .custom(Data()))],
            action: recorder.action
        )
        await sut.send(.deleteButtonTapped(customRunner))
        #expect(sut.customRunnerBundleList.isEmpty)
        #expect(recorder.lock.withLock(\.self) == nil)
    }

    @MainActor @Test
    func send_onTapFrameImageCell_selects_frame_and_background_clears_it() async {
        let frameImage = FrameImage.dummy()
        let sut = CustomRunnerSettings(.testDependencies())
        await sut.send(.onTapFrameImageCell(frameImage))
        #expect(sut.selectingFrameImage == frameImage)
        await sut.send(.onTapCollectionBackground)
        #expect(sut.selectingFrameImage == nil)
    }

    @MainActor @Test
    func send_onDropCollection_appends_valid_png_and_ignores_other_extensions() async {
        let recorder = errorRecorder()
        let sut = CustomRunnerSettings(.testDependencies(), action: recorder.action)
        await sut.send(.onDropCollection([
            URL.fixture(name: "solid_red_30x36"),
            URL(filePath: "/tmp/ignored.json"),
        ]))
        #expect(sut.frameImages.count == 1)
        #expect(recorder.lock.withLock(\.self) == nil)
    }

    @MainActor @Test
    func send_onDropCollection_forwards_error_when_image_size_is_invalid() async {
        let recorder = errorRecorder()
        let sut = CustomRunnerSettings(.testDependencies(), action: recorder.action)
        await sut.send(.onDropCollection([URL.fixture(name: "solid_red_10x18")]))
        #expect(recorder.lock.withLock(\.self) == .customRunner(.invalidFrameImage))
        #expect(sut.frameImages.isEmpty)
    }

    @MainActor @Test
    func send_addFrameButtonTapped_shows_file_importer() async {
        let sut = CustomRunnerSettings(.testDependencies())
        await sut.send(.addFrameButtonTapped)
        #expect(sut.showingFileImporter == true)
    }

    @MainActor @Test
    func send_deleteFrameButtonTapped_removes_selecting_frame_and_selects_next() async {
        let firstFrameImage = FrameImage.dummy()
        let secondFrameImage = FrameImage.dummy()
        let sut = CustomRunnerSettings(
            .testDependencies(),
            frameImages: [firstFrameImage, secondFrameImage],
            selectingFrameImage: firstFrameImage
        )
        await sut.send(.deleteFrameButtonTapped)
        #expect(sut.frameImages == [secondFrameImage])
        #expect(sut.selectingFrameImage == secondFrameImage)
    }

    @MainActor @Test
    func send_addButtonTapped_saves_runner_and_appends_to_list() async {
        let writtenFileNames = AllocatedUnfairLock<[String]>(initialState: [])
        let recorder = errorRecorder()
        let sut = CustomRunnerSettings(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.convert = { _, _ in Data("png".utf8) }
                    $0.write = { _, url in
                        writtenFileNames.withLock { $0.append(url.lastPathComponent) }
                    }
                }
            ),
            runnerName: "New Runner",
            frameImages: [FrameImage.dummy()],
            action: recorder.action
        )
        await sut.send(.addButtonTapped)
        #expect(recorder.lock.withLock(\.self) == nil)
        #expect(sut.customRunnerBundleList.compactMap { runnerBundle in
            if case let .custom(name) = runnerBundle.runner.source { name } else { nil }
        } == ["New Runner"])
        #expect(writtenFileNames.withLock(\.self) == ["frame-0.png", "CUSTOM_RUNNERS.json"])
    }

    @MainActor @Test
    func send_addButtonTapped_forwards_error_when_name_already_exists() async {
        let json = """
            [
              {
                "id": "custom-runner",
                "name": "New Runner",
                "isTemplate": false,
                "frameOrder": [0]
              }
            ]
            """
        let recorder = errorRecorder()
        let sut = CustomRunnerSettings(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.read = { _ in Data(json.utf8) }
                },
                fileManagerClient: testDependency(of: FileManagerClient.self) {
                    $0.fileExists = { _ in true }
                }
            ),
            runnerName: "New Runner",
            frameImages: [FrameImage.dummy()],
            action: recorder.action
        )
        await sut.send(.addButtonTapped)
        #expect(recorder.lock.withLock(\.self) == .customRunner(.nameAlreadyExists))
        #expect(sut.customRunnerBundleList.isEmpty)
    }

    @MainActor @Test
    func send_addButtonTapped_forwards_error_when_saving_fails() async {
        let recorder = errorRecorder()
        let sut = CustomRunnerSettings(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.write = { _, _ in throw URLError(.unknown) }
                }
            ),
            runnerName: "New Runner",
            frameImages: [FrameImage.dummy()],
            action: recorder.action
        )
        await sut.send(.addButtonTapped)
        #expect(recorder.lock.withLock(\.self) == .customRunner(.savingFailed))
        #expect(sut.customRunnerBundleList.isEmpty)
    }

    @MainActor @Test
    func send_addButtonTapped_without_frames_is_noop() async {
        let recorder = errorRecorder()
        let sut = CustomRunnerSettings(
            .testDependencies(),
            runnerName: "New Runner",
            action: recorder.action
        )
        await sut.send(.addButtonTapped)
        #expect(recorder.lock.withLock(\.self) == nil)
        #expect(sut.customRunnerBundleList.isEmpty)
    }

    @MainActor @Test
    func send_addCustomRunnerButtonTapped_shows_editor_sheet() async {
        let sut = CustomRunnerSettings(.testDependencies())
        await sut.send(.addCustomRunnerButtonTapped)
        #expect(sut.showingCustomRunnerEditorSheet == true)
    }

    @MainActor @Test
    func send_cancelButtonTapped_hides_editor_sheet() async {
        let sut = CustomRunnerSettings(
            .testDependencies(),
            showingCustomRunnerEditorSheet: true
        )
        await sut.send(.cancelButtonTapped)
        #expect(sut.showingCustomRunnerEditorSheet == false)
    }

    @MainActor @Test
    func send_onDissmissSheet_resets_editor_inputs() async {
        let frameImage = FrameImage.dummy()
        let sut = CustomRunnerSettings(
            .testDependencies(),
            runnerName: "New Runner",
            isTemplate: false,
            frameImages: [frameImage],
            selectingFrameImage: frameImage,
            previewingFrameImage: frameImage,
            previewSpeed: 2
        )
        await sut.send(.onDissmissSheet)
        #expect(sut.runnerName.isEmpty)
        #expect(sut.isTemplate == true)
        #expect(sut.frameImages.isEmpty)
        #expect(sut.selectingFrameImage == nil)
        #expect(sut.previewingFrameImage == nil)
        #expect(sut.previewSpeed == 1)
    }

    @MainActor @Test
    func send_selectRenderingMode_updates_isTemplate() async {
        let sut = CustomRunnerSettings(.testDependencies())
        await sut.send(.selectRenderingMode(.color))
        #expect(sut.isTemplate == false)
        await sut.send(.selectRenderingMode(.monochrome))
        #expect(sut.isTemplate == true)
    }

    @MainActor @Test
    func send_onDragFrameImageCell_selects_frame() async {
        let frameImage = FrameImage.dummy()
        let sut = CustomRunnerSettings(.testDependencies())
        await sut.send(.onDragFrameImageCell(frameImage))
        #expect(sut.selectingFrameImage == frameImage)
    }

    @MainActor @Test
    func send_onCompletionFileImporter_appends_accessible_frame_image() async {
        let recorder = errorRecorder()
        let urlClient = testDependency(of: URLClient.self) {
            $0.startAccessingSecurityScopedResource = { _ in true }
            $0.stopAccessingSecurityScopedResource = { _ in }
        }
        let sut = CustomRunnerSettings(
            .testDependencies(urlClient: urlClient),
            action: recorder.action
        )
        await sut.send(.onCompletionFileImporter(.success([URL.fixture(name: "solid_red_30x36")])))
        #expect(sut.frameImages.count == 1)
        #expect(recorder.lock.withLock(\.self) == nil)
    }

    @MainActor @Test
    func send_onCompletionFileImporter_skips_inaccessible_frame_image() async {
        let recorder = errorRecorder()
        let urlClient = testDependency(of: URLClient.self) {
            $0.startAccessingSecurityScopedResource = { _ in false }
        }
        let sut = CustomRunnerSettings(
            .testDependencies(urlClient: urlClient),
            action: recorder.action
        )
        await sut.send(.onCompletionFileImporter(.success([URL.fixture(name: "solid_red_30x36")])))
        #expect(sut.frameImages.isEmpty)
        #expect(recorder.lock.withLock(\.self) == nil)
    }

    @MainActor @Test
    func send_onCompletionFileImporter_failure_is_noop() async {
        let recorder = errorRecorder()
        let sut = CustomRunnerSettings(.testDependencies(), action: recorder.action)
        await sut.send(.onCompletionFileImporter(.failure(URLError(.cancelled))))
        #expect(sut.frameImages.isEmpty)
        #expect(recorder.lock.withLock(\.self) == nil)
    }
}
