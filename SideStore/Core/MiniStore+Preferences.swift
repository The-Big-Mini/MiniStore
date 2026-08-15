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

    /// Posted when the tab bar's contents *or* their order changes. One notification for both,
    /// because the observer rebuilds the whole bar either way.
    static let tabLayoutDidChangeNotification = Notification.Name("MiniStoreTabLayoutDidChangeNotification")

    private static let oledModeKey = "MiniStoreOLEDModeEnabled"
    private static let hiddenTabsKey = "MiniStoreHiddenTabs"
    private static let tabOrderKey = "MiniStoreTabOrder"
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
            self.refreshBackgrounds()
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
            self.postTabLayoutDidChange()
        }
    }

    /// The tab bar's display order, as indices into the storyboard's tab order.
    ///
    /// Stored raw and repaired on read by `resolvedTabOrder(count:)` rather than validated here,
    /// so that a saved order never has to be migrated when upstream adds or removes a tab.
    static var tabOrder: [Int] {
        get { UserDefaults.standard.array(forKey: tabOrderKey) as? [Int] ?? [] }
        set {
            UserDefaults.standard.set(newValue, forKey: tabOrderKey)
            self.postTabLayoutDidChange()
        }
    }

    /// The stored order made safe to index `allViewControllers` with.
    ///
    /// Upstream is free to add or remove a tab between releases, and a saved order from before
    /// that change must neither drop the new tab nor resurrect a departed one. Out-of-range and
    /// duplicate entries are discarded, then anything missing is appended in storyboard order —
    /// so an unset order, a stale order and a corrupt one all resolve to something complete.
    static func resolvedTabOrder(count: Int) -> [Int] {
        var seen = Set<Int>()
        var order = self.tabOrder.filter { (0..<count).contains($0) && seen.insert($0).inserted }

        order += (0..<count).filter { !seen.contains($0) }
        return order
    }

    /// Deferred by one turn of the run loop. These setters are called from inside a SwiftUI
    /// state mutation, and the observer rebuilds `UITabBarController.viewControllers` — tearing
    /// down and re-adding the very view hierarchy that is mid-update.
    private static func postTabLayoutDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: tabLayoutDidChangeNotification, object: nil)
        }
    }
}

private extension MiniStore
{
    /// The fork's dynamic colours, held by identity so a view painted with one can be found
    /// again. All are `static let`, so every screen that uses them holds this same instance.
    static let dynamicColors: [UIColor] = [.altBackground, .settingsBackground, .altPurple, .altPurpleHighlighted]

    /// Repaints the screens already on-screen when OLED mode is toggled.
    ///
    /// These colours resolve OLED mode correctly on their own the next time UIKit asks — but
    /// a `UserDefaults` change is not a trait change, so nothing asks, and UIKit keeps
    /// serving the CGColor it cached. Clearing the property and setting it back re-runs the
    /// resolver against the view's current traits.
    static func refreshBackgrounds()
    {
        let windows = (UIApplication.alt_shared?.connectedScenes ?? [])
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        for window in windows
        {
            self.repaint(window)
        }
    }

    static func repaint(_ view: UIView)
    {
        if let current = view.backgroundColor, self.dynamicColors.contains(where: { $0 === current })
        {
            view.backgroundColor = nil
            view.backgroundColor = current
        }

        for subview in view.subviews
        {
            self.repaint(subview)
        }
    }
}
