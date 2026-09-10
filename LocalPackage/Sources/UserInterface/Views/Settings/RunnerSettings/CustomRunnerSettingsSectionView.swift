/*
 CustomRunnerSettingsSectionView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/31.
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

struct CustomRunnerSettingsSectionView: View {
    @Environment(\.appDependencies) private var appDependencies
    @State var store: CustomRunnerSettings

    var body: some View {
        Section {
            List {
                ForEach(store.customRunnerBundleList) { runnerBundle in
                    CustomRunnerRowView(
                        runnerBundle: runnerBundle,
                        deleteButtonTapped: {
                            await store.send(.deleteButtonTapped(runnerBundle.runner))
                        }
                    )
                }
                .onMove { indexSet, offset in
                    Task {
                        await store.send(.customRunnerRowMoved(indexSet, offset))
                    }
                }
            }
            HStack {
                Spacer()
                Button {
                    Task {
                        await store.send(.addCustomRunnerButtonTapped(appDependencies))
                    }
                } label: {
                    Label {
                        Text("addCustomRunner", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .sheet(item: $store.customRunnerEditor) { store in
                    CustomRunnerEditorView(store: store)
                }
                Button {
                    Task {
                        await store.send(.guidanceButtonTapped)
                    }
                } label: {
                    Label {
                        Text("guidance", bundle: .module)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $store.showingGuidancePopover, arrowEdge: .bottom) {
                    GuidanceView(
                        description: "runnerGalleryDescription",
                        linkLabel: "viewRunnerGallery",
                        linkDestination: .runnerGallery
                    )
                }
            }
        } header: {
            Text("customRunners", bundle: .module)
        }
        .task {
            await store.send(.viewAppeared)
        }
    }
}
