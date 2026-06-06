/*
 RunnerBar.swift
 Model

 Created by Takuto Nakamura on 2026/05/08.
 Copyright 2026 Koyme22 (Takuto Nakamura)

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
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService

    @ObservationIgnored private var eventBridge: Action.EventBridge?
    @ObservationIgnored private var tintColor = CGColor.black
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
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.icon = icon
        self.size = size
        self.isTemplate = isTemplate
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName, eventBridge):
            logService.notice(.screenView(name: screenName))
            self.eventBridge = eventBridge
            task?.cancel()
            task = Task { [weak self, appStateClient] in
                await withTaskGroup { group in
                    group.addTask {
                        for await value in StatusBarAppearanceBridge.shared.stream {
                            await self?.update(appearance: value)
                        }
                    }
                    group.addTask {
                        let stream = appStateClient.withLock(\.runnerBundles.stream)
                        for await value in stream {
                            await self?.update(runnerBundle: value)
                        }
                    }
                    group.addTask {
                        let stream = appStateClient.withLock(\.runnerSpeeds.stream)
                        for await value in stream {
                            await self?.update(runnerSpeed: value)
                        }
                    }
                }
            }

        case .onDisappear:
            task?.cancel()
            task = nil
        }
    }

    private func update(appearance: NSAppearance) {
        appearance.performAsCurrentDrawingAppearance {
            tintColor = NSColor.textColor.cgColor
        }
        eventBridge?.setColor(tintColor, isTemplate)
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
        icon = images.first?.plane
        icon?.normalize()
        size = icon?.size ?? .zero
        eventBridge?.setSize(size)
        let isFlippedHorizontally = userDefaultsRepository.isFlippedHorizontally
        isTemplate = runnerBundle.runner.isTemplate
        eventBridge?.setColor(tintColor, isTemplate)
        let imageFrames = images.map { image in
            if isFlippedHorizontally {
                image.flip()
            }
            image.normalize()
            image.isTemplate = isTemplate
            return image
        }
        eventBridge?.setFrames(imageFrames, isTemplate)
    }

    private func update(runnerSpeed: Float) {
        eventBridge?.setSpeed(runnerSpeed)
    }

    public enum Action: Sendable {
        case task(String, EventBridge)
        case onDisappear

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
