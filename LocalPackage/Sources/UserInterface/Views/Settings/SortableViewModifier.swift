/*
 SortableViewModifier.swift
 UserInterface

 Created by Takuto Nakamura on 2026/07/22.
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

import SwiftUI

private struct SortableViewModifier<Item: Hashable & Identifiable>: ViewModifier where Item.ID: Sendable & Codable {
    var index: Int
    var item: Item
    @Binding var items: [Item]
    @Binding var draggingItem: Item?

    func body(content: Content) -> some View {
        content
            .draggable(hook(item)) {
                Color.clear.frame(width: 40, height: 40)
            }
            .dropDestination(
                for: DraggableItem.self,
                isEnabled: true,
                action: { _, session in
                    if session.phase == .ended(.move) {
                        draggingItem = nil
                    }
                }
            )
            .dropConfiguration { session in
                if session.phase == .entering,
                   let draggingItem, draggingItem != item,
                   let fromIndex = items.firstIndex(of: draggingItem) {
                    withAnimation(.bouncy) {
                        items.move(
                            fromOffsets: IndexSet(integer: fromIndex),
                            toOffset: index > fromIndex ? index + 1 : index
                        )
                    }
                }
                return DropConfiguration(operation: .move)
            }
    }

    private func hook(_ item: Item) -> DraggableItem {
        draggingItem = item
        return .init(id: item.id)
    }

    private struct DraggableItem: Codable, Transferable {
        var id: Item.ID

        static var transferRepresentation: some TransferRepresentation {
            CodableRepresentation(for: DraggableItem.self, contentType: .data)
        }
    }
}

extension View {
    func sortable<Item: Hashable & Identifiable>(
        index: Int,
        item: Item,
        items: Binding<[Item]>,
        draggingItem: Binding<Item?>
    ) -> some View where Item.ID: Sendable & Codable {
        modifier(SortableViewModifier<Item>(index: index, item: item, items: items, draggingItem: draggingItem))
    }
}
