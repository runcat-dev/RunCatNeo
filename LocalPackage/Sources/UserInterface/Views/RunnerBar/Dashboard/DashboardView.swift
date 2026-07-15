/*
 DashboardView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/08.
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
import DataSource
import Model
import SwiftUI

struct DashboardView: View {
    @Environment(\.appDependencies) private var appDependencies
    @StateObject var store: Dashboard

    private var screenVisibleFrame: CGRect? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
    }

    var body: some View {
        DashboardColumnsLayout(maximumHeight: screenVisibleFrame?.height) {
            HStack {
                Text(store.appName)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                Spacer()
                MenuView(
                    appName: store.appName,
                    isPreview: store.isPreview,
                    buttonTapped: { action in
                        await store.send(action)
                    }
                )
            }
            .frame(maxWidth: .infinity)
            SystemInfoStackView(
                systemInfoBundle: store.systemInfoBundle,
                cpuRingBuffer: store.cpuRingBuffer,
                memoryRingBuffer: store.memoryRingBuffer,
                isPreview: store.isPreview
            )
            ForEach(store.customMetricsBundles) { customMetricsBundle in
                CustomMetricsCardView(customMetricsBundle: customMetricsBundle)
                    .layoutValue(
                        key: TextOverflowLayoutValueKey.self,
                        value: customMetricsBundle.snapshot.textOverflow ?? .expand
                    )
            }
        }
        .padding(8)
        .task {
            await store.send(.task(String(describing: Self.self)))
        }
        .onDisappear {
            Task {
                await store.send(.onDisappear)
            }
        }
    }
}

private struct DashboardColumnsLayout: Layout {
    var maximumHeight: CGFloat?
    private let spacing: CGFloat = 8

    private struct Column {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func columns(for subviews: Subviews, heightLimit: CGFloat?) -> [Column] {
        let baseWidth = subviews.count > 1
            ? subviews[subviews.index(subviews.startIndex, offsetBy: 1)].sizeThatFits(.unspecified).width
            : 0
        let indices = Array(subviews.indices.dropFirst())
        var columns: [Column] = []
        var start = indices.startIndex
        while start < indices.endIndex {
            var selectedColumn = measuredColumn(
                indices: [indices[start]],
                baseWidth: baseWidth,
                subviews: subviews,
                heightLimit: heightLimit
            )
            var selectedEnd = start
            for end in indices.indices[start...].dropFirst() {
                let column = measuredColumn(
                    indices: Array(indices[start...end]),
                    baseWidth: baseWidth,
                    subviews: subviews,
                    heightLimit: heightLimit
                )
                if heightLimit.map({ column.height <= $0 }) ?? true {
                    selectedColumn = column
                    selectedEnd = end
                }
            }
            columns.append(selectedColumn)
            start = indices.index(after: selectedEnd)
        }
        return columns
    }

    private func measuredColumn(
        indices: [Int],
        baseWidth: CGFloat,
        subviews: Subviews,
        heightLimit: CGFloat?
    ) -> Column {
        let width = indices.reduce(baseWidth) { width, index in
            guard subviews[index][TextOverflowLayoutValueKey.self] == .expand else { return width }
            return max(width, subviews[index].sizeThatFits(.unspecified).width)
        }
        let height = indices.reduce(0) { height, index in
            let naturalHeight = subviews[index].sizeThatFits(
                ProposedViewSize(width: width, height: nil)
            ).height
            let itemHeight = min(naturalHeight, heightLimit ?? naturalHeight)
            return height + (height > 0 ? spacing : 0) + itemHeight
        }
        return Column(indices: indices, width: width, height: height)
    }

    private func layout(for subviews: Subviews) -> (headerSize: CGSize, columns: [Column]) {
        guard let header = subviews.first else { return (.zero, []) }
        let headerSize = header.sizeThatFits(.unspecified)
        let heightLimit = maximumHeight.flatMap {
            $0.isFinite ? max(1, $0 - 16 - headerSize.height - spacing) : nil
        }
        return (headerSize, columns(for: subviews, heightLimit: heightLimit))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let layout = layout(for: subviews)
        let columns = layout.columns
        let columnsWidth = columns.reduce(0) { $0 + $1.width }
            + spacing * CGFloat(max(0, columns.count - 1))
        return CGSize(
            width: max(layout.headerSize.width, columnsWidth),
            height: layout.headerSize.height
                + (columns.isEmpty ? 0 : spacing + (columns.map(\.height).max() ?? 0))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let header = subviews.first else { return }
        let layout = layout(for: subviews)
        header.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: layout.headerSize.height)
        )
        var x = bounds.minX
        let heightLimit = maximumHeight.flatMap {
            $0.isFinite ? max(1, $0 - 16 - layout.headerSize.height - spacing) : nil
        }
        for column in layout.columns {
            var y = bounds.minY + layout.headerSize.height + spacing
            for index in column.indices {
                let naturalSize = subviews[index].sizeThatFits(ProposedViewSize(width: column.width, height: nil))
                let height = min(naturalSize.height, heightLimit ?? naturalSize.height)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: column.width, height: height)
                )
                y += height + spacing
            }
            x += column.width + spacing
        }
    }
}

private struct TextOverflowLayoutValueKey: LayoutValueKey {
    static let defaultValue = CustomMetricsTextOverflow.truncate
}

extension Dashboard: ObservableObject {}
