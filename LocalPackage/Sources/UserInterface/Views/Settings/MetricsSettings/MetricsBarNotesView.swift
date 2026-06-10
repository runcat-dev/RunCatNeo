/*
 MetricsBarNotesView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/10.
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

import Model
import SwiftUI

struct MetricsBarNotesView: View {
    var store: MetricsSettings

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName)!)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
            VStack(spacing: 8) {
                Text("notesOnUsingMetricsBar", bundle: .module)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("metricsBarNotes", bundle: .module)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 8) {
                MenuBarSampleView(kind: .withoutNotch)
                MenuBarSampleView(kind: .withNotch)
                Button {
                    Task {
                        await store.send(.changedMyMindButtonTapped)
                    }
                } label: {
                    Text("changedMyMind", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                Button(role: .cancel) {
                    Task {
                        await store.send(.showButtonTapped)
                    }
                } label: {
                    Text("show", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .frame(width: 320)
        .padding(16)
    }
}
