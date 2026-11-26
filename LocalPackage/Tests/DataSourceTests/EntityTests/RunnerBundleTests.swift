import Foundation
import Testing

@testable import DataSource

struct RunnerBundleTests {
    private var runner: Runner {
        Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0]))
    }

    @Test
    func equality_holds_when_runner_and_display_format_are_same() {
        #expect(RunnerBundle(runner: runner, frame: .custom(Data())) == RunnerBundle(runner: runner, frame: .custom(Data())))
    }

    @Test(arguments: [
        Runner(id: "custom-runner", name: "Renamed Runner", isTemplate: false, frameOrder: .custom([0])),
        Runner(id: "custom-runner", name: "Custom Runner", isTemplate: true, frameOrder: .custom([0])),
        Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0, 1])),
    ])
    func equality_fails_when_runner_with_same_id_is_edited(editedRunner: Runner) {
        #expect(RunnerBundle(runner: runner, frame: .custom(Data())) != RunnerBundle(runner: editedRunner, frame: .custom(Data())))
    }

    @Test
    func equality_fails_when_display_format_is_different() {
        #expect(RunnerBundle(runner: runner, frame: .custom(Data())) != RunnerBundle(runner: runner, frame: .custom(Data("png".utf8))))
    }
}
