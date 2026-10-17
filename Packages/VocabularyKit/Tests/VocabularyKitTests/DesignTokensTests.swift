import Foundation
import Testing

@testable import VocabularyKit

@Suite("DesignTokens")
struct DesignTokensTests {
    @Test("Contrast ratio matches the WCAG reference values")
    func referenceRatios() {
        let white = RGBColor(hex: 0xFFFFFF)
        let black = RGBColor(hex: 0x000000)
        #expect(abs(RGBColor.contrastRatio(white, black) - 21) < 0.001)
        #expect(abs(RGBColor.contrastRatio(white, white) - 1) < 0.001)
        #expect(RGBColor.contrastRatio(white, black) == RGBColor.contrastRatio(black, white))
    }

    @Test("Hex parsing splits components")
    func hexParsing() {
        let color = RGBColor(hex: 0x8E97FD)
        #expect(color.red == 0x8E && color.green == 0x97 && color.blue == 0xFD)
    }

    @Test("The kit's original values fail AA, which is why they were adjusted")
    func kitValuesNeedAdjustment() {
        let white = RGBColor(hex: 0xFFFFFF)
        #expect(RGBColor.contrastRatio(white, RGBColor(hex: 0x8E97FD)) < 4.5)
        #expect(RGBColor.contrastRatio(RGBColor(hex: 0xA1A4B2), white) < 4.5)
    }

    @Test("Every UI color pair meets its threshold in light and dark appearance")
    func allPairsMeetThresholds() {
        for requirement in DesignTokens.contrastRequirements {
            let light = RGBColor.contrastRatio(requirement.foreground.light, requirement.background.light)
            let dark = RGBColor.contrastRatio(requirement.foreground.dark, requirement.background.dark)
            #expect(light >= requirement.minimumRatio, "\(requirement.name) (light) is \(light)")
            #expect(dark >= requirement.minimumRatio, "\(requirement.name) (dark) is \(dark)")
        }
    }
}
