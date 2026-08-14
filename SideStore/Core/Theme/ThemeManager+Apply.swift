//
//  ThemeManager+Apply.swift
//  SideStore
//
//  Pushes the selected accent colour into the live UIKit hierarchy.
//

@preconcurrency import UIKit

public extension ThemeManager
{
    /// Re-applies `primaryColor` to the UIKit screens that are already on-screen.
    ///
    /// `UIColor.altPrimary` resolves to `primaryColor`, so every call site picks up a new
    /// theme by itself — but only the *next* time it runs. Setting the window's tint is not
    /// enough to cover the rest, for two separate reasons:
    ///
    /// - Several view controllers own an explicitly assigned `tintColor`: `Main.storyboard`
    ///   sets a scene-level tint on the tab bar controller's view, and `SourcesViewController`
    ///   and `FeaturedViewController` assign one to their navigation controller's view. An
    ///   explicit tint beats an inherited one, so any of these blocks the window's colour from
    ///   reaching everything beneath it — which is why controls that take their colour from
    ///   the inherited tint, like the "Refresh All" button, kept the old accent.
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
    }
}

private extension ThemeManager
{
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
