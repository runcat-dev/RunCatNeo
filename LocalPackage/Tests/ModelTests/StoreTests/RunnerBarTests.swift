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
            }
        )
    }

    @MainActor @Test
    func send_viewAppeared_applies_latest_runner_bundle_to_event_bridge() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(
                runner: .default,
                frames: [.preset("cat-frame-0"), .preset("cat-frame-1")]
            ))
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { callStack.withLock(\.self).count >= 4 }
        #expect(sut.isReady)
        #expect(sut.size == CGSize(width: 10, height: 18))
        #expect(sut.isTemplate)
        #expect(callStack.withLock(\.self) == [
            "getBundleImage: cat-frame-0",
            "getBundleImage: cat-frame-1",
            "setSize: 10.0x18.0",
            "setFrames: 2, true",
        ])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_applies_runner_speed_to_event_bridge() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock { $0.runnerSpeeds.send(12.5) }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { !callStack.withLock(\.self).isEmpty }
        #expect(callStack.withLock(\.self) == ["setSpeed: 12.5"])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_ignores_thumbnail_bundle() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: .default, frame: .preset("cat-frame-0")))
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(callStack.withLock(\.self).isEmpty)
        #expect(sut.icon == nil)
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_with_broken_frames_clears_icon() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(runner: .default, frames: [.broken]))
        }
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await waitUntil { callStack.withLock(\.self).count >= 2 }
        #expect(sut.icon == nil)
        #expect(sut.size == .zero)
        #expect(callStack.withLock(\.self) == [
            "setSize: 0.0x0.0",
            "setFrames: 0, true",
        ])
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_renders_frames_in_accent_color_when_system_colors_change() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(
                runner: .default,
                frames: [.preset("cat-frame-0"), .preset("cat-frame-1")]
            ))
        }
        let usesAccentColor = AllocatedUnfairLock(initialState: false)
        let notificationCenter = NotificationCenter()
        let observedNotificationName = AllocatedUnfairLock<Notification.Name?>(initialState: nil)
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(
            appStateClient: .testDependency(appState),
            notificationCenterClient: testDependency(of: NotificationCenterClient.self) {
                $0.publisher = { name in
                    observedNotificationName.withLock { $0 = name }
                    return notificationCenter.publisher(for: name).eraseToAnyPublisher()
                }
            },
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.bool = { key in
                    key == "USES_ACCENT_COLOR" ? usesAccentColor.withLock(\.self) : false
                }
            }
        ))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        StatusBarAppearanceBridge.shared.send(try #require(NSAppearance(named: .aqua)))
        StatusBarAppearanceBridge.shared.send(try #require(NSAppearance(named: .darkAqua)))
        await waitUntil { callStack.withLock(\.last) == "setFrames: 2, true" }
        usesAccentColor.withLock { $0 = true }
        notificationCenter.post(name: NSColor.systemColorsDidChangeNotification, object: nil)
        await waitUntil { callStack.withLock(\.last) == "setFrames: 2, false" }
        #expect(observedNotificationName.withLock(\.self) == NSColor.systemColorsDidChangeNotification)
        #expect(callStack.withLock(\.last) == "setFrames: 2, false")
        #expect(!sut.isTemplate)
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewAppeared_tints_frames_and_icon_with_accent_color() async throws {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        appState.withLock {
            $0.runnerBundles.send(RunnerBundle(
                runner: .default,
                frames: [.preset("cat-frame-0"), .preset("cat-frame-1")]
            ))
        }
        let framePixels = AllocatedUnfairLock<[SampledPixel]>(initialState: [])
        let eventBridge = RunnerBar.Action.EventBridge(
            getBundleImage: { _ in makeFilledImage(color: .black) },
            setSize: { _ in },
            setFrames: { images, isTemplate in
                guard !isTemplate else { return }
                let pixels = images.map { $0.sampleColor(x: 5, y: 9) }
                framePixels.withLock { $0 = pixels }
            },
            setColor: { _, _ in },
            setSpeed: { _ in }
        )
        let sut = RunnerBar(.testDependencies(
            appStateClient: .testDependency(appState),
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.bool = { $0 == "USES_ACCENT_COLOR" }
            }
        ))
        await sut.send(.viewAppeared("RunnerBarTests", eventBridge))
        let darkAppearance = try #require(NSAppearance(named: .darkAqua))
        StatusBarAppearanceBridge.shared.send(try #require(NSAppearance(named: .aqua)))
        StatusBarAppearanceBridge.shared.send(darkAppearance)
        let accentColor = NSColor(cgColor: NSColor.controlAccentColor.cgColor(in: darkAppearance))!
        let expectedPixel = makeFilledImage(color: accentColor).sampleColor(x: 5, y: 9)
        await waitUntil {
            framePixels.withLock(\.self).count == 2
                && framePixels.withLock(\.self).allSatisfy { $0.isClose(to: expectedPixel) }
        }
        let icon = try #require(sut.icon)
        #expect(framePixels.withLock(\.self).count == 2)
        #expect(framePixels.withLock(\.self).allSatisfy { $0.isClose(to: expectedPixel) })
        #expect(icon.sampleColor(x: 5, y: 9).isClose(to: expectedPixel))
        await sut.send(.viewDisappeared)
    }

    @MainActor @Test
    func send_viewDisappeared_stops_observing_streams() async {
        let appState = AllocatedUnfairLock<AppState>(initialState: .init())
        let callStack = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = RunnerBar(.testDependencies(appStateClient: .testDependency(appState)))
        await sut.send(.viewAppeared("RunnerBarTests", makeEventBridge(recording: callStack)))
        await sut.send(.viewDisappeared)
        appState.withLock { $0.runnerSpeeds.send(5.0) }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(callStack.withLock(\.self).isEmpty)
    }
}

@MainActor
private func makeFilledImage(color: NSColor) -> NSImage {
    NSImage(size: CGSize(width: 10, height: 18), flipped: false) { rect in
        color.setFill()
        rect.fill()
        return true
    }
}

private extension SampledPixel {
    func isClose(to other: SampledPixel) -> Bool {
        abs(redComponent - other.redComponent) < 0.02
            && abs(greenComponent - other.greenComponent) < 0.02
            && abs(blueComponent - other.blueComponent) < 0.02
            && abs(alphaComponent - other.alphaComponent) < 0.02
    }
}
