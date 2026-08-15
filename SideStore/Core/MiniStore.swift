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
    /// The name shown to the user: My Apps, the store listing for the app itself, settings.
    ///
    /// Deliberately *not* the value of `CFBundleDisplayName` in `Info.plist`. That key has to
    /// keep reading "SideStore": iLoader and `idevice_pair` identify sideloaders by matching
    /// the raw `CFBundleDisplayName` that `installation_proxy` reports against a hardcoded
    /// list, with no bundle-identifier fallback. The Home Screen name is overridden
    /// separately and non-destructively, in `AltStore/en.lproj/InfoPlist.strings`.
    public static let displayName = "MiniStore"
}
