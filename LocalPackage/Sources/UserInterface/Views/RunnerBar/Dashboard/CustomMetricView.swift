/*
 CustomMetricView.swift
 UserInterface

 Created on 2026/07/15.
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
import SwiftUI

struct CustomMetricView: View {
    var metric: CustomMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if let state = metric.state {
                    Circle()
                        .fill(state.color)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                }
                Text(verbatim: metric.title)
                Spacer(minLength: 4)
                Text(verbatim: metric.formattedValue)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            if let detail = metric.detail {
                Text(verbatim: detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let normalizedValue = metric.normalizedValue {
                BarGraphView(value: max(0, min(1, normalizedValue)) * 100)
            }
        }
    }
}

private extension CustomMetricState {
    var color: Color {
        switch self {
        case .active: .accentColor
        case .waiting: .orange
        case .completed: .green
        case .error: .red
        }
    }
}
