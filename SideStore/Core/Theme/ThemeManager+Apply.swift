//
//  ThemeManager+Apply.swift
//  SideStore
//
//  Pushes the selected accent colour into the live UIKit hierarchy.
//

@preconcurrency import UIKit
import WidgetKit

public extension ThemeManager
{
    /// Everything a colour change reaches beyond `primaryColor` itself, run once the colour
    /// stops changing. A ColorPicker drag sets it on every tick, and each pass reloads the
    /// widget's timelines — which WidgetKit budgets — and `reloadData()`s every loaded table
    /// and collection view. Needs proper testing on a device: the drag itself is unmeasured.
    func scheduleThemeChange()
    {
        Self.pendingThemeChange?.cancel()
        Self.pendingThemeChange = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            let themeManager = ThemeManager.shared
            let color = themeManager.primaryColor

            // The widget runs in its own process and cannot see UserDefaults.standard, so the
            // colour is mirrored into the app group and the timeline reloaded to pick it up.
            MiniStoreSharedAccent.color = color
            WidgetCenter.shared.reloadAllTimelines()

            NotificationCenter.default.post(name: ThemeManager.themeDidChangeNotification, object: color)
            themeManager.applyToVisibleUI()
        }
    }

    /// Re-applies `primaryColor` to the UIKit screens that are already on-screen.
    ///
    /// `UIColor.altPrimary` resolves to `primaryColor`, so every call site picks up a new
    /// theme by itself — but only the *next* time it runs. Setting the window's tint is not
    /// enough to cover the rest, for two separate reasons:
    ///
    /// - Some view controllers assign a `tintColor` of their own — `SourcesViewController` to
    ///   its navigation controller's view, `FeaturedViewController` to its navigation bar. An
    ///   explicit tint beats an inherited one, so each blocks the window's colour from reaching
    ///   everything beneath it. (The storyboard-wide `Primary` tint that did the same for the
    ///   whole tab bar was deleted from `Main.storyboard` and `Authentication.storyboard`; it
    ///   is why "Refresh All" kept the old accent.)
    /// - Collection and table views colour their cells at dequeue and cache the result, so
    ///   they have to re-run that pass.
    ///
    /// Deliberately walks the view *controller* tree rather than every `UIView`: cells set
    /// their own tint from a source's or app's brand colour (`app.tintColor ?? .altPrimary`),
    /// and blanket-assigning the accent to every view would overwrite those.
    func applyToVisibleUI()
    {
        let color = self.primaryColor

        let windows = (UIApplication.alt_shared?.connectedScenes ?? [])
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        for window in windows
        {
            window.tintColor = color

            if let rootViewController = window.rootViewController
            {
                ThemeManager.retint(rootViewController, with: color)
            }
        }

        // Switched-off tabs are out of the tree walked above, and would come back with the tint
        // `retint` gave them last time. `assumeIsolated` because `TabBarController` is main-actor
        // isolated and this is not; both callers are on the main thread.
        let hidden = MainActor.assumeIsolated { MiniStore.tabBarController()?.hiddenViewControllers ?? [] }
        for viewController in hidden
        {
            ThemeManager.retint(viewController, with: color)
        }
    }
}

private extension ThemeManager
{
    nonisolated(unsafe) static var pendingThemeChange: Task<Void, Never>?

    static func retint(_ viewController: UIViewController, with color: UIColor)
    {
        // `viewIfLoaded` so this never forces a tab the user has not opened to load early —
        // it reads the current colour for itself when it eventually does.
        if let view = viewController.viewIfLoaded
        {
            view.tintColor = color
            reloadDataViews(in: view)
        }

        switch viewController
        {
        case let navigationController as UINavigationController: navigationController.navigationBar.tintColor = color
        case let tabBarController as UITabBarController: tabBarController.tabBar.tintColor = color
        default: break
        }

        for child in viewController.children
        {
            retint(child, with: color)
        }

        if let presented = viewController.presentedViewController
        {
            retint(presented, with: color)
        }
    }

    static func reloadDataViews(in view: UIView)
    {
        switch view
        {
        // Stop here rather than recursing into the cells this is about to rebuild.
        case let collectionView as UICollectionView: collectionView.reloadData()
        case let tableView as UITableView: tableView.reloadData()

        default:
            for subview in view.subviews
            {
                reloadDataViews(in: subview)
            }
        }
    }
}
