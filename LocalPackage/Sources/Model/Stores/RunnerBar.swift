/*
 RunnerBar.swift
 Model

 Created by Takuto Nakamura on 2026/05/08.
 Copyright 2026 Kyome22 (Takuto Nakamura)

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import AppKit
import DataSource
import Observation

@MainActor @Observable
public final class RunnerBar: Composable {
    private let appStateClient: AppStateClient
    private let notificationCenterClient: NotificationCenterClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService

    @ObservationIgnored private var eventBridge: Action.EventBridge?
    @ObservationIgnored private var appearance: NSAppearance?
    @ObservationIgnored private var task: Task<Void, Never>?

    public var icon: NSImage?
    public var size: CGSize
    public var isTemplate: Bool
    public let action: (Action) async -> Void

    public var isReady: Bool {
        eventBridge != nil
    }

    public init(
        _ appDependencies: AppDependencies,
        icon: NSImage? = nil,
        size: CGSize = .zero,
        isTemplate: Bool = false,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.notificationCenterClient = appDependencies.notificationCenterClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.icon = icon
        self.size = size
        self.isTemplate = isTemplate
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .viewAppeared(screenName, eventBridge):
            logService.notice(.screenView(name: screenName))
            self.eventBridge = eventBridge
            task?.cancel()
            task = Task.immediate { [weak self, appStateClient, notificationCenterClient] in
                await withTaskGroup { group in
                    group.addImmediateTask {
                        for await value in StatusBarAppearanceBridge.shared.stream {
                            self?.update(appearance: value)
                        }
                    }
                    group.addImmediateTask {
                        let publisher = notificationCenterClient.publisher(NSColor.systemColorsDidChangeNotification)
                        for await _ in publisher.bufferedValues() {
                            self?.updateColors()
                        }
                    }
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.runnerBundles.stream)
                        for await value in stream {
                            self?.update(runnerBundle: value)
                        }
                    }
                    group.addImmediateTask {
                        let stream = appStateClient.withLock(\.runnerSpeeds.stream)
                        for await value in stream {
                            self?.update(runnerSpeed: value)
                        }
                    }
                }
            }

        case .viewDisappeared:
            task?.cancel()
            task = nil
        }
    }

    private func update(appearance: NSAppearance) {
        self.appearance = appearance
        updateColors()
    }

    private func updateColors() {
        guard let runnerBundle = appStateClient.withLock(\.runnerBundles.latestValue),
              frameTintColor(for: runnerBundle.runner) != nil else {
            updateTemplateColor()
            return
        }
        update(runnerBundle: runnerBundle)
    }

    private func updateTemplateColor() {
        guard let appearance else { return }
        eventBridge?.setColor(NSColor.textColor.cgColor(in: appearance), isTemplate)
    }

    private func frameTintColor(for runner: Runner) -> CGColor? {
        guard runner.isTemplate, userDefaultsRepository.usesAccentColor, let appearance else {
            return nil
        }
        return NSColor.controlAccentColor.cgColor(in: appearance)
    }

    private func update(runnerBundle: RunnerBundle) {
        guard case let .keyFrameAnimation(frames) = runnerBundle.displayFormat else {
            return
        }
        let images = frames.compactMap { frame in
            switch frame {
            case let .preset(resourceName):
                eventBridge?.getBundleImage(resourceName)
            case let .custom(data):
                NSImage(data: data)
            case .broken:
                nil
            }
        }
        let isFlippedHorizontally = userDefaultsRepository.isFlippedHorizontally
        let frameTintColor = frameTintColor(for: runnerBundle.runner)
        icon = images.first?.plane
        icon?.flip(enabled: isFlippedHorizontally)
        icon?.normalize()
        icon?.tint(with: frameTintColor)
        size = icon?.size ?? .zero
        eventBridge?.setSize(size)
        isTemplate = runnerBundle.runner.isTemplate && frameTintColor == nil
        updateTemplateColor()
        let imageFrames = images.map { image in
            image.flip(enabled: isFlippedHorizontally)
            image.normalize()
            image.tint(with: frameTintColor)
            image.isTemplate = isTemplate
            return image
        }
        eventBridge?.setFrames(imageFrames, isTemplate)
    }

    private func update(runnerSpeed: Float) {
        eventBridge?.setSpeed(runnerSpeed)
    }

    public enum Action: Sendable {
        case viewAppeared(String, EventBridge)
        case viewDisappeared

        public struct EventBridge: Sendable {
            public let getBundleImage: @MainActor @Sendable (String) -> NSImage
            public var setSize: @MainActor @Sendable (CGSize) -> Void
            public var setFrames: @MainActor @Sendable ([NSImage], Bool) -> Void
            public var setColor: @MainActor @Sendable (CGColor, Bool) -> Void
            public var setSpeed: @MainActor @Sendable (Float) -> Void

            public init(
                getBundleImage: @escaping @MainActor @Sendable (String) -> NSImage,
                setSize: @escaping @MainActor @Sendable (CGSize) -> Void,
                setFrames: @escaping @MainActor @Sendable ([NSImage], Bool) -> Void,
                setColor: @escaping @MainActor @Sendable (CGColor, Bool) -> Void,
                setSpeed: @escaping @MainActor @Sendable (Float) -> Void
            ) {
                self.getBundleImage = getBundleImage
                self.setSize = setSize
                self.setFrames = setFrames
                self.setColor = setColor
                self.setSpeed = setSpeed
            }
        }
    }
}
