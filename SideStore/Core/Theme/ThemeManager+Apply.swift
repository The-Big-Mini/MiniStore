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
    /// `UIColor.altPrimary` resolves to `primaryColor`, so every call site picks up the new
    /// theme by itself — but only the *next* time it runs. Two kinds of view keep the stale
    /// colour until something rebuilds them, and this closes both:
    ///
    /// - Navigation bars and tab bars, because `Main.storyboard` and
    ///   `Authentication.storyboard` bake the `Primary` colorset straight in. An explicitly
    ///   assigned `tintColor` beats the window's inherited one, so setting the window alone
    ///   leaves them purple.
    /// - Collection and table views, because their cells read `.altPrimary` at dequeue time
    ///   and cache the result in a background or title colour.
    func applyToVisibleUI()
    {
        let color = self.primaryColor

        let windows = (UIApplication.alt_shared?.connectedScenes ?? [])
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        for window in windows
        {
            window.tintColor = color
            ThemeManager.retint(window, with: color)
        }
    }
}

private extension ThemeManager
{
    static func retint(_ view: UIView, with color: UIColor)
    {
        switch view
        {
        case let navigationBar as UINavigationBar: navigationBar.tintColor = color
        case let tabBar as UITabBar: tabBar.tintColor = color
        case let collectionView as UICollectionView: collectionView.reloadData()
        case let tableView as UITableView: tableView.reloadData()
        default: break
        }

        for subview in view.subviews
        {
            retint(subview, with: color)
        }
    }
}
