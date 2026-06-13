/*
 CustomRunnerEditorView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/03.
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

import DataSource
import Model
import SwiftUI

struct CustomRunnerEditorView: View {
    @Bindable var store: CustomRunnerSettings

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $store.runnerName) {
                        Text("runnerName", bundle: .module)
                    }
                    Picker(selection: Binding<RenderingMode>(
                        get: { .init(isTemplate: store.isTemplate) },
                        asyncSet: { await store.send(.selectRenderingMode($0)) }
                    )) {
                        ForEach(RenderingMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    } label: {
                        Text("renderingMode", bundle: .module)
                    }
                    LabeledContent {
                        FrameImagesCollectionView(store: store)
                    } label: {
                        Text("frames", bundle: .module)
                        Text("requirements", bundle: .module)
                    }
                    LabeledContent {
                        RunnerPreviewView(store: store)
                    } label: {
                        Text("preview", bundle: .module)
                    }
                } header: {
                    Text("customRunnerEditor", bundle: .module)
                }
            }
            .formStyle(.grouped)
            .fixedSize()
            .fileImporter(
                isPresented: $store.showingFileImporter,
                allowedContentTypes: [.png],
                allowsMultipleSelection: true,
                onCompletion: { result in
                    Task {
                        await store.send(.onCompletionFileImporter(result))
                    }
                }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        Task {
                            await store.send(.cancelButtonTapped)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        Task {
                            await store.send(.addButtonTapped)
                        }
                    } label: {
                        Text("add", bundle: .module)
                    }
                    .disabled(!store.canAdd)
                }
            }
        }
    }
}
