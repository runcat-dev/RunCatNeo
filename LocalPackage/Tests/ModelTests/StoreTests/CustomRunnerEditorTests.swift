import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct CustomRunnerEditorTests {
    private func errorRecorder() -> (
        lock: AllocatedUnfairLock<RCNError?>,
        action: (CustomRunnerEditor.Action) async -> Void
    ) {
        let lock = AllocatedUnfairLock<RCNError?>(initialState: nil)
        let action: (CustomRunnerEditor.Action) async -> Void = { action in
            if case let .errorOccurred(error) = action {
                lock.withLock { $0 = error }
            }
        }
        return (lock, action)
    }

    @MainActor @Test
    func send_viewAppeared_starts_frame_preview() async {
        let frameImages = [FrameImage.dummy(), FrameImage.dummy()]
        let sut = CustomRunnerEditor(
            .testDependencies(),
            id: .init(),
            frameImages: frameImages
        )
        await sut.send(.viewAppeared)
        let previewedSecondFrameImage = await waitUntil { sut.previewingFrameImage == frameImages[1] }
        #expect(previewedSecondFrameImage)
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_renderingModePickerSelected_updates_isTemplate() async {
        let sut = CustomRunnerEditor(.testDependencies(), id: .init())
        await sut.send(.renderingModePickerSelected(.color))
        #expect(!sut.isTemplate)
        await sut.send(.renderingModePickerSelected(.monochrome))
        #expect(sut.isTemplate)
    }

    @MainActor @Test
    func send_frameImageCellTapped_selects_frame_and_background_clears_it() async {
        let frameImage = FrameImage.dummy()
        let sut = CustomRunnerEditor(.testDependencies(), id: .init())
        await sut.send(.frameImageCellTapped(frameImage))
        #expect(sut.selectingFrameImage == frameImage)
        await sut.send(.collectionBackgroundTapped)
        #expect(sut.selectingFrameImage == nil)
    }

    @MainActor @Test
    func send_filesDropped_appends_valid_png_and_ignores_other_extensions() async {
        let recorder = errorRecorder()
        let sut = CustomRunnerEditor(.testDependencies(), id: .init(), action: recorder.action)
        await sut.send(.filesDropped([
            URL.fixture(name: "solid_red_30x36"),
            URL(filePath: "/tmp/ignored.json"),
        ]))
        #expect(sut.frameImages.count == 1)
        #expect(recorder.lock.withLock(\.self) == nil)
    }

    @MainActor @Test
    func send_filesDropped_forwards_error_when_image_size_is_invalid() async {
        let recorder = errorRecorder()
        let sut = CustomRunnerEditor(.testDependencies(), id: .init(), action: recorder.action)
        await sut.send(.filesDropped([URL.fixture(name: "solid_red_10x18")]))
        #expect(recorder.lock.withLock(\.self) == .customRunner(.invalidFrameImage))
        #expect(sut.frameImages.isEmpty)
    }

    @MainActor @Test
    func send_addFrameButtonTapped_shows_file_importer() async {
        let sut = CustomRunnerEditor(.testDependencies(), id: .init())
        await sut.send(.addFrameButtonTapped)
        #expect(sut.showingFileImporter)
    }

    @MainActor @Test
    func send_deleteFrameButtonTapped_removes_selecting_frame_and_selects_next() async {
        let firstFrameImage = FrameImage.dummy()
        let secondFrameImage = FrameImage.dummy()
        let sut = CustomRunnerEditor(
            .testDependencies(),
            id: .init(),
            frameImages: [firstFrameImage, secondFrameImage],
            selectingFrameImage: firstFrameImage
        )
        await sut.send(.deleteFrameButtonTapped)
        #expect(sut.frameImages == [secondFrameImage])
        #expect(sut.selectingFrameImage == secondFrameImage)
    }

    @MainActor @Test
    func send_fileImporterResponse_appends_accessible_frame_image() async {
        let recorder = errorRecorder()
        let urlClient = testDependency(of: URLClient.self) {
            $0.startAccessingSecurityScopedResource = { _ in true }
            $0.stopAccessingSecurityScopedResource = { _ in }
        }
        let sut = CustomRunnerEditor(
            .testDependencies(urlClient: urlClient),
            id: .init(),
            action: recorder.action
        )
        await sut.send(.fileImporterResponse(.success([URL.fixture(name: "solid_red_30x36")])))
        #expect(sut.frameImages.count == 1)
        #expect(recorder.lock.withLock(\.self) == nil)
    }

    @MainActor @Test
    func send_fileImporterResponse_skips_inaccessible_frame_image() async {
        let recorder = errorRecorder()
        let urlClient = testDependency(of: URLClient.self) {
            $0.startAccessingSecurityScopedResource = { _ in false }
        }
        let sut = CustomRunnerEditor(
            .testDependencies(urlClient: urlClient),
            id: .init(),
            action: recorder.action
        )
        await sut.send(.fileImporterResponse(.success([URL.fixture(name: "solid_red_30x36")])))
        #expect(sut.frameImages.isEmpty)
        #expect(recorder.lock.withLock(\.self) == nil)
    }

    @MainActor @Test
    func send_fileImporterResponse_failure_is_noop() async {
        let recorder = errorRecorder()
        let sut = CustomRunnerEditor(.testDependencies(), id: .init(), action: recorder.action)
        await sut.send(.fileImporterResponse(.failure(URLError(.cancelled))))
        #expect(sut.frameImages.isEmpty)
        #expect(recorder.lock.withLock(\.self) == nil)
    }

    @MainActor @Test
    func send_addButtonTapped_saves_runner_and_forwards_bundle() async {
        let writtenFileNames = AllocatedUnfairLock<[String]>(initialState: [])
        let addedRunnerBundle = AllocatedUnfairLock<RunnerBundle?>(initialState: nil)
        let sut = CustomRunnerEditor(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.convert = { _, _ in Data("png".utf8) }
                    $0.write = { _, url in
                        writtenFileNames.withLock { $0.append(url.lastPathComponent) }
                    }
                }
            ),
            id: .init(),
            runnerName: "New Runner",
            frameImages: [FrameImage.dummy()],
            action: { action in
                if case let .customRunnerAdded(runnerBundle) = action {
                    addedRunnerBundle.withLock { $0 = runnerBundle }
                }
            }
        )
        await sut.send(.addButtonTapped)
        #expect(addedRunnerBundle.withLock(\.self).flatMap { runnerBundle in
            if case let .custom(name) = runnerBundle.runner.source { name } else { nil }
        } == "New Runner")
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
        let sut = CustomRunnerEditor(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.read = { _ in Data(json.utf8) }
                },
                fileManagerClient: testDependency(of: FileManagerClient.self) {
                    $0.fileExists = { _ in true }
                }
            ),
            id: .init(),
            runnerName: "New Runner",
            frameImages: [FrameImage.dummy()],
            action: recorder.action
        )
        await sut.send(.addButtonTapped)
        #expect(recorder.lock.withLock(\.self) == .customRunner(.nameAlreadyExists))
    }

    @MainActor @Test
    func send_addButtonTapped_forwards_error_when_saving_fails() async {
        let recorder = errorRecorder()
        let sut = CustomRunnerEditor(
            .testDependencies(
                dataClient: testDependency(of: DataClient.self) {
                    $0.write = { _, _ in throw URLError(.unknown) }
                }
            ),
            id: .init(),
            runnerName: "New Runner",
            frameImages: [FrameImage.dummy()],
            action: recorder.action
        )
        await sut.send(.addButtonTapped)
        #expect(recorder.lock.withLock(\.self) == .customRunner(.savingFailed))
    }

    @MainActor @Test
    func send_addButtonTapped_without_frames_is_noop() async {
        let recorder = errorRecorder()
        let sut = CustomRunnerEditor(
            .testDependencies(),
            id: .init(),
            runnerName: "New Runner",
            action: recorder.action
        )
        await sut.send(.addButtonTapped)
        #expect(recorder.lock.withLock(\.self) == nil)
    }

    @MainActor @Test
    func send_errorOccurred_shows_alert() async {
        let sut = CustomRunnerEditor(.testDependencies(), id: .init())
        await sut.send(.errorOccurred(.customRunner(.invalidFrameImage)))
        #expect(sut.showingAlert)
        #expect(sut.error == .customRunner(.invalidFrameImage))
    }
}
