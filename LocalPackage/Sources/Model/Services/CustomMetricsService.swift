/*
 CustomMetricsService.swift
 Model

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
import Foundation

struct CustomMetricsService {
    private let appStateClient: AppStateClient
    private let dateClient: DateClient
    private let fileWatcherClient: FileWatcherClient
    private let urlClient: URLClient
    private let uuidClient: UUIDClient
    private let userDefaultsRepository: UserDefaultsRepository

    private var snapshotDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(_ appDependencies: AppDependencies) {
        self.appStateClient = appDependencies.appStateClient
        self.dateClient = appDependencies.dateClient
        self.fileWatcherClient = appDependencies.fileWatcherClient
        self.urlClient = appDependencies.urlClient
        self.uuidClient = appDependencies.uuidClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
    }

    func addSource(of url: URL) throws {
        guard urlClient.startAccessingSecurityScopedResource(url) else {
            throw RCNError.customMetrics(.fileUnreadable)
        }
        defer {
            urlClient.stopAccessingSecurityScopedResource(url)
        }
        let data = try Data(contentsOf: url)
        let snapshot = try snapshotDecoder.decode(CustomMetricsSnapshot.self, from: data)
        let bookmark = try urlClient.bookmarkData(url, .withSecurityScope)
        let source = CustomMetricsSource(
            id: uuidClient.create(),
            displayName: snapshot.title,
            fileURL: url,
            bookmark: bookmark,
            createdAt: dateClient.now()
        )
        var configuration = userDefaultsRepository.customMetricsConfiguration
        configuration.sources.append(source)
        userDefaultsRepository.customMetricsConfiguration = configuration
    }

    func removeSource(of id: UUID) {
        var configuration = userDefaultsRepository.customMetricsConfiguration
        configuration.sources.removeAll { $0.id == id }
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
        appStateClient.withLock {
            $0.customMetricsConfigurationChanges.send()
        }
    }

    func stopMonitoring() {
        appStateClient.withLock {
            $0.customMetricsReconcileObserver?.cancel()
            $0.customMetricsReconcileObserver = nil
            $0.customMetricsObservers.values.forEach { $0.cancel() }
            $0.customMetricsObservers.removeAll()
            var metrics = $0.metrics.latestValue ?? .init()
            metrics.customMetricsBundles.removeAll()
            $0.metrics.send(metrics)
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
        let newSources = appStateClient.withLock { appState in
            let currentIDs = Set(appState.customMetricsObservers.keys)
            let staleIDs = currentIDs.subtracting(desiredIDs)
            staleIDs.forEach {
                appState.customMetricsObservers[$0]?.cancel()
                appState.customMetricsObservers.removeValue(forKey: $0)
            }
            var metrics = appState.metrics.latestValue ?? .init()
            metrics.customMetricsBundles.removeAll {
                staleIDs.contains($0.id)
            }
            appState.metrics.send(metrics)
            return sources.filter {
                appState.customMetricsObservers[$0.id] == nil
            }
        }
        newSources.forEach { source in
            let observer = makeObserver(for: source)
            appStateClient.withLock {
                $0.customMetricsObservers[source.id] = observer
            }
        }
    }

    private func emitFailure(for source: CustomMetricsSource) {
        appStateClient.withLock {
            var metrics = $0.metrics.latestValue ?? .init()
            if let index = metrics.customMetricsBundles.firstIndex(where: { $0.id == source.id }) {
                metrics.customMetricsBundles[index].isFailed = true
            }
            $0.metrics.send(metrics)
        }
    }

    private func emitSuccess(snapshot: CustomMetricsSnapshot, for source: CustomMetricsSource) {
        appStateClient.withLock {
            var metrics = $0.metrics.latestValue ?? .init()
            if let index = metrics.customMetricsBundles.firstIndex(where: { $0.id == source.id }) {
                metrics.customMetricsBundles[index].snapshot = snapshot
                metrics.customMetricsBundles[index].isFailed = false
            } else {
                metrics.customMetricsBundles.append(CustomMetricsBundle(
                    id: source.id,
                    snapshot: snapshot,
                    isFailed: false
                ))
            }
            $0.metrics.send(metrics)
        }
    }

    private func makeObserver(for source: CustomMetricsSource) -> Task<Void, Never> {
        Task {
            var currentBookmark = source.bookmark
            while !Task.isCancelled {
                do {
                    let (isStale, url) = try urlClient.create(currentBookmark, .withSecurityScope)
                    if isStale, let refreshed = try? urlClient.bookmarkData(url, .withSecurityScope) {
                        currentBookmark = refreshed
                        persistRefreshedBookmark(refreshed, for: source.id)
                    }
                    guard urlClient.startAccessingSecurityScopedResource(url) else {
                        emitFailure(for: source)
                        try await Task.sleep(for: .seconds(5))
                        continue
                    }
                    defer {
                        urlClient.stopAccessingSecurityScopedResource(url)
                    }
                    let watchStream = fileWatcherClient.watch(url)
                    for await _ in watchStream {
                        if Task.isCancelled { break }
                        do {
                            let data = try Data(contentsOf: url)
                            let snapshot = try snapshotDecoder.decode(CustomMetricsSnapshot.self, from: data)
                            emitSuccess(snapshot: snapshot, for: source)
                        } catch {
                            emitFailure(for: source)
                        }
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                } catch is CancellationError {
                    return
                } catch {
                    emitFailure(for: source)
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }
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
