//
//  UIColor+AltStore.swift
//  AltStore
//
//  Created by Riley Testut on 5/9/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

public extension UIColor
{
    private static func namedColor(_ name: String) -> UIColor? {
        return UIColor(named: name, in: .main, compatibleWith: nil)
    }

    static var altPrimary: UIColor {
        #if WIDGET_EXTENSION
        return defaultAltPrimary
        #else
        return ThemeManager.shared.primaryColor
        #endif
    }
    static let defaultAltPrimary = namedColor("Primary")!
    static let deltaPrimary = namedColor("DeltaPrimary")
    static let clipPrimary = namedColor("ClipPrimary")
    
    static let refreshRed = namedColor("RefreshRed")!
    static let refreshOrange = namedColor("RefreshOrange")!
    static let refreshYellow = namedColor("RefreshYellow")!
    static let refreshGreen = namedColor("RefreshGreen")!

    /// Dynamic so OLED mode resolves per trait collection rather than being baked in at
    /// launch. `static let` rather than a computed property so the identity is stable —
    /// `MiniStore.refreshBackgrounds` compares against it to find the views to repaint.
    static let altBackground = UIColor { traits in
        let background = namedColor("Background")!.resolvedColor(with: traits)

        #if WIDGET_EXTENSION
        return background
        #else
        guard traits.userInterfaceStyle == .dark, MiniStore.isOLEDModeEnabled else { return background }
        return .black
        #endif
    }

    /// Settings card background: a darkened version of the accent colour.
    ///
    /// Light mode keeps the translucent white the cells shipped with, because there the page
    /// behind them is still SideStore's purple — an accent-tinted card on an accent-tinted
    /// page has no contrast.
    static let altPurple = accentCard(brightnessScale: 0.65, fallbackWhite: 0.15)

    /// The pressed state of `altPurple`. Same hue, lifted enough to read as a highlight.
    static let altPurpleHighlighted = accentCard(brightnessScale: 0.95, fallbackWhite: 0.28)

    private static func accentCard(brightnessScale: CGFloat, fallbackWhite: CGFloat) -> UIColor {
        UIColor { traits in
            guard traits.userInterfaceStyle == .dark else { return UIColor.white.withAlphaComponent(0.25) }

            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
            guard UIColor.altPrimary.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil) else {
                return UIColor(white: fallbackWhite, alpha: 1)
            }

            return UIColor(hue: hue,
                           saturation: min(saturation * 0.90, 1),
                           brightness: min(brightness * brightnessScale, 1),
                           alpha: 1)
        }
    }

    /// Dark mode follows `altBackground` so the settings screens go pure black with the rest
    /// of the app in OLED mode. Light mode keeps the purple backdrop, because every label on
    /// these screens is hard-coded white and would vanish on a light page.
    ///
    /// `static let` for a stable identity: `MiniStore.refreshBackgrounds` finds the views to
    /// re-resolve by comparing against these instances.
    static let settingsBackground = UIColor { traits in
        guard traits.userInterfaceStyle == .dark else {
            return namedColor("SettingsBackground")!.resolvedColor(with: traits)
        }

        return altBackground.resolvedColor(with: traits)
    }

    static var settingsHighlighted: UIColor {
        return namedColor("SettingsHighlighted")!
    }

    static let altInvertedPrimary = namedColor("SettingsHighlighted")!
}

public extension UIColor
{
    private static let brightnessMaxThreshold = 0.85
    private static let brightnessMinThreshold = 0.35

    private static let saturationBrightnessThreshold = 0.5

    var adjustedForDisplay: UIColor {
        guard self.isTooBright || self.isTooDark else { return self }

        return UIColor { traits in
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            guard self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil) else { return self }

            brightness = min(brightness, UIColor.brightnessMaxThreshold)

            if traits.userInterfaceStyle == .dark
            {
                // Only raise brightness when in dark mode.
                brightness = max(brightness, UIColor.brightnessMinThreshold)
            }

            let color = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
            return color
        }
    }

    var isTooBright: Bool {
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0

        guard self.getHue(nil, saturation: &saturation, brightness: &brightness, alpha: nil) else { return false }

        let isTooBright = (brightness >= UIColor.brightnessMaxThreshold && saturation <= UIColor.saturationBrightnessThreshold)
        return isTooBright
    }

    var isTooDark: Bool {
        var brightness: CGFloat = 0
        guard self.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil) else { return false }

        let isTooDark = brightness <= UIColor.brightnessMinThreshold
        return isTooDark
    }
}
