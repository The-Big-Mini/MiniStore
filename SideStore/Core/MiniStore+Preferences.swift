//
//  MiniStore+Preferences.swift
//  SideStore
//
//  Display preferences the fork adds on top of SideStore's own settings.
//

@preconcurrency import UIKit

public extension MiniStore
{
    static let oledModeDidChangeNotification = Notification.Name("MiniStoreOLEDModeDidChangeNotification")
    static let hiddenTabsDidChangeNotification = Notification.Name("MiniStoreHiddenTabsDidChangeNotification")

    private static let oledModeKey = "MiniStoreOLEDModeEnabled"
    private static let hiddenTabsKey = "MiniStoreHiddenTabs"
    private static let defaultTabKey = "MiniStoreDefaultTab"

    /// The tab the app opens on, as an index into the storyboard's tab order.
    ///
    /// Unset means "whatever the storyboard selects", which is why this is not simply
    /// defaulted to 0 — a stored 0 and an absent value would otherwise be the same thing.
    static var defaultTab: Int {
        get { UserDefaults.standard.object(forKey: defaultTabKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: defaultTabKey) }
    }

    /// The app's tab bar controller, wherever it currently sits.
    ///
    /// It is not the window's root — the launch controller is, and it swaps the tab bar in
    /// underneath itself once the database is ready.
    internal static func tabBarController() -> TabBarController? {
        let roots = (UIApplication.alt_shared?.connectedScenes ?? [])
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .compactMap { $0.rootViewController }

        return roots.lazy.compactMap { search($0) }.first
    }

    private static func search(_ viewController: UIViewController) -> TabBarController? {
        if let tabBarController = viewController as? TabBarController { return tabBarController }

        for child in viewController.children {
            if let found = search(child) { return found }
        }

        if let presented = viewController.presentedViewController { return search(presented) }
        return nil
    }

    /// Paints dark mode pure black. Read from inside `UIColor.altBackground`'s resolver, so
    /// every screen that uses that colour follows without knowing this setting exists.
    static var isOLEDModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: oledModeKey) }
        set {
            let wasEnabled = self.isOLEDModeEnabled
            guard newValue != wasEnabled else { return }

            UserDefaults.standard.set(newValue, forKey: oledModeKey)
            self.refreshBackgrounds(wasEnabled: wasEnabled)
            NotificationCenter.default.post(name: oledModeDidChangeNotification, object: newValue)
        }
    }

    /// Tabs the user has switched off, as indices into the storyboard's tab order.
    ///
    /// Indices rather than the `Tab` enum because they are persisted: a name is free to
    /// change, and upstream inserting a tab would silently reinterpret saved values either
    /// way — so this keeps the cheaper representation.
    static var hiddenTabs: Set<Int> {
        get { Set(UserDefaults.standard.array(forKey: hiddenTabsKey) as? [Int] ?? []) }
        set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: hiddenTabsKey)
            NotificationCenter.default.post(name: hiddenTabsDidChangeNotification, object: nil)
        }
    }
}

private extension MiniStore
{
    /// Repaints the screens already on-screen when OLED mode is toggled.
    ///
    /// `UIColor.altBackground` is dynamic, so it resolves correctly on its own the next time
    /// UIKit asks — but a `UserDefaults` change is not a trait change, so nothing asks.
    /// Re-assigning the colour forces the resolve.
    ///
    /// Matching on the *resolved* colour rather than the dynamic one is deliberate: the
    /// dozen call sites assign `.altBackground` and UIKit hands back the resolved value, so
    /// identity comparison would never match. The previous state tells us which value to
    /// look for, which keeps this from repainting views that are merely black by coincidence.
    static func refreshBackgrounds(wasEnabled: Bool)
    {
        let windows = (UIApplication.alt_shared?.connectedScenes ?? [])
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        for window in windows
        {
            let traits = window.traitCollection
            guard traits.userInterfaceStyle == .dark else { continue }

            // Turning OLED on replaces the Background asset; turning it off replaces black.
            let previous = wasEnabled ? UIColor.black : UIColor(named: "Background", in: .main, compatibleWith: traits)
            guard let previous else { continue }

            self.repaint(window, matching: previous.resolvedColor(with: traits), traits: traits)
        }
    }

    static func repaint(_ view: UIView, matching previous: UIColor, traits: UITraitCollection)
    {
        if let current = view.backgroundColor?.resolvedColor(with: traits), current == previous
        {
            view.backgroundColor = .altBackground
        }

        for subview in view.subviews
        {
            self.repaint(subview, matching: previous, traits: traits)
        }
    }
}
