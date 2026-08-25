//
//  MiniStore+AppIconPicker.swift
//  SideStore
//
//  Hosts the UIKit alternate-icon grid inside SwiftUI, so User Customizations can own it.
//

import SwiftUI
import UIKit

/// `AltAppIconsViewController` in a form `NavigationLink` can push.
///
/// The controller builds its own compositional layout, cell registrations, data source and title
/// in `viewDidLoad`, and reads its icons straight out of `AltIcons.plist`. It never needed
/// anything from the storyboard scene it used to be reached through — which is what let the
/// `display` settings section, its cell and its segue be removed outright rather than hidden.
struct AppIconPickerView: UIViewControllerRepresentable
{
    func makeUIViewController(context: Context) -> AltAppIconsViewController
    {
        // The layout passed here is replaced by the controller's own in `viewDidLoad`; it exists
        // only because `UICollectionViewController` has no initialiser without one.
        AltAppIconsViewController(collectionViewLayout: UICollectionViewFlowLayout())
    }

    func updateUIViewController(_ controller: AltAppIconsViewController, context: Context) {}
}
