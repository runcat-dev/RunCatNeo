/*
 CustomMetricsService.swift
 Model

 Created by Takuto Nakamura on 2026/06/06.
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
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct CustomMetricsService {
    private let appStateClient: AppStateClient
    private let dataClient: DataClient
    private let dateClient: DateClient
    private let fileWatcherClient: FileWatcherClient
    private let urlClient: URLClient
    private let uuidClient: UUIDClient
    private let applicationSupportRepository: ApplicationSupportRepository
    private let userDefaultsRepository: UserDefaultsRepository

    private static let symbolImageFileName = "symbol"
    private static let symbolImagePixelSize = 48

    private var snapshotDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(_ appDependencies: AppDependencies) {
        self.appStateClient = appDependencies.appStateClient
        self.dataClient = appDependencies.dataClient
        self.dateClient = appDependencies.dateClient
        self.fileWatcherClient = appDependencies.fileWatcherClient
        self.urlClient = appDependencies.urlClient
        self.uuidClient = appDependencies.uuidClient
        self.applicationSupportRepository = .init(appDependencies.dataClient, appDependencies.fileManagerClient)
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
    }

    func makeSource(of url: URL) throws -> (source: CustomMetricsSource, snapshot: CustomMetricsSnapshot) {
        guard urlClient.startAccessingSecurityScopedResource(url) else {
            throw RCNError.customMetrics(.fileUnreadable)
        }
        defer {
            urlClient.stopAccessingSecurityScopedResource(url)
        }
        guard let data = try? dataClient.read(url) else {
            throw RCNError.customMetrics(.fileUnreadable)
        }
        guard let snapshot = try? snapshotDecoder.decode(CustomMetricsSnapshot.self, from: data) else {
            throw RCNError.customMetrics(.invalidFormat)
        }
        let bookmark = try urlClient.bookmarkData(url, .withSecurityScope)
        let source = CustomMetricsSource(
            id: uuidClient.create(),
            displayName: snapshot.title,
            symbol: snapshot.symbol,
            fileURL: url,
            bookmark: bookmark,
            createdAt: dateClient.now()
        )
        return (source, snapshot)
    }

    func loadSymbolImageData(of url: URL) throws -> Data {
        guard urlClient.startAccessingSecurityScopedResource(url) else {
            throw RCNError.customMetrics(.fileUnreadable)
        }
        defer {
            urlClient.stopAccessingSecurityScopedResource(url)
        }
        guard let data = try? dataClient.read(url) else {
            throw RCNError.customMetrics(.fileUnreadable)
        }
        guard Self.isValidSymbolImage(data) else {
            throw RCNError.customMetrics(.invalidSymbolImage)
        }
        return data
    }

    func add(source: CustomMetricsSource, symbolImageData: Data?) throws {
        if let symbolImageData {
            do {
                try applicationSupportRepository.saveData(
                    directory: source.id.uuidString,
                    fileName: Self.symbolImageFileName,
                    fileType: .png,
                    data: symbolImageData
                )
            } catch {
                throw RCNError.customMetrics(.savingFailed)
            }
        }
        var configuration = userDefaultsRepository.customMetricsConfiguration
        configuration.sources.append(source)
        userDefaultsRepository.customMetricsConfiguration = configuration
    }

    func removeSource(of id: UUID) {
        var configuration = userDefaultsRepository.customMetricsConfiguration
        configuration.sources.removeAll { $0.id == id }
        userDefaultsRepository.customMetricsConfiguration = configuration
        applicationSupportRepository.delete(directory: id.uuidString)
        var metricsBarConfiguration = userDefaultsRepository.metricsBarConfiguration
        metricsBarConfiguration.visibleCustomMetricsSourceIDs.remove(id)
        userDefaultsRepository.metricsBarConfiguration = metricsBarConfiguration
    }

    func moveSources(fromOffsets source: IndexSet, toOffset destination: Int) {
        var configuration = userDefaultsRepository.customMetricsConfiguration
        configuration.sources.move(fromOffsets: source, toOffset: destination)
        userDefaultsRepository.customMetricsConfiguration = configuration
    }

    func perform(action: (_ securityScopedURL: URL) -> Void, for source: CustomMetricsSource) throws {
        let (isStale, url) = try urlClient.create(source.bookmark, .withSecurityScope)
        if isStale, let refreshed = try? urlClient.bookmarkData(url, .withSecurityScope) {
            persistRefreshedBookmark(refreshed, for: source.id)
        }
        guard urlClient.startAccessingSecurityScopedResource(url) else {
            throw RCNError.customMetrics(.fileUnreadable)
        }
        defer {
            urlClient.stopAccessingSecurityScopedResource(url)
        }
        action(url)
    }

    func emitConfigurationChange() {
        appStateClient.send(\.customMetricsConfigurationChanges, ())
    }

    func stopMonitoring() {
        appStateClient.withLock {
            $0.customMetricsReconcileObserver?.cancel()
            $0.customMetricsReconcileObserver = nil
            $0.customMetricsObservers.values.forEach { $0.cancel() }
            $0.customMetricsObservers.removeAll()
        }
        appStateClient.send(\.metrics, default: .init()) { metrics in
            metrics.customMetricsBundles.removeAll()
        }
    }

    func startMonitoring() {
        reconcile()
        if appStateClient.withLock(\.customMetricsReconcileObserver) == nil {
            let task = Task {
                let stream = appStateClient.withLock(\.customMetricsConfigurationChanges.stream)
                for await _ in stream {
                    reconcile()
                }
            }
            appStateClient.withLock {
                $0.customMetricsReconcileObserver = task
            }
        }
    }

    private func reconcile() {
        let sources = userDefaultsRepository.customMetricsConfiguration.sources
        let desiredIDs = Set(sources.map(\.id))
        let newSources = appStateClient.withLock { appState -> [CustomMetricsSource] in
            let currentIDs = Set(appState.customMetricsObservers.keys)
            let staleIDs = currentIDs.subtracting(desiredIDs)
            staleIDs.forEach {
                appState.customMetricsObservers[$0]?.cancel()
                appState.customMetricsObservers.removeValue(forKey: $0)
            }
            return sources.filter {
                appState.customMetricsObservers[$0.id] == nil
            }
        }
        appStateClient.send(\.metrics, default: .init()) { metrics in
            metrics.customMetricsBundles = Self.sortedBySourceOrder(metrics.customMetricsBundles, sources: sources)
        }
        newSources.forEach { source in
            let observer = makeObserver(for: source)
            appStateClient.withLock {
                $0.customMetricsObservers[source.id] = observer
            }
        }
    }

    private func emitFailure(for source: CustomMetricsSource, symbolImageData: Data?) {
        let sources = userDefaultsRepository.customMetricsConfiguration.sources
        appStateClient.send(\.metrics, default: .init()) { metrics in
            if let index = metrics.customMetricsBundles.firstIndex(where: { $0.id == source.id }) {
                metrics.customMetricsBundles[index].isFailed = true
            } else {
                metrics.customMetricsBundles.append(CustomMetricsBundle(
                    id: source.id,
                    snapshot: CustomMetricsSnapshot(
                        title: source.displayName,
                        symbol: source.symbol,
                        lastUpdatedDate: source.createdAt
                    ),
                    symbolImageData: symbolImageData,
                    isFailed: true
                ))
            }
            metrics.customMetricsBundles = Self.sortedBySourceOrder(metrics.customMetricsBundles, sources: sources)
        }
    }

    private func emitSuccess(snapshot: CustomMetricsSnapshot, for source: CustomMetricsSource, symbolImageData: Data?) {
        let sources = userDefaultsRepository.customMetricsConfiguration.sources
        appStateClient.send(\.metrics, default: .init()) { metrics in
            if let index = metrics.customMetricsBundles.firstIndex(where: { $0.id == source.id }) {
                metrics.customMetricsBundles[index].snapshot = snapshot
                metrics.customMetricsBundles[index].isFailed = false
            } else {
                metrics.customMetricsBundles.append(CustomMetricsBundle(
                    id: source.id,
                    snapshot: snapshot,
                    symbolImageData: symbolImageData,
                    isFailed: false
                ))
            }
            metrics.customMetricsBundles = Self.sortedBySourceOrder(metrics.customMetricsBundles, sources: sources)
        }
    }

    private static func sortedBySourceOrder(
        _ bundles: [CustomMetricsBundle],
        sources: [CustomMetricsSource]
    ) -> [CustomMetricsBundle] {
        sources.compactMap { source in
            bundles.first { $0.id == source.id }
        }
    }

    private func makeObserver(for source: CustomMetricsSource) -> Task<Void, Never> {
        let symbolImageData = applicationSupportRepository.loadData(
            directory: source.id.uuidString,
            fileName: Self.symbolImageFileName,
            fileType: .png
        )
        return Task {
            var currentBookmark = source.bookmark
            while !Task.isCancelled {
                do {
                    let (isStale, url) = try urlClient.create(currentBookmark, .withSecurityScope)
                    if isStale, let refreshed = try? urlClient.bookmarkData(url, .withSecurityScope) {
                        currentBookmark = refreshed
                        persistRefreshedBookmark(refreshed, for: source.id)
                    }
                    guard urlClient.startAccessingSecurityScopedResource(url) else {
                        emitFailure(for: source, symbolImageData: symbolImageData)
                        try await Task.sleep(for: .seconds(5))
                        continue
                    }
                    defer {
                        urlClient.stopAccessingSecurityScopedResource(url)
                    }
                    loadSnapshot(from: url, for: source, symbolImageData: symbolImageData)
                    let watchStream = fileWatcherClient.watch(url)
                    for await _ in watchStream {
                        if Task.isCancelled { break }
                        loadSnapshot(from: url, for: source, symbolImageData: symbolImageData)
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                } catch is CancellationError {
                    return
                } catch {
                    emitFailure(for: source, symbolImageData: symbolImageData)
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }
    }

    private func loadSnapshot(from url: URL, for source: CustomMetricsSource, symbolImageData: Data?) {
        do {
            let data = try dataClient.read(url)
            let snapshot = try snapshotDecoder.decode(CustomMetricsSnapshot.self, from: data)
            emitSuccess(snapshot: snapshot, for: source, symbolImageData: symbolImageData)
        } catch {
            emitFailure(for: source, symbolImageData: symbolImageData)
        }
    }

    private static func isValidSymbolImage(_ data: Data) -> Bool {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(imageSource) as String? == UTType.png.identifier,
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int,
              let hasAlpha = properties[kCGImagePropertyHasAlpha] as? Bool else {
            return false
        }
        return pixelWidth == symbolImagePixelSize && pixelHeight == symbolImagePixelSize && hasAlpha
    }

    private func persistRefreshedBookmark(_ bookmark: Data, for sourceID: UUID) {
        var configuration = userDefaultsRepository.customMetricsConfiguration
        guard let index = configuration.sources.firstIndex(where: { $0.id == sourceID }) else {
            return
        }
        configuration.sources[index].bookmark = bookmark
        userDefaultsRepository.customMetricsConfiguration = configuration
    }
}
