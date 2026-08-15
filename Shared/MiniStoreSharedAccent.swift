//
//  MiniStoreSharedAccent.swift
//  SideStore
//
//  The accent colour, shared from the app to the widget extension.
//

@preconcurrency import UIKit

/// The user's accent colour, mirrored into the app group so `AltWidget` can tint itself with it.
///
/// `ThemeManager` is in the app target only, so the widget cannot ask it directly — this store is
/// the whole interface between them. Components rather than the hex string `ThemeManager`
/// persists for itself, because `UIColor(hex:)` is also app-target-only and the widget would have
/// nothing to parse it with.
public enum MiniStoreSharedAccent
{
    private static let key = "MiniStoreAccentRGBA"

    private static var sharedDefaults: UserDefaults? {
        guard let appGroup = Bundle.main.altstoreAppGroup else { return nil }
        return UserDefaults(suiteName: appGroup)
    }

    /// `nil` when the user has never picked a colour, or when this bundle has no app group —
    /// callers fall back to `UIColor.defaultAltPrimary`.
    public static var color: UIColor? {
        get
        {
            guard let components = self.sharedDefaults?.array(forKey: self.key) as? [Double], components.count == 4 else { return nil }
            return UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3])
        }
        set
        {
            guard let sharedDefaults = self.sharedDefaults else { return }

            guard let newValue else { return sharedDefaults.removeObject(forKey: self.key) }

            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard newValue.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return }

            sharedDefaults.set([Double(red), Double(green), Double(blue), Double(alpha)], forKey: self.key)
        }
    }
}
