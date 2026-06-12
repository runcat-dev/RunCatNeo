/*
 RunnerBarView.swift
 UserInterface

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

import Model
import SwiftUI

struct RunnerBarView: View {
    @StateObject var store: RunnerBar

    private var iconImage: NSImage {
        let nsImage = NSImage(size: store.size, flipped: true) { rect in
#if arch(arm64)
            store.icon?.draw(in: rect)
#endif
            return true
        }
        nsImage.isTemplate = store.isTemplate
        return nsImage
    }

    var body: some View {
        Label {
            Text(verbatim: "\0")
        } icon: {
            Image(nsImage: iconImage)
        }
        .labelStyle(isReady: store.isReady)
        .task {
            guard !store.isReady,
                  let statusBarButton = NSApp.statusBarButton(withTitle: "\0"),
                  let window = statusBarButton.window else {
                return
            }
            statusBarButton.tag = .zero
            let gap = 0.5 * statusBarButton.bounds.width
            statusBarButton.wantsLayer = true
            let backgroundLayer = BackgroundLayer(gap: gap)
#if arch(arm64)
            statusBarButton.layer?.addSublayer(backgroundLayer)
#endif
            let runnerLayer = RunnerLayer(gap: gap)
            statusBarButton.layer?.addSublayer(runnerLayer)
            StatusBarAppearanceBridge.shared.send(window.effectiveAppearance)
            await store.send(.task(
                String(describing: Self.self),
                .init(
                    getBundleImage: { NSImage(resource: .init(name: $0, bundle: .module)) },
                    setSize: { backgroundLayer.setSize($0) },
                    setFrames: { runnerLayer.setFrames($0, $1) },
                    setColor: { runnerLayer.setColor($0, $1) },
                    setSpeed: { runnerLayer.setSpeed($0) }
                )
            ))
        }
        // This will not be called within the MenuBarExtra lifecycle,
        // but I am including it here for the sake of formality.
        .onDisappear {
            Task {
                await store.send(.onDisappear)
            }
        }
    }
}

extension RunnerBar: ObservableObject {}
