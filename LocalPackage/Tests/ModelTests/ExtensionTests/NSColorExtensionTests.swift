import AppKit
import Testing

@testable import Model

@MainActor
struct NSColorExtensionTests {
    @Test
    func cgColor_resolves_dynamic_color_in_given_appearance() throws {
        let lightAppearance = try #require(NSAppearance(named: .aqua))
        let darkAppearance = try #require(NSAppearance(named: .darkAqua))
        #expect(NSColor.textColor.cgColor(in: lightAppearance).components == [0, 0, 0, 1])
        #expect(NSColor.textColor.cgColor(in: darkAppearance).components == [1, 1, 1, 1])
    }
}
