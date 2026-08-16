//
//  MiniStore+Appearance.swift
//  SideStore
//
//  Chrome shared by the fork's restyled settings screens.
//

@preconcurrency import UIKit
import SwiftUI

public extension MiniStore
{
    /// A 28×28 rounded colour tile with a centred SF Symbol, as used down the left edge of
    /// the settings rows.
    ///
    /// Rendered rather than composed out of views so it can be handed to `UIImageView` and to
    /// SwiftUI's `Image(uiImage:)` unchanged, and so the tile is one layer instead of two.
    static func settingsIcon(_ systemName: String, color: UIColor) -> UIImage
    {
        let size = CGSize(width: 28, height: 28)
        let configuration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let symbol = UIImage(systemName: systemName, withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)

        if symbol == nil
        {
            debugLog("[MiniStore] No SF Symbol named \(systemName); drawing a bare tile.")
        }

        return UIGraphicsImageRenderer(size: size).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6).fill()

            guard let symbol else { return }
            symbol.draw(at: CGPoint(x: (size.width - symbol.size.width) / 2,
                                    y: (size.height - symbol.size.height) / 2))
        }
    }
}

public extension MiniStore
{
    /// The bar appearance for plain UIKit and SwiftUI screens pushed out of Settings — health
    /// check, connection config, certificate detail — which have no appearance of their own and
    /// would otherwise render a dark title on a dark bar under iOS 26.
    ///
    /// A per-item appearance rather than one written to `navigationController.navigationBar`.
    /// The bar is shared by the whole stack, and a write to it lands while UIKit is still
    /// interpolating the bar's metrics: the header then held the *outgoing* screen's height for
    /// the entire pop and snapped to the right one 28 frames later. UIKit cross-fades
    /// `navigationItem` appearances between view controllers, so each screen can differ without
    /// any screen touching the shared bar.
    static var pushedScreenBarAppearance: UINavigationBarAppearance
    {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        return appearance
    }

    /// The static `Background` colour asset, held once so views painted with it can be found.
    private static let staticBackground = UIColor(named: "Background", in: .main, compatibleWith: nil)

    /// Repaints anything still carrying the static `Background` asset with `altBackground`.
    ///
    /// `Main.storyboard` paints twelve views with the raw asset. It has no OLED variant, so
    /// those screens stay `#1C1C1E` with OLED mode on — most visibly the app detail screen,
    /// whose table, cells and stack views are all painted that way. Swapping in the dynamic
    /// colour also gives `MiniStore.refreshBackgrounds` an instance it can match by identity,
    /// so a later toggle repaints them too.
    static func adoptDynamicBackground(in view: UIView)
    {
        guard let asset = self.staticBackground else { return }

        if let current = view.backgroundColor, current.isEqual(asset)
        {
            view.backgroundColor = .altBackground
        }

        for subview in view.subviews
        {
            self.adoptDynamicBackground(in: subview)
        }
    }
}

public extension View
{
    /// Paints a settings screen with the app background and repaints it live when OLED mode
    /// or the accent colour changes.
    ///
    /// `Color(uiColor:)` snapshots the resolved colour, and neither of those settings is a
    /// trait change, so without this the screen keeps the old colour until it is rebuilt.
    func miniStoreBackground() -> some View
    {
        self.modifier(MiniStoreBackground())
    }
}

private struct MiniStoreBackground: ViewModifier
{
    @State private var generation = 0

    func body(content: Content) -> some View
    {
        content
            // The generation identifies only the background layer, so bumping it re-resolves
            // the colour without discarding the screen's own state or scroll position.
            .background(Color(uiColor: .settingsBackground).id(generation).ignoresSafeArea())
            .onReceive(NotificationCenter.default.publisher(for: MiniStore.oledModeDidChangeNotification)) { _ in
                generation += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: ThemeManager.themeDidChangeNotification)) { _ in
                generation += 1
            }
    }
}

public extension Color
{
    /// The settings card, matching the UIKit `InsetGroupTableViewCell` fill. Unlike the page
    /// background this does not follow OLED mode, so it needs no live refresh.
    static var miniStoreCard: Color { Color(uiColor: .altPurple) }

    /// Hairline between rows inside a card.
    static var miniStoreSeparator: Color { Color.white.opacity(0.25) }
}
