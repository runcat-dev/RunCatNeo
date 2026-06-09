/*
 CustomRunnerSettingsSectionView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/31.
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

struct CustomRunnerSettingsSectionView: View {
    @State var store: CustomRunnerSettings

    var body: some View {
        Section {
            ForEach(store.customRunnerBundleList, id: \.runner) { runnerBundle in
                LabeledContent {
                    Button(role: .destructive) {
                        Task {
                            await store.send(.deleteButtonTapped(runnerBundle.runner))
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.borderless)
                } label: {
                    Label {
                        runnerBundle.runner.displayText
                    } icon: {
                        runnerBundle.thumbnail
                    }
                }
            }
            HStack {
                Spacer()
                Button {
                    Task {
                        await store.send(.addCustomRunnerButtonTapped)
                    }
                } label: {
                    Label {
                        Text("addCustomRunner", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .sheet(isPresented: $store.showingCustomRunnerEditorSheet) {
                    Task {
                        await store.send(.onDissmissSheet)
                    }
                } content: {
                    CustomRunnerEditorView(store: store)
                }
            }
        } header: {
            Text("customRunners", bundle: .module)
        }
        .task {
            await store.send(.task)
        }
        .onDisappear {
            Task {
                await store.send(.onDisappear)
            }
        }
    }
}
