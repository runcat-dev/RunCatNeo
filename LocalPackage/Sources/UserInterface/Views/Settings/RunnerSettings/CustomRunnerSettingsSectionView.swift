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
    @State var store: CustomRunnerSettings

    var body: some View {
        Section {
            if !store.customRunnerBundleList.isEmpty {
                List {
                    ForEach(store.customRunnerBundleList) { runnerBundle in
                        CustomRunnerRowView(
                            runnerBundle: runnerBundle,
                            editButtonTapped: {
                                await store.send(.editCustomRunnerButtonTapped(runnerBundle.runner))
                            },
                            removeButtonTapped: {
                                await store.send(.removeCustomRunnerButtonTapped(runnerBundle.runner))
                            }
                        )
                    }
                    .onMove { indexSet, offset in
                        Task {
                            await store.send(.customRunnerRowMoved(indexSet, offset))
                        }
                    }
                    .listRowInsets(.vertical, 8)
                }
            }
            HStack {
                Spacer()
                Menu {
                    Button {
                        Task {
                            await store.send(.importRunnerArchiveButtonTapped)
                        }
                    } label: {
                        Label {
                            Text("importRunnerArchive", bundle: .module)
                        } icon: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .labelStyle(.titleAndIcon)
                    }
                } label: {
                    Label {
                        Text("addCustomRunner", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                } primaryAction: {
                    Task {
                        await store.send(.addCustomRunnerButtonTapped)
                    }
                }
                .fixedSize()
                .sheet(item: $store.customRunnerEditor) { store in
                    CustomRunnerEditorView(store: store)
                }
                .fileImporter(
                    isPresented: $store.showingFileImporter,
                    allowedContentTypes: [.zip],
                    onCompletion: { result in
                        Task {
                            await store.send(.fileImporterResponse(result))
                        }
                    }
                )
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
            .alert(
                isPresented: $store.showingAlert,
                error: store.error,
                actions: { _ in },
                message: { _ in }
            )
        } header: {
            Text("customRunners", bundle: .module)
        }
        .task {
            await store.send(.viewAppeared)
        }
    }
}
