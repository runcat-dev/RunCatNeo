import Foundation
import Testing

@testable import DataSource

struct CustomMetricsSnapshotTests {
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @Test
    func decode_full_snapshot_with_symbol_and_metrics() throws {
        let json = """
        {
          "title": "Claude Code",
          "symbol": "staroflife",
          "metrics": [
            { "title": "Context", "formattedValue": "5.4%", "normalizedValue": 0.054 },
            { "title": "Cost", "formattedValue": "$3.21" }
          ],
          "lastUpdatedDate": "2026-06-05T04:50:40Z"
        }
        """.data(using: .utf8)!
        let snapshot = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        #expect(snapshot.title == "Claude Code")
        #expect(snapshot.symbol == "staroflife")
        #expect(snapshot.metrics.count == 2)
        #expect(snapshot.metrics[0].title == "Context")
        #expect(snapshot.metrics[0].formattedValue == "5.4%")
        #expect(snapshot.metrics[0].normalizedValue == 0.054)
        #expect(snapshot.metrics[1].title == "Cost")
        #expect(snapshot.metrics[1].formattedValue == "$3.21")
        #expect(snapshot.metrics[1].normalizedValue == nil)
        let expected = ISO8601DateFormatter().date(from: "2026-06-05T04:50:40Z")
        #expect(snapshot.lastUpdatedDate == expected)
    }

    @Test
    func decode_minimum_snapshot_without_symbol() throws {
        let json = """
        { "title": "Empty Card", "metrics": [], "lastUpdatedDate": "2026-06-05T04:50:40Z" }
        """.data(using: .utf8)!
        let snapshot = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        #expect(snapshot.title == "Empty Card")
        #expect(snapshot.symbol == nil)
        #expect(snapshot.metrics.isEmpty)
        #expect(snapshot.lastUpdatedDate == ISO8601DateFormatter().date(from: "2026-06-05T04:50:40Z"))
    }

    @Test
    func decode_throws_when_title_missing() {
        let json = """
        { "metrics": [], "lastUpdatedDate": "2026-06-05T04:50:40Z" }
        """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        }
    }

    @Test
    func decode_throws_when_lastUpdatedDate_missing() {
        let json = """
        { "title": "Card", "metrics": [] }
        """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        }
    }

    @Test
    func decode_throws_on_invalid_json() {
        let json = "{ not json }".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try decoder.decode(CustomMetricsSnapshot.self, from: json)
        }
    }

    @Test
    func roundtrip_preserves_values() throws {
        let original = CustomMetricsSnapshot(
            title: "GPU",
            symbol: "cpu",
            metrics: [
                CustomMetric(title: "Temp", formattedValue: "64°C", normalizedValue: 0.64),
                CustomMetric(title: "Fan", formattedValue: "1200 RPM"),
            ],
            lastUpdatedDate: Date(timeIntervalSince1970: 1800000000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(CustomMetricsSnapshot.self, from: data)
        #expect(decoded == original)
    }
}
