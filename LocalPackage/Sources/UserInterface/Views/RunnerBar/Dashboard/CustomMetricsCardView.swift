/*
 CustomMetricsCardView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/06.
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

import DataSource
import SwiftUI

struct CustomMetricsCardView: View {
    var snapshot: CustomMetricsSnapshot
    var isFailed: Bool

    init(customMetricsBundle: CustomMetricsBundle) {
        self.snapshot = customMetricsBundle.snapshot
        self.isFailed = customMetricsBundle.isFailed
    }

    private var lastUpdatedDetail: String {
        if isFailed {
            String(localized: "failed", bundle: .module)
        } else {
            snapshot.lastUpdatedDate.formatted(.relative(presentation: .named))
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: snapshot.symbol ?? "waveform.path.ecg.rectangle")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: snapshot.title)
                Group {
                    ForEach(snapshot.metrics.enumerated(), id: \.offset) { _, metric in
                        Text(verbatim: "\(metric.title): \(metric.formattedValue)")
                            .font(.caption)
                        if let normalizedValue = metric.normalizedValue {
                            BarGraphView(value: max(0, min(1, normalizedValue)) * 100)
                        }
                    }
                    Text("lastUpdated:\(lastUpdatedDetail)", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(isFailed ? Color.red : Color.secondary)
                }
                .padding(.leading, 12)
            }
        }
        .fixedSize()
        .padding(.leading, 8)
        .padding(8)
        .materialCellStyle()
    }
}
