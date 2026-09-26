//
//  MiniStore+Sources.swift
//  SideStore
//
//  Clears dead sources out of an upgrading install's database. Seeds nothing.
//

import CoreData
import Foundation

public extension MiniStore
{
    /// Feeds an upgrading install may still have in its database, matched against the
    /// normalized `Source.identifier` (lowercased, scheme stripped).
    ///
    /// Three kinds, none of which serve anything now:
    ///
    /// - SideStore's catalogue, seeded before this fork repointed `Source.altStoreSourceURL`.
    /// - Earlier MiniStore self-update feeds, which lived at several paths over time.
    /// - **Mini's Repo**, this fork's own catalogue. It was seeded on first launch until
    ///   2026-09-26, when the user retired the repo; the feed is dead, so every install that
    ///   ever launched an older build is carrying a source that 404s.
    ///
    /// A source that 404s is not merely inert: `FetchSourceOperation` decodes the whole
    /// response, so one source returning GitHub's error page fails the refresh — which is what
    /// empties the News tab.
    ///
    /// Prefixes rather than exact URLs, because the path varied. **They also match this fork's
    /// own live feed**, `the-big-mini.github.io/MiniStore/source.json`, and deliberately still
    /// do: an identifier already written into a user's database is not rewritten by anything
    /// that happens on the server side, so narrowing them would strand the records this exists
    /// to clear. The `altStoreIdentifier` guard in `removeLegacySideStoreSource` is therefore
    /// the only thing keeping this from deleting the app's own update source. Do not remove it.
    static let legacySourceIdentifierPrefixes = [
        "sidestore.io/apps-v2.json",
        "raw.githubusercontent.com/the-big-mini/ministore/",
        "the-big-mini.github.io/ministore/",

        // The feed's home before the repo was renamed `The-Big-Mini/SideStore` →
        // `The-Big-Mini/MiniStore`. Its path is `/sidestore/`, so none of the prefixes above
        // reach it, and it outlived every launch: a row still named "MiniStore" — that being
        // the feed's own `name` — sitting in Sources reporting "failed to load", while
        // self-updates went on working from the current feed's separate row.
        "the-big-mini.github.io/sidestore/",

        // Mini's Repo, retired 2026-09-26. Seeded into every install that launched a build
        // before then, so dropping the seeding alone would have left it behind — and left it
        // failing every source refresh.
        "oofmini.github.io/minis-repo/",
    ]
}

public extension MiniStore
{
    /// Called from `DatabaseManager.prepareDatabase`, inside its context and before its save.
    ///
    /// Seeds no catalogue. The fork ships **no default sources** — the Add Source screen's
    /// recommended list (`default-sources.json`, fetched by `UpdateKnownSourcesOperation`) is
    /// the only thing suggesting sources, and the user picks from it. The only row that appears
    /// unasked is the app's own update feed, `Source.altStoreSourceURL`.
    static func prepareDatabase(in context: NSManagedObjectContext)
    {
        Source.removeLegacySideStoreSource(in: context)
        self.renameSelfAppIfNeeded(in: context)
        self.detachOrphanedNewsBanners(in: context)
    }

    /// Clears `NewsItem.storeApp` wherever `appID` is gone.
    ///
    /// `NewsViewController` draws a whole app banner — icon, developer, OPEN button — under any
    /// item with a `storeApp`, which is what made every MiniStore release note read as MiniStore
    /// listing its own IPA. CI no longer publishes `appID`, and `Source.init(from:)` now clears
    /// the relationship when the key is absent, but neither reaches a row the feed has since
    /// scrolled past: those are never decoded again and keep whatever they were given.
    ///
    /// A `storeApp` without an `appID` is not a valid state in the first place, so this enforces
    /// the invariant rather than special-casing MiniStore's own feed.
    private static func detachOrphanedNewsBanners(in context: NSManagedObjectContext)
    {
        let predicate = NSPredicate(format: "%K == nil AND %K != nil",
                                    #keyPath(NewsItem.appID),
                                    #keyPath(NewsItem.storeApp))

        for newsItem in NewsItem.all(satisfying: predicate, in: context)
        {
            debugLog("[MiniStore] Detaching the app banner from news item \(newsItem.identifier).")
            newsItem.storeApp = nil
        }
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
}
