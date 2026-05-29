import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct DashboardTests {
    @MainActor @Test
    func send_settingsButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsAppClient: testDependency(of: NSAppClient.self) {
                $0.activate = { value in
                    callStack.withLock { $0.append("activate: \(value)") }
                }
            }
        ))
        await sut.send(.settingsButtonTapped)
        #expect(callStack.withLock(\.self) == ["activate: true"])
    }

    @MainActor @Test
    func send_activityMonitorButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsWorkspaceClient: testDependency(of: NSWorkspaceClient.self) {
                $0.urlForApplication = { _ in
                    URL(filePath: "/System/Applications/Utilities/Activity Monitor.app/")
                }
                $0.openApplication = { value, _ in
                    callStack.withLock { $0.append("openApplication: \(value.absoluteString)") }
                }
            }
        ))
        await sut.send(.activityMonitorButtonTapped)
        #expect(callStack.withLock(\.self) == [
            "openApplication: file:///System/Applications/Utilities/Activity%20Monitor.app/",
        ])
    }

    @MainActor @Test
    func send_aboutButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsAppClient: testDependency(of: NSAppClient.self) {
                $0.activate = { value in
                    callStack.withLock { $0.append("activate: \(value)") }
                }
                $0.orderFrontStandardAboutPanel = { _ in
                    callStack.withLock { $0.append("orderFrontStandardAboutPanel") }
                }
            }
        ))
        await sut.send(.aboutButtonTapped(.init()))
        #expect(callStack.withLock(\.self) == [
            "activate: true",
            "orderFrontStandardAboutPanel",
        ])
    }

    @MainActor @Test
    func send_reportIssueButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsWorkspaceClient: testDependency(of: NSWorkspaceClient.self) {
                $0.open = { value in
                    callStack.withLock { $0.append("open: \(value.absoluteString)") }
                    return true
                }
            }
        ))
        await sut.send(.reportIssueButtonTapped)
        #expect(callStack.withLock(\.self) == [
            "open: https://github.com/runcat-dev/RunCatNeo/issues",
        ])
    }


    @MainActor @Test
    func send_quitButtonTapped() async {
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = Dashboard(.testDependencies(
            nsAppClient: testDependency(of: NSAppClient.self) {
                $0.terminate = { _ in
                    callStack.withLock { $0.append("terminate") }
                }
            }
        ))
        await sut.send(.quitButtonTapped)
        #expect(callStack.withLock(\.self) == ["terminate"])
    }
}
