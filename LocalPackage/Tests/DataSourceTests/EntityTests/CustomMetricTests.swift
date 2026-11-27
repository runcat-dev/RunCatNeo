import Foundation
import Testing

@testable import DataSource

struct CustomMetricTests {
    @Test
    func decode_with_normalizedValue_yields_value() throws {
        let json = """
            { "title": "Context", "formattedValue": "5.4%", "normalizedValue": 0.054 }
            """.data(using: .utf8)!
        let metric = try JSONDecoder().decode(CustomMetric.self, from: json)
        #expect(metric == CustomMetric(title: "Context", formattedValue: "5.4%", normalized: .value(0.054)))
    }

    @Test
    func decode_with_normalizedValues_yields_values() throws {
        let json = """
            { "title": "GPU", "formattedValue": "42%", "normalizedValues": [0.31, 0.35, 0.42] }
            """.data(using: .utf8)!
        let metric = try JSONDecoder().decode(CustomMetric.self, from: json)
        #expect(metric == CustomMetric(title: "GPU", formattedValue: "42%", normalized: .values([0.31, 0.35, 0.42])))
    }

    @Test
    func decode_with_empty_normalizedValues_yields_empty_values() throws {
        let json = """
            { "title": "GPU", "formattedValue": "0%", "normalizedValues": [] }
            """.data(using: .utf8)!
        let metric = try JSONDecoder().decode(CustomMetric.self, from: json)
        #expect(metric == CustomMetric(title: "GPU", formattedValue: "0%", normalized: .values([])))
    }

    @Test
    func decode_without_normalized_keys_yields_nil() throws {
        let json = """
            { "title": "Model", "formattedValue": "Opus" }
            """.data(using: .utf8)!
        let metric = try JSONDecoder().decode(CustomMetric.self, from: json)
        #expect(metric == CustomMetric(title: "Model", formattedValue: "Opus"))
    }

    @Test
    func decode_throws_when_both_normalizedValue_and_normalizedValues_present() {
        let json = """
            { "title": "GPU", "formattedValue": "42%", "normalizedValue": 0.42, "normalizedValues": [0.31, 0.42] }
            """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(CustomMetric.self, from: json)
        }
    }

    @Test
    func decode_throws_when_normalizedValues_contains_null() {
        let json = """
            { "title": "GPU", "formattedValue": "42%", "normalizedValues": [0.31, null, 0.42] }
            """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(CustomMetric.self, from: json)
        }
    }
}
