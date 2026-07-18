/*
 CustomMetricsSettingsSectionView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/07.
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
import Model
import Observation
import SwiftUI
import UniformTypeIdentifiers

struct CustomMetricsSettingsSectionView: View {
    @State var store: CustomMetricsSettings
    @State private var dragState = CustomMetricsSourceDragState()

    var body: some View {
        Section {
            ForEach(store.customMetricsSources) { source in
                CustomMetricsSourceRowView(
                    source: source,
                    isErrorDetected: store.failedCustomMetricsSourceIDs.contains(source.id),
                    removeButtonTapped: {
                        await store.send(.removeCustomMetricsSourceButtonTapped(source.id))
                    },
                    sourceLinkTapped: {
                        await store.send(.customMetricsSourceLinkTapped(source))
                    }
                )
                .opacity(dragState.sourceID == source.id ? 0 : 1)
                .onDrag {
                    dragState.begin(sourceID: source.id)
                    return NSItemProvider(object: source.id.uuidString as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: CustomMetricsSourceDropDelegate(
                        destinationSourceID: source.id,
                        dragState: dragState,
                        move: { sourceID, destinationID in
                            Task {
                                await store.send(.customMetricsSourceMoved(sourceID, destinationID))
                            }
                        }
                    )
                )
            }
            HStack {
                Spacer()
                Button {
                    Task {
                        await store.send(.addCustomMetricsSourceButtonTapped)
                    }
                } label: {
                    Label {
                        Text("addCustomMetricsSource", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                Button {
                    Task {
                        await store.send(.helpButtonTapped)
                    }
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $store.showingHelpPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("customMetricsDescription", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Link(destination: URL.customMetricsSchema) {
                            Text("viewJsonSchemaAndSamples", bundle: .module)
                                .font(.caption)
                        }
                    }
                    .padding()
                    .frame(maxWidth: 360, alignment: .leading)
                }
            }
        } header: {
            Text("customMetrics", bundle: .module)
        }
        .fileImporter(
            isPresented: $store.showingFileImporter,
            allowedContentTypes: [.json],
            onCompletion: { result in
                Task {
                    await store.send(.onCompletionFileImporter(result))
                }
            }
        )
        .fileDialogMessage(Text("chooseJsonFile", bundle: .module))
        .fileDialogConfirmationLabel(Text("add", bundle: .module))
        .confirmationDialog(
            Text("removeCustomMetrics", bundle: .module),
            isPresented: $store.showingConfirmationDialog,
            presenting: store.pendingRemovalSourceID,
            actions: { sourceID in
                Button(role: .destructive) {
                    Task {
                        await store.send(.removingCustomMetricsSourceConfirmed)
                    }
                } label: {
                    Text("remove", bundle: .module)
                }
                Button(role: .cancel) {
                    Task {
                        await store.send(.removingCustomMetricsSourceCancelled)
                    }
                } label: {
                    Text("cancel", bundle: .module)
                }
            },
            message: { _ in
                Text("customMetricsConfirmationMessage", bundle: .module)
            }
        )
        .task {
            await store.send(.task)
        }
        .onDisappear {
            dragState.end()
            Task {
                await store.send(.onDisappear)
            }
        }
    }
}

@MainActor @Observable
private final class CustomMetricsSourceDragState {
    var sourceID: UUID?

    @ObservationIgnored private var mouseUpMonitor: Any?

    func begin(sourceID: UUID) {
        self.sourceID = sourceID
        guard mouseUpMonitor == nil else { return }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.end()
            return event
        }
    }

    func end() {
        sourceID = nil
        guard let mouseUpMonitor else { return }
        NSEvent.removeMonitor(mouseUpMonitor)
        self.mouseUpMonitor = nil
    }
}

private struct CustomMetricsSourceDropDelegate: DropDelegate {
    var destinationSourceID: UUID
    var dragState: CustomMetricsSourceDragState
    var move: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedSourceID = dragState.sourceID,
              draggedSourceID != destinationSourceID else {
            return
        }
        move(draggedSourceID, destinationSourceID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragState.end()
        return true
    }
}
