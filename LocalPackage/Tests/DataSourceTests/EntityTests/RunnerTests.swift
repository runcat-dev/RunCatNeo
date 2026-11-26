import Foundation
import Testing

@testable import DataSource

struct RunnerTests {
    private var runner: Runner {
        Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0]))
    }

    @Test
    func equality_holds_when_all_properties_are_same() {
        #expect(runner == Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0])))
    }

    @Test(arguments: [
        Runner(id: "custom-runner", name: "Renamed Runner", isTemplate: false, frameOrder: .custom([0])),
        Runner(id: "custom-runner", name: "Custom Runner", isTemplate: true, frameOrder: .custom([0])),
        Runner(id: "custom-runner", name: "Custom Runner", isTemplate: false, frameOrder: .custom([0, 1])),
    ])
    func equality_fails_when_runner_with_same_id_is_edited(editedRunner: Runner) {
        #expect(runner != editedRunner)
    }
}
