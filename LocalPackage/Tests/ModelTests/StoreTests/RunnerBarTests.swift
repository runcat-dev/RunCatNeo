import AllocatedUnfairLock
import AppKit
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct RunnerBarTests {
    private func makeEventBridge(recording callStack: AllocatedUnfairLock<[String]>) -> RunnerBar.Action.EventBridge {
        RunnerBar.Action.EventBridge(
            getBundleImage: { name in
                callStack.withLock { $0.append("getBundleImage: \(name)") }
                return NSImage(size: CGSize(width: 10, height: 18))
            },
            setSize: { size in
                callStack.withLock { $0.append("setSize: \(size.width)x\(size.height)") }
            },
            setFrames: { images, isTemplate in
                callStack.withLock { $0.append("setFrames: \(images.count), \(isTemplate)") }
            },
            setColor: { _, _ in },
            setSpeed: { speed in
                callStack.withLock { $0.append("setSpeed: \(speed)") }
            },
            setPaused: { isPaused in
                callStack.withLock { $0.append("setPaused: \(isPaused)") }
            }
        )
    }

    @MainActor @Test
    func send_task_applies_latest_runner_bundle_to_event_bridge() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(
                runner: .default,
                frames: [.preset("cat-frame-0"), .preset("cat-frame-1")]
            ))
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { callStack.withLock(\.self).count >= 4 }
        #expect(sut.isReady == true)
        #expect(sut.size == CGSize(width: 10, height: 18))
        #expect(sut.isTemplate == true)
        #expect(callStack.withLock(\.self) == [
            "getBundleImage: cat-frame-0",
            "getBundleImage: cat-frame-1",
            "setSize: 10.0x18.0",
            "setFrames: 2, true",
        ])
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_task_applies_runner_speed_to_event_bridge() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock { $0.runnerSpeeds.send(12.5) }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { !callStack.withLock(\.self).isEmpty }
        #expect(callStack.withLock(\.self) == ["setSpeed: 12.5"])
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_task_applies_runner_paused_to_event_bridge() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock { $0.runnerPauses.send(true) }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { !callStack.withLock(\.self).isEmpty }
        #expect(callStack.withLock(\.self) == ["setPaused: true"])
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_task_ignores_thumbnail_bundle() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: .default, frame: .preset("cat-frame-0")))
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("RunnerBarTests", makeEventBridge(recording: callStack)))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(callStack.withLock(\.self).isEmpty)
        #expect(sut.icon == nil)
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_task_with_broken_frames_clears_icon() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: .default, frames: [.broken]))
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { callStack.withLock(\.self).count >= 2 }
        #expect(sut.icon == nil)
        #expect(sut.size == .zero)
        #expect(callStack.withLock(\.self) == [
            "setSize: 0.0x0.0",
            "setFrames: 0, true",
        ])
        await sut.send(.onDisappear)
    }

    @MainActor @Test
    func send_onDisappear_stops_observing_streams() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.task("RunnerBarTests", makeEventBridge(recording: callStack)))
        await sut.send(.onDisappear)
        appState.withLock { $0.runnerSpeeds.send(5.0) }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(callStack.withLock(\.self).isEmpty)
    }
}
