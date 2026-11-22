import DeviceModel
import Testing

@testable import DataSource
@testable import Model

struct OnboardingServiceTests {
    @Test
    func needsOnboarding_returns_true_when_mac_has_notch_and_onboarding_not_shown() {
        let sut = OnboardingService(.testDependencies(
            deviceModelClient: testDependency(of: DeviceModelClient.self) {
                $0.current = { .Macintosh(.Mac15_6) }
            }
        ))
        #expect(sut.needsOnboarding())
    }

    @Test
    func needsOnboarding_returns_true_when_mac_has_punch_hole_and_onboarding_not_shown() {
        let sut = OnboardingService(.testDependencies(
            deviceModelClient: testDependency(of: DeviceModelClient.self) {
                $0.current = { .Macintosh(.Mac17_13) }
            }
        ))
        #expect(sut.needsOnboarding())
    }

    @Test
    func needsOnboarding_returns_false_when_onboarding_already_shown() {
        let sut = OnboardingService(.testDependencies(
            deviceModelClient: testDependency(of: DeviceModelClient.self) {
                $0.current = { .Macintosh(.Mac15_6) }
            },
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.bool = { $0 == "HAS_SHOWN_ONBOARDING" }
            }
        ))
        #expect(!sut.needsOnboarding())
    }

    @Test
    func needsOnboarding_returns_false_when_mac_has_no_display_cutout() {
        let sut = OnboardingService(.testDependencies(
            deviceModelClient: testDependency(of: DeviceModelClient.self) {
                $0.current = { .Macintosh(.iMac4_1) }
            }
        ))
        #expect(!sut.needsOnboarding())
    }

    @Test
    func needsOnboarding_returns_false_when_device_model_is_unknown() {
        let sut = OnboardingService(.testDependencies())
        #expect(!sut.needsOnboarding())
    }
}
