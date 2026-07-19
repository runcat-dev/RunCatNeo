/*
 MetricsBarView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/24.
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
import SystemInfoKit

struct MetricsBarView: View {
    @StateObject var store: MetricsBar

    private var usageIndicatorKind: IndicatorKind {
        switch store.metricsBarConfiguration.resolvedValueStyle {
        case .percentage: .usageFullLabel
        case .bar: .usageBar
        case .pie: .usagePieChart
        }
    }

    private var size: CGSize {
        var widthArray = [CGFloat]()
        let iconWidth = IndicatorKind.categoryIcon.size.width
        if store.metricsBarConfiguration.showsCPU, store.systemInfoBundle.cpuInfo != nil {
            widthArray.append(iconWidth + usageIndicatorKind.size.width)
        }
        if store.metricsBarConfiguration.showsMemory, store.systemInfoBundle.memoryInfo != nil {
            widthArray.append(iconWidth + usageIndicatorKind.size.width)
        }
        if store.metricsBarConfiguration.showsStorage, store.systemInfoBundle.storageInfo != nil {
            widthArray.append(iconWidth + usageIndicatorKind.size.width)
        }
        if store.metricsBarConfiguration.showsBattery,
           let batteryInfo = store.systemInfoBundle.batteryInfo?.simulated(store.isPreview) {
            if batteryInfo.isInstalled && store.metricsBarConfiguration.resolvedBatteryStyle == .percentage {
                let boltWidth = batteryInfo.isCharging ? IndicatorKind.boltIcon.size.width : 0
                widthArray.append(iconWidth + boltWidth + IndicatorKind.usageFullLabel.size.width)
            } else {
                widthArray.append(iconWidth)
            }
        }
        if store.metricsBarConfiguration.showsNetwork, store.systemInfoBundle.networkInfo != nil {
            widthArray.append(iconWidth + IndicatorKind.usageHalfLabel.size.width)
        }
        for bundle in store.customMetricsBundles where store.metricsBarConfiguration.showsCustomMetrics(of: bundle.id) {
            widthArray.append(iconWidth + IndicatorKind.customValueLabelSize(for: bundle.metricsBarLabel).width)
        }
        let width = if widthArray.isEmpty {
            IndicatorKind.sleepingCat.size.width
        } else {
            widthArray.joined(separator: IndicatorKind.spacer.size.width)
        }
        return CGSize(width: width, height: 18)
    }

    var body: some View {
        Image(size: size) { context in
            if store.metricsBarConfiguration.isEmpty {
                context.drawBlackImage(origin: .zero, size: IndicatorKind.sleepingCat.size) {
                    Image(.sleepingCat)
                }
            } else {
                var point = CGPoint(x: 0, y: 1)
                if store.metricsBarConfiguration.showsCPU, let cpuInfo = store.systemInfoBundle.cpuInfo {
                    drawSystemInfo(context: &context, point: &point, systemInfo: cpuInfo)
                }
                if store.metricsBarConfiguration.showsMemory, let memoryInfo = store.systemInfoBundle.memoryInfo {
                    drawSystemInfo(context: &context, point: &point, systemInfo: memoryInfo)
                }
                if store.metricsBarConfiguration.showsStorage, let storageInfo = store.systemInfoBundle.storageInfo {
                    drawSystemInfo(context: &context, point: &point, systemInfo: storageInfo)
                }
                if store.metricsBarConfiguration.showsBattery, let batteryInfo = store.systemInfoBundle.batteryInfo?.simulated(store.isPreview) {
                    drawSystemInfo(context: &context, point: &point, systemInfo: batteryInfo)
                }
                if store.metricsBarConfiguration.showsNetwork, let networkInfo = store.systemInfoBundle.networkInfo {
                    drawSystemInfo(context: &context, point: &point, systemInfo: networkInfo)
                }
                for bundle in store.customMetricsBundles where store.metricsBarConfiguration.showsCustomMetrics(of: bundle.id) {
                    drawCustomMetrics(context: &context, point: &point, bundle: bundle)
                }
            }
        }
        .renderingMode(.template)
        .task {
            await store.send(.task(String(describing: Self.self)))
        }
    }

    private func drawSystemInfo(
        context: inout GraphicsContext,
        point: inout CGPoint,
        systemInfo: any SystemInfo
    ) {
        let iconSize = IndicatorKind.categoryIcon.size

        if let batteryInfo = systemInfo as? BatteryInfo,
           batteryInfo.isInstalled,
           store.metricsBarConfiguration.resolvedBatteryStyle == .compact {
            context.drawBatteryIndicator(origin: point, size: iconSize, percentage: batteryInfo.percentage.value, isCharging: batteryInfo.isCharging)
            point.x += iconSize.width + IndicatorKind.spacer.size.width
            return
        }

        context.drawIcon(systemName: systemInfo.icon, point: point, size: iconSize)
        point.x += iconSize.width

        switch systemInfo {
        case is CPUInfo, is MemoryInfo, is StorageInfo:
            drawUsage(context: &context, point: point, percentage: systemInfo.percentage)
            point.x += usageIndicatorKind.size.width + IndicatorKind.spacer.size.width

        case let batteryInfo as BatteryInfo:
            if batteryInfo.isInstalled {
                if batteryInfo.isCharging {
                    context.drawBoltIcon(point: point, size: IndicatorKind.boltIcon.size)
                    point.x += IndicatorKind.boltIcon.size.width
                }
                context.drawBlackText(origin: point, size: IndicatorKind.usageFullLabel.size) {
                    Text(verbatim: batteryInfo.percentage.menuBarDescription)
                }
                point.x += IndicatorKind.usageFullLabel.size.width
            }
            point.x += IndicatorKind.spacer.size.width

        case let networkInfo as NetworkInfo:
            let labelSize = IndicatorKind.usageHalfLabel.size
            context.drawBlackText(origin: CGPoint(x: point.x, y: 1), size: labelSize) {
                Text(verbatim: "\u{2B06}\(networkInfo.upload.menuBarDescription(type: .network))")
                    .font(.system(size: 7))
                    .monospaced()
            }
            context.drawBlackText(origin: CGPoint(x: point.x, y: 9), size: labelSize) {
                Text(verbatim: "\u{2B07}\(networkInfo.download.menuBarDescription(type: .network))")
                    .font(.system(size: 7))
                    .monospaced()
            }
            point.x += labelSize.width + IndicatorKind.spacer.size.width

        default:
            break
        }
    }

    private func drawUsage(
        context: inout GraphicsContext,
        point: CGPoint,
        percentage: Percentage
    ) {
        switch store.metricsBarConfiguration.resolvedValueStyle {
        case .percentage:
            context.drawBlackText(origin: point, size: usageIndicatorKind.size) {
                Text(verbatim: percentage.menuBarDescription)
            }
        case .bar:
            context.drawUsageBar(origin: point, size: usageIndicatorKind.size, percentage: percentage.value)
        case .pie:
            context.drawUsagePieChart(origin: point, size: usageIndicatorKind.size, percentage: percentage.value)
        }
    }

    private func drawCustomMetrics(
        context: inout GraphicsContext,
        point: inout CGPoint,
        bundle: CustomMetricsBundle
    ) {
        let iconSize = IndicatorKind.categoryIcon.size
        context.drawIcon(systemName: bundle.snapshot.displaySymbol, point: point, size: iconSize)
        point.x += iconSize.width
        let labelSize = IndicatorKind.customValueLabelSize(for: bundle.metricsBarLabel)
        context.drawBlackText(origin: point, size: labelSize) {
            Text(verbatim: bundle.metricsBarLabel)
                .monospacedDigit()
        }
        point.x += labelSize.width + IndicatorKind.spacer.size.width
    }
}

extension MetricsBar: ObservableObject {}
