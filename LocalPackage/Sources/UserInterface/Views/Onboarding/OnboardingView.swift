/*
 OnboardingView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/11/21.
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

struct OnboardingView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @StateObject var store: Onboarding

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("onboardingTitle", bundle: .module)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("onboardingMenuBarApp", bundle: .module)
                } icon: {
                    Image(systemName: "menubar.rectangle")
                }
                Label {
                    Text("onboardingNotch", bundle: .module)
                } icon: {
                    Image(systemName: "eye.slash")
                }
                Label {
                    Text("onboardingRearrange", bundle: .module)
                } icon: {
                    Image(systemName: "command")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Link(destination: URL.menuBarHelp) {
                Text("learnHowToCustomizeMenuBar", bundle: .module)
            }
            Button {
                Task {
                    await store.send(.okButtonTapped(.init { dismissWindow(id: $0) }))
                }
            } label: {
                Text("ok", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 420)
        .task {
            await store.send(.viewAppeared(String(describing: Self.self)))
        }
    }
}

extension Onboarding: ObservableObject {}
