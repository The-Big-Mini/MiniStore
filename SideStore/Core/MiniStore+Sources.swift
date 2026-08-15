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

    /// Sources left behind in databases this build inherits, matched against the normalized
    /// `Source.identifier` (lowercased, scheme stripped).
    ///
    /// Two generations of dead feed:
    ///
    /// - SideStore's catalogue, seeded before the fork repointed `Source.altStoreSourceURL`.
    /// - The old MiniStore hard fork's `side.json` / `sidenightly.json` self-update feeds.
    ///   That repo is dead and serves nothing, so the source sits there listing no apps and
    ///   failing every refresh — which is also what breaks the News tab, since one source
    ///   returning GitHub's 404 page fails the whole decode.
    ///
    /// Prefixes rather than exact URLs because the dead repo served several feeds, and the
    /// branch in the path changed over time.
    ///
    /// **These prefixes now collide with this fork's own feed.** The repos were renamed on
    /// 2026-08-15: the fork became `The-Big-Mini/MiniStore` and the dead hard fork became
    /// `The-Big-Mini/MiniStore-Dead`. The prefixes still say `/ministore/` — correctly, because
    /// they match identifiers already written into users' databases, which a repo rename does
    /// not rewrite. But the live feed is now `the-big-mini.github.io/MiniStore/source.json`,
    /// which matches too. The `altStoreIdentifier` guard in `removeLegacySideStoreSource` is
    /// the only thing stopping this from deleting the app's own update source. Do not remove it.
    static let legacySourceIdentifierPrefixes = [
        "sidestore.io/apps-v2.json",
        "raw.githubusercontent.com/the-big-mini/ministore/",
        "the-big-mini.github.io/ministore/",
    ]

    /// Set once Mini's Repo has been seeded, so removing it sticks. An existence check
    /// instead would re-add the source on the next launch and make it undeletable.
    fileprivate static let didSeedCatalogueKey = "MiniStoreDidSeedCatalogueSource"
}

public extension MiniStore
{
    /// Called from `DatabaseManager.prepareDatabase`, inside its context and before its save.
    static func prepareDatabase(in context: NSManagedObjectContext)
    {
        Source.removeLegacySideStoreSource(in: context)
        Source.seedCatalogueSourceIfNeeded(in: context)
        self.renameSelfAppIfNeeded(in: context)
    }

    /// `InstalledApp.update` only runs when the app is installed or refreshed, so a database
    /// carried over from an earlier build keeps whatever name it was given then — which is
    /// what My Apps shows.
    private static func renameSelfAppIfNeeded(in context: NSManagedObjectContext)
    {
        guard let installedApp = InstalledApp.fetchAltStore(in: context) else { return }
        guard installedApp.name != MiniStore.displayName else { return }

        debugLog("[MiniStore] Renaming the installed app record from \(installedApp.name).")
        installedApp.name = MiniStore.displayName
    }
}

extension Source
{

    static func seedCatalogueSourceIfNeeded(in context: NSManagedObjectContext)
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

    static func removeLegacySideStoreSource(in context: NSManagedObjectContext)
    {
        let predicates = MiniStore.legacySourceIdentifierPrefixes.map {
            NSPredicate(format: "%K BEGINSWITH %@", #keyPath(Source.identifier), $0)
        }
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

        for source in Source.all(satisfying: predicate, in: context)
        {
            // Guard against the fork ever pointing its own feed at one of these.
            guard source.identifier != Source.altStoreIdentifier else { continue }

            debugLog("[MiniStore] Removing dead source \(source.identifier).")
            context.delete(source)
        }
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
