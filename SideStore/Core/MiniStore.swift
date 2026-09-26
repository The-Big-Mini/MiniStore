//
//  MiniStore.swift
//  SideStore
//
//  Fork identity, kept in one place so the rename never has to be chased through
//  scattered string literals.
//

import Foundation

public enum MiniStore
{
    /// The name shown wherever the app draws it itself: My Apps, its own store listing, the
    /// splash screen.
    ///
    /// Deliberately *not* `CFBundleDisplayName`, which has to read "SideStore" — and so does
    /// the Home Screen label. iLoader and `idevice_pair` find sideloaders by matching the
    /// display name `installation_proxy` reports against a hardcoded list, with no
    /// bundle-identifier fallback, and that report is the *localized* name SpringBoard shows.
    /// A localized override was tried and hid the app from iLoader (fb9d5ddb); see the note
    /// in `AltStore/en.lproj/InfoPlist.strings`.
    public static let displayName = "MiniStore"
}
