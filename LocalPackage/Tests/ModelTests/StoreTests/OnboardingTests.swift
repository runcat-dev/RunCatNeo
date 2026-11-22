import AllocatedUnfairLock
import Testing

@testable import DataSource
@testable import Model

struct OnboardingTests {
    @MainActor @Test
    func send_viewAppeared_persists_shown_flag_and_activates_app() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Onboarding(.testDependencies(
            nsAppClient: testDependency(of: NSAppClient.self) {
                $0.activate = { value in
                    callStack.withLock { $0.append("activate: \(value)") }
                }
            },
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.set = { value, key in
                    let entry = "set: \(key) = \(value ?? "nil")"
                    callStack.withLock { $0.append(entry) }
                }
            }
        ))
        await sut.send(.viewAppeared("OnboardingTests"))
        #expect(callStack.withLock(\.self) == ["set: HAS_SHOWN_ONBOARDING = true", "activate: true"])
    }

    @MainActor @Test
    func send_okButtonTapped_dismisses_onboarding_window() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Onboarding(.testDependencies())
        await sut.send(.okButtonTapped(.init { id in
            callStack.withLock { $0.append("dismissWindow: \(id)") }
        }))
        #expect(callStack.withLock(\.self) == ["dismissWindow: ONBOARDING"])
    }
}
