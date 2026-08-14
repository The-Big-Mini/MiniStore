//
//  MiniStore+Sources.swift
//  SideStore
//
//  Seeds Mini's Repo as the catalogue source and clears out SideStore's.
//

import CoreData
import Foundation

public extension MiniStore
{
    /// The catalogue seeded on first launch.
    ///
    /// Deliberately separate from `Source.altStoreSourceURL`, which is this app's own update
    /// feed and carries no third-party apps.
    static let catalogueSourceURL = URL(string: "https://OofMini.github.io/Minis-Repo/mini.json")!
    static let catalogueSourceName = "Mini's Repo"

    /// SideStore's catalogue, seeded by builds made before the fork repointed
    /// `Source.altStoreSourceURL`. Still sitting in those databases, listing nothing.
    static let legacySideStoreSourceURL = URL(string: "https://sidestore.io/apps-v2.json/")!

    /// Set once Mini's Repo has been seeded, so removing it sticks. An existence check
    /// instead would re-add the source on the next launch and make it undeletable.
    fileprivate static let didSeedCatalogueKey = "MiniStoreDidSeedCatalogueSource"
}

extension Source
{
    /// Adds Mini's Repo, and drops the SideStore catalogue an earlier build left behind.
    ///
    /// Called from `DatabaseManager.prepareDatabase` inside its context, before its save.
    static func prepareMiniStoreSources(in context: NSManagedObjectContext)
    {
        self.removeLegacySideStoreSource(in: context)
        self.seedCatalogueSourceIfNeeded(in: context)
    }

    private static func seedCatalogueSourceIfNeeded(in context: NSManagedObjectContext)
    {
        guard !UserDefaults.standard.bool(forKey: MiniStore.didSeedCatalogueKey) else { return }

        guard let identifier = self.sourceID(for: MiniStore.catalogueSourceURL) else { return }

        let predicate = NSPredicate(format: "%K == %@", #keyPath(Source.identifier), identifier)
        if Source.first(satisfying: predicate, in: context) == nil
        {
            // Apps stay empty until the next source refresh — `AppManager.fetchSources()`
            // walks every Source row, so this one gets populated with the rest.
            _ = Source.make(name: MiniStore.catalogueSourceName,
                            groupID: Source.altStoreGroupIdentifier,
                            sourceURL: MiniStore.catalogueSourceURL,
                            context: context)
        }

        UserDefaults.standard.set(true, forKey: MiniStore.didSeedCatalogueKey)
    }

    private static func removeLegacySideStoreSource(in context: NSManagedObjectContext)
    {
        guard let identifier = self.sourceID(for: MiniStore.legacySideStoreSourceURL) else { return }

        // Guard against the fork ever pointing its own feed back at that URL.
        guard identifier != Source.altStoreIdentifier else { return }

        let predicate = NSPredicate(format: "%K == %@", #keyPath(Source.identifier), identifier)
        guard let source = Source.first(satisfying: predicate, in: context) else { return }

        context.delete(source)
    }

    private static func sourceID(for sourceURL: URL) -> String?
    {
        do
        {
            return try Source.sourceID(from: sourceURL)
        }
        catch
        {
            debugLog("[MiniStore] Could not derive a source ID for \(sourceURL). [\(error._domain) \(error._code)] \(error.localizedDescription)")
            return nil
        }
    }
}
