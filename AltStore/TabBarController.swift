//
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

extension TabBarController
{
    private enum Tab: Int, CaseIterable
    {
        case news
        case sources
        case browse
        case myApps
        case settings
    }
}

final class TabBarController: UITabBarController
{
    private var initialSegue: (identifier: String, sender: Any?)?
    
    private var _viewDidAppear = false
    
    private var sourcesViewController: SourcesViewController!

    /// Every tab the storyboard defines, including the ones the user has switched off.
    /// `viewControllers` holds only the visible subset, so `Tab.rawValue` indexes this.
    private(set) var allViewControllers: [UIViewController] = []

    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.importApp(_:)), name: AppDelegate.importAppDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.presentSources(_:)), name: AppDelegate.addSourceDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
    }
    
    override func viewDidLoad() 
    {
        super.viewDidLoad()
        debugLog("[TabBarController] viewDidLoad()")
        
        self.allViewControllers = self.viewControllers ?? []

        let browseNavigationController = self.allViewControllers[Tab.browse.rawValue] as! UINavigationController
        browseNavigationController.tabBarItem.image = UIImage(systemName: "bag")

        let sourcesNavigationController = self.allViewControllers[Tab.sources.rawValue] as! UINavigationController
        self.sourcesViewController = sourcesNavigationController.viewControllers.first as? SourcesViewController

        self.applyHiddenTabs()
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.applyHiddenTabs), name: MiniStore.hiddenTabsDidChangeNotification, object: nil)

        // Only on first load, so switching tabs and coming back doesn't yank the user away.
        let defaultTab = MiniStore.defaultTab
        if self.allViewControllers.indices.contains(defaultTab),
           let index = self.viewControllers?.firstIndex(of: self.allViewControllers[defaultTab])
        {
            self.selectedIndex = index
        }
    }

    @objc func applyHiddenTabs()
    {
        let hidden = MiniStore.hiddenTabs
        let visible = self.allViewControllers.enumerated().filter { !hidden.contains($0.offset) }.map(\.element)

        // An empty tab bar would strand the user with no way back to Settings.
        self.viewControllers = visible.isEmpty ? self.allViewControllers : visible
    }

    /// Selects a tab by its storyboard position, which is not its position in the tab bar
    /// once tabs are hidden. Unhides the tab if it is switched off, because the callers are
    /// deep links and error-log taps — silently doing nothing would look like a broken link.
    private func select(_ tab: Tab)
    {
        guard self.allViewControllers.indices.contains(tab.rawValue) else { return }
        let viewController = self.allViewControllers[tab.rawValue]

        if self.viewControllers?.contains(viewController) != true
        {
            debugLog("[TabBarController] Unhiding tab \(tab.rawValue) so it can be selected.")
            MiniStore.hiddenTabs.remove(tab.rawValue)
        }

        guard let index = self.viewControllers?.firstIndex(of: viewController) else { return }
        self.selectedIndex = index
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        debugLog("[TabBarController] viewDidAppear() — TabBarController is now visible")
        
        _viewDidAppear = true
        
        if let (identifier, sender) = self.initialSegue
        {
            self.initialSegue = nil
            self.performSegue(withIdentifier: identifier, sender: sender)
        }
    }
    
    override func performSegue(withIdentifier identifier: String, sender: Any?)
    {
        guard _viewDidAppear else {
            self.initialSegue = (identifier, sender)
            return
        }
        
        super.performSegue(withIdentifier: identifier, sender: sender)
    }
}

extension TabBarController
{
    @objc func presentSources(_ sender: Any)
    {
        if let presentedViewController = self.presentedViewController
        {
            presentedViewController.dismiss(animated: true) {
                self.presentSources(sender)
            }
            
            return
        }
                
        if let notification = (sender as? Notification), let sourceURL = notification.userInfo?[AppDelegate.addSourceDeepLinkURLKey] as? URL
        {
            self.sourcesViewController?.deepLinkSourceURL = sourceURL
        }
        
        self.select(.sources)
    }
}

private extension TabBarController
{
    @objc func importApp(_ notification: Notification)
    {
        self.select(.myApps)
    }

    @objc func openErrorLog(_ notification: Notification)
    {
        self.select(.settings)
    }
}
