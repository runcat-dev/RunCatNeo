/*
 FrameImagesCollectionView.swift
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

struct FrameImagesCollectionView: View {
    @Bindable var store: CustomRunnerSettings
    private let columns = [GridItem](repeating: .init(.flexible(), spacing: 4), count: 5)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(store.frameImages.enumerated(), id: \.element) { index, frameImage in
                        FrameImageCellView(
                            index: index,
                            frameImage: frameImage,
                            isTemplate: store.isTemplate,
                            isSelected: store.selectingFrameImage == frameImage
                        )
                        .onTapGesture {
                            Task {
                                await store.send(.onTapFrameImageCell(frameImage))
                            }
                        }
                        .sortable(
                            index: index,
                            item: frameImage,
                            items: $store.frameImages,
                            draggingItem: $store.selectingFrameImage
                        )
                    }
                }
            }
            .background(Color(.controlBackgroundColor))
            .onTapGesture {
                Task {
                    await store.send(.onTapCollectionBackground)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                Task {
                    await store.send(.onDropFiles(urls))
                }
                return true
            }
            Divider()
            HStack(spacing: 0) {
                Button {
                    Task {
                        await store.send(.addFrameButtonTapped)
                    }
                } label: {
                    Label {
                        Text("addFrame", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.segmented)
                Button {
                    Task {
                        await store.send(.deleteFrameButtonTapped)
                    }
                } label: {
                    Label {
                        Text("deleteFrame", bundle: .module)
                    } icon: {
                        Image(systemName: "minus")
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.segmented)
                .disabled(store.selectingFrameImage == nil)
                Spacer()
            }
        }
        .frame(width: 256, height: 180) // 256 = 48 × 5 + 4 × 4
        .border(Color(.separatorColor))
    }
}
