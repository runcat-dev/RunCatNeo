/*
 CustomMetricsSourceEditorView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/11/26.
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

struct CustomMetricsSourceEditorView: View {
    @Bindable var store: CustomMetricsSourceEditor

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent {
                        Button {
                            Task {
                                await store.send(.chooseSourceButtonTapped)
                            }
                        } label: {
                            Text("choose", bundle: .module)
                        }
                        .fileImporter(
                            isPresented: $store.showingSourceFileImporter,
                            allowedContentTypes: [.json],
                            allowsMultipleSelection: false,
                            onCompletion: { result in
                                Task {
                                    await store.send(.sourceFileImporterResponse(result))
                                }
                            }
                        )
                        .fileDialogMessage(Text("chooseJsonFile", bundle: .module))
                    } label: {
                        Text("sourceFile", bundle: .module)
                        if let source = store.source {
                            Text(verbatim: source.fileURL.lastPathComponent)
                                .truncationMode(.middle)
                        }
                    }
                    LabeledContent {
                        if store.symbolImageData == nil {
                            Button {
                                Task {
                                    await store.send(.chooseSymbolImageButtonTapped)
                                }
                            } label: {
                                Text("choose", bundle: .module)
                            }
                            .fileImporter(
                                isPresented: $store.showingSymbolImageFileImporter,
                                allowedContentTypes: [.png],
                                allowsMultipleSelection: false,
                                onCompletion: { result in
                                    Task {
                                        await store.send(.symbolImageFileImporterResponse(result))
                                    }
                                }
                            )
                            .fileDialogMessage(Text("chooseSymbolImage", bundle: .module))
                        } else {
                            Button {
                                Task {
                                    await store.send(.removeSymbolImageButtonTapped)
                                }
                            } label: {
                                Text("remove", bundle: .module)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("symbolImage", bundle: .module)
                            Button {
                                Task {
                                    await store.send(.symbolImageGuidanceButtonTapped)
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
                            .popover(isPresented: $store.showingSymbolImageGuidancePopover, arrowEdge: .bottom) {
                                GuidanceView(
                                    description: "symbolImageDescription",
                                    linkLabel: "viewJsonSchemaAndSamples",
                                    linkDestination: .customMetricsSchema
                                )
                            }
                        }
                        Text("symbolImageRequirements", bundle: .module)
                    }
                    LabeledContent {
                        CustomMetricsCardView(
                            customMetricsBundle: store.previewBundle ?? .init(
                                id: store.id,
                                snapshot: .placeholder,
                                symbolImageData: store.symbolImageData
                            ),
                            displayedDate: .now
                        )
                    } label: {
                        Text("preview", bundle: .module)
                    }
                } header: {
                    Text("customMetricsSourceEditor", bundle: .module)
                }
            }
            .formStyle(.grouped)
            .fixedSize()
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
                            await store.send(store.isEditing ? .saveButtonTapped : .addButtonTapped)
                        }
                    } label: {
                        if store.isEditing {
                            Text("save", bundle: .module)
                        } else {
                            Text("add", bundle: .module)
                        }
                    }
                    .disabled(!store.canConfirm)
                }
            }
            .alert(
                isPresented: $store.showingAlert,
                error: store.error,
                actions: { _ in },
                message: { _ in }
            )
        }
    }
}
