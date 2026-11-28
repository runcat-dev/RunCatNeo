/*
 StepCountCardView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/11/28.
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

struct StepCountCardView: View {
    @Environment(\.locale) private var locale

    var statistics: StepStatistics

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "shoeprints.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("runnerTrail", bundle: .module)
                Group {
                    HStack(spacing: 4) {
                        Text("stepsToday:\(compact(statistics.todaySteps))", bundle: .module)
                        Text(verbatim: "·")
                            .foregroundStyle(.tertiary)
                        Text("stepsRecentMinute:\(statistics.stepsInLastMinute)", bundle: .module)
                    }
                    Text("stepsTotal:\(compact(statistics.totalSteps))", bundle: .module)
                    StepBarChartView(records: statistics.recentRecords(limit: 7))
                }
                .font(.caption)
                .padding(.leading, 12)
            }
        }
        .fixedSize()
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.fill.quaternary, in: .rect(cornerRadius: 12))
    }

    private func compact(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName).locale(locale))
    }
}

private struct StepBarChartView: View {
    var records: [StepRecord]

    private let barHeight = CGFloat(22)

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(records) { record in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.accentColor)
                        .frame(width: 8, height: height(of: record))
                    Text(verbatim: weekday(of: record))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func height(of record: StepRecord) -> CGFloat {
        let maxSteps = max(1, records.map(\.steps).max() ?? 1)
        return max(2, barHeight * CGFloat(record.steps) / CGFloat(maxSteps))
    }

    private func weekday(of record: StepRecord) -> String {
        let numbers = record.dayKey.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3,
              let date = Calendar.current.date(from: DateComponents(
                  year: numbers[0],
                  month: numbers[1],
                  day: numbers[2]
              )) else {
            return ""
        }
        return date.formatted(.dateTime.weekday(.narrow))
    }
}
