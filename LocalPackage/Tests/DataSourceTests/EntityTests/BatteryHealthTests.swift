import Foundation
import SystemInfoKit
import Testing

@testable import DataSource

struct BatteryHealthTests {
    @Test(arguments: [
        ("90%", 90.0),
        (" 90%\n", 90.0),
        ("90 %", 90.0),
        ("93.5%", 93.5),
        ("0%", 0.0),
        ("100%", 100.0),
    ])
    func maximumCapacityPercent_reads_system_health(text: String, expected: Double) throws {
        #expect(BatteryHealthReport.maximumCapacityPercent(from: try report(text)) == expected)
    }

    @Test(arguments: ["N/A", "", "101%", "-1%", "nan%", "inf%", "90"])
    func maximumCapacityPercent_rejects_invalid_values(_ text: String) throws {
        #expect(BatteryHealthReport.maximumCapacityPercent(from: try report(text)) == nil)
    }

    @Test
    func maximumCapacityPercent_rejects_unrelated_and_incomplete_reports() throws {
        #expect(BatteryHealthReport.maximumCapacityPercent(from: Data("not JSON".utf8)) == nil)
        #expect(BatteryHealthReport.maximumCapacityPercent(from: Data("{}".utf8)) == nil)
        #expect(BatteryHealthReport.maximumCapacityPercent(from: try report(NSNull())) == nil)
        #expect(BatteryHealthReport.maximumCapacityPercent(from: try report(true)) == nil)
    }

    @Test(arguments: [1.0, 0.85])
    func details_preserve_charge_and_replace_estimated_health(_ estimatedHealth: Double) {
        let status = BatteryStatusInfo(battery: chargedBattery(health: estimatedHealth), maximumCapacityPercent: 90)
        #expect(status.description == chargedBattery(health: 0.9).description)
        #expect(status.percentage.value == 100)
    }

    @Test(arguments: [nil, -1.0, 101.0, Double.nan, Double.infinity] as [Double?])
    func details_show_unavailable_instead_of_a_fake_percentage(_ value: Double?) {
        let battery = chargedBattery(health: 1)
        let status = BatteryStatusInfo(battery: battery, maximumCapacityPercent: value)
        #expect(status.details[1].contains("—"))
        #expect(!status.details[1].contains("%"))
        #expect(status.summary == battery.summary)
    }

    @Test
    func details_keep_valid_zero_health() {
        let status = BatteryStatusInfo(battery: chargedBattery(health: 1), maximumCapacityPercent: 0)
        #expect(status.description == chargedBattery(health: 0).description)
    }

    private func report(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "SPPowerDataType": [
                ["sppower_ac_charger_information": ["sppower_charger_watts": 65]],
                ["sppower_battery_health_info": ["sppower_battery_health_maximum_capacity": value]],
            ],
        ])
    }

    private func chargedBattery(health: Double) -> BatteryInfo {
        BatteryInfo(
            percentage: .init(rawValue: 1, width: 5),
            isInstalled: true,
            isCharging: false,
            adapterName: "Power Adapter",
            maxCapacity: .init(rawValue: health, width: 5),
            cycleCount: 127,
            temperature: .init(value: 37)
        )
    }
}
