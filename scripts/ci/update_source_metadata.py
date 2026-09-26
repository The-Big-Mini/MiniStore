#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
TEMPLATE_FILE = SCRIPT_DIR / "source-template.json"


# ----------------------------------------------------------
# metadata
# ----------------------------------------------------------

def load_metadata(metadata_file: Path):
    if not metadata_file.exists():
        raise SystemExit(f"Missing metadata file: {metadata_file}")

    with open(metadata_file, "r", encoding="utf-8") as f:
        meta = json.load(f)

    print("  ====> Required parameter list <====")
    for k, v in meta.items():
        print(f"{k}: {v}")

    required = [
        "bundle_identifier",
        "version_ipa",
        "version_date",
        "release_channel",
        "size",
        "sha256",
        "localized_description",
        "download_url",
    ]

    for r in required:
        if not meta.get(r):
            raise SystemExit("One or more required metadata fields missing")

    meta["size"] = int(meta["size"])
    meta["release_channel"] = meta["release_channel"].lower()

    return meta


# ----------------------------------------------------------
# source loading
# ----------------------------------------------------------

def load_source(source_file: Path):
    if source_file.exists():
        with open(source_file, "r", encoding="utf-8") as f:
            data = json.load(f)
    else:
        print("source.json missing — creating minimal structure")
        data = {"version": 2, "apps": []}

    if int(data.get("version", 1)) < 2:
        raise SystemExit("Only v2 and above are supported")

    return data


# ----------------------------------------------------------
# locate app
# ----------------------------------------------------------

def ensure_app(data, bundle_id):
    apps = data.setdefault("apps", [])

    app = next(
        (a for a in apps if a.get("bundleIdentifier") == bundle_id),
        None,
    )

    if app is None:
        print("App entry missing — creating new app entry")
        app = {
            "bundleIdentifier": bundle_id,
            "releaseChannels": [],
        }
        apps.append(app)

    return app


# ----------------------------------------------------------
# update storefront
# ----------------------------------------------------------

def update_storefront(app, meta):
    """The legacy top-level release block: the stable track's head release, or this run's.

    Run after update_release_channel, and taken from the stable track whenever the feed has
    one, so it no longer belongs to whichever channel deployed last. Written from this run's
    metadata every time, a nightly landing after a stable tag re-pointed it at the nightly
    IPA: on 2026-09-26 the published feed's top-level `version` was
    `0.7.3-20260926.88+fae30b3b` while its stable track said `0.7.3`. MiniStore reads the
    tracks first and never noticed; anything reading these AltStore-format fields — older
    clients, Feather, source viewers — was offered the nightly as the release. Tag-after-
    nightly sequencing hid it for 0.7.2 and 0.7.3, and the next nightly undid it anyway.

    Only a feed with no stable track falls back to this run, and it has to — see below.

    StoreApp.decodeVersions resolves versions as
    `getReleases(default: stableTrack) ?? versions ?? createNewAppVersion(decoder:)`.
    On a nightly-only feed the first two are empty — there is no "stable" track, and
    `betaReleases` bails at StoreApp.swift:120 because it needs a stable release to
    compare the beta against — so it falls through to createNewAppVersion, which decodes
    version/versionDate/downloadURL/size *non-optionally* (StoreApp.swift:504-509).
    Gating these fields on stable therefore made every nightly feed throw during decode:
    the source appeared in Sources and never loaded, taking the news items with it.

    `versionDescription`, not `localizedDescription`, is the release notes. createNewAppVersion
    reads the changelog from `versionDescription` (StoreApp.swift:506) and passes it through as
    the AppVersion's localizedDescription; `localizedDescription` at this level is the store
    page blurb, decoded non-optionally by StoreApp.init(from:) and authored in the template.

    Writing the notes into the wrong one of those cost both: the update card in My Apps read
    `latestSupportedVersion.localizedDescription ?? "nil"` and printed a literal **nil**, while
    the store page showed the release notes where its description belongs. `localizedDescription`
    is therefore left to apply_template, which runs first.
    """
    stable = next(
        (t["releases"][0] for t in app.get("releaseChannels", [])
         if isinstance(t, dict) and t.get("track") == "stable" and t.get("releases")),
        None,
    )

    # Keyed like a track release (update_release_channel's shape) either way, so both
    # sources map onto the top-level names through one table.
    release = stable or {
        "version": meta["version_ipa"],
        "date": meta["version_date"],
        "size": meta["size"],
        "sha256": meta["sha256"],
        "localizedDescription": meta["localized_description"],
        "downloadURL": meta["download_url"],
    }

    app.update({
        "version": release["version"],
        "versionDate": release["date"],
        "size": release["size"],
        "sha256": release["sha256"],
        "versionDescription": changelog_body(release["localizedDescription"]),
        "downloadURL": release["downloadURL"],
    })


# ----------------------------------------------------------
# update release channel (ORIGINAL FORMAT)
# ----------------------------------------------------------

def update_release_channel(app, meta):
    channels = app.setdefault("releaseChannels", [])

    new_version = {
        "version": meta["version_ipa"],
        "date": meta["version_date"],
        "localizedDescription": meta["localized_description"],
        "downloadURL": meta["download_url"],
        "size": meta["size"],
        "sha256": meta["sha256"],
    }

    tracks = [
        t for t in channels
        if isinstance(t, dict)
        and t.get("track") == meta["release_channel"]
    ]

    if len(tracks) > 1:
        raise SystemExit(f"Multiple tracks named {meta['release_channel']}")

    if not tracks:
        channels.insert(0, {
            "track": meta["release_channel"],
            "releases": [new_version],
        })
    else:
        track = tracks[0]
        releases = track.setdefault("releases", [])

        if not releases:
            releases.append(new_version)
        else:
            releases[0] = new_version


# ----------------------------------------------------------
# presentation metadata
# ----------------------------------------------------------

def load_template():
    if not TEMPLATE_FILE.exists():
        print(f"No template at {TEMPLATE_FILE} — publishing release data only")
        return {}

    with open(TEMPLATE_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def apply_template(data, app, template):
    """Everything a store page renders, and nothing CI can work out on its own.

    StoreApp.init(from:) decodes name, developerName, localizedDescription and iconURL
    non-optionally. An app entry carrying only bundleIdentifier and releaseChannels — which
    is all ensure_app creates — therefore throws during decode, and the source appears in
    the Sources tab but never loads.

    Applied on every run rather than only when absent, so the published feed is reproducible
    from this repo instead of depending on hand edits surviving on the gh-pages branch.
    """
    for key in ("name", "subtitle", "iconURL"):
        if key in template:
            data[key] = template[key]

    app.update(template.get("app", {}))


# ----------------------------------------------------------
# news
# ----------------------------------------------------------

def changelog_body(localized_description):
    """The release notes with generate_source_metadata.py's preamble taken off.

    That preamble repeats the version, the revision and the build timestamp, all of which the
    update card already shows beside the notes. Everything from the first `#### What's Changed`
    onwards is the part worth reading.

    Falls back to the description unchanged if that heading is missing, so a release whose notes
    were written by hand still gets published rather than being silently emptied.
    """
    marker = "#### What's Changed"
    index = localized_description.find(marker)

    if index == -1:
        return localized_description

    return localized_description[index:].strip()


def changelog_caption(localized_description):
    """The newest feature in the changelog, else the newest fix, else the newest other change,
    as a one-line summary of a release.

    Not simply the first bullet: every change reaches develop as a merged PR, so that one is
    always `Merge pull request #N from The-Big-Mini/MiniStoreFork`. On 2026-09-26 all ten news
    items on the feed carried that caption, differing only in N. Merges and chores (the version
    bump among them) are passed over, and features and fixes are preferred over docs and
    refactors, which the newest commit often is. A conventional-commit type is dropped — the
    item's title already says which release it is.

    generate_source_metadata.py indents the "this is release for" bullets by two spaces and
    starts the changelog ones at column zero, so the prefix alone tells them apart.
    """
    def commit_type(types):
        return rf"^(?:{types})(?:\([^)]*\))?!?:\s*"

    changes = [
        line[2:].strip() for line in localized_description.splitlines()
        if line.startswith("- ") and line[2:].strip()
        and not line[2:].startswith("Merge ") and not re.match(commit_type("chore"), line[2:])
    ]

    for preferred in ("feat", "fix", None):
        for caption in changes:
            if preferred and not re.match(commit_type(preferred), caption):
                continue

            description = re.sub(commit_type("feat|fix|docs|refactor|perf|test|build|ci|style|revert"), "", caption)
            if description != caption:
                # Conventional descriptions are lower-case; anything else keeps its own casing.
                caption = description[:1].upper() + description[1:]

            return caption if len(caption) <= 120 else caption[:117].rstrip() + "..."

    return "Tap to see what changed in this release."


def release_page_url(download_url):
    """.../releases/download/<tag>/<file> -> .../releases/tag/<tag>"""
    marker = "/releases/download/"
    if marker not in download_url:
        return None

    base, remainder = download_url.split(marker, 1)
    return f"{base}/releases/tag/{remainder.split('/', 1)[0]}"


def update_news(data, meta, template):
    """One news item per published release.

    NewsItem.init(from:) requires identifier, date, title and caption; everything else is
    optional.

    Deliberately no appID. NewsViewController renders a whole app banner — icon, developer,
    OPEN button — under any item that carries one, so every release note read as MiniStore
    listing its own IPA in the feed. `url` covers the tap: the item opens its release page.

    Items already on the feed are stripped too. The published source.json is carried forward
    between runs rather than regenerated, so dropping the key here only ever cleaned the item
    being written — every older release note kept its banner until this ran over them.
    """
    settings = template.get("news", {})
    channel = meta["release_channel"]
    version = meta["version_ipa"]

    entry = {
        # Stable across re-runs of the same version, so re-publishing replaces the item
        # instead of stacking a duplicate.
        "identifier": f"ministore-{channel}-{version}",
        "title": f"MiniStore {version}" if channel == "stable" else f"MiniStore {channel.title()} — {version}",
        "caption": changelog_caption(meta["localized_description"]),
        "date": meta["version_date"],
    }

    tint_color = settings.get("tintColor")
    if tint_color:
        entry["tintColor"] = tint_color

    url = release_page_url(meta["download_url"])
    if url:
        entry["url"] = url

    news = [item for item in data.get("news", []) if item.get("identifier") != entry["identifier"]]
    for item in news:
        item.pop("appID", None)

    news.insert(0, entry)

    maximum = settings.get("maximumItems")
    if isinstance(maximum, int) and maximum > 0:
        news = news[:maximum]

    data["news"] = news


# ----------------------------------------------------------
# save
# ----------------------------------------------------------

def save_source(source_file: Path, data):
    print("\nUpdated Sources File:\n")
    print(json.dumps(data, indent=2, ensure_ascii=False))

    source_file.parent.mkdir(parents=True, exist_ok=True)

    with open(source_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print("JSON successfully updated.")


# ----------------------------------------------------------
# main
# ----------------------------------------------------------

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 update_apps.py <metadata.json> <source.json>")
        sys.exit(1)

    metadata_file = Path(sys.argv[1])
    source_file = Path(sys.argv[2])

    meta = load_metadata(metadata_file)
    data = load_source(source_file)
    template = load_template()

    app = ensure_app(data, meta["bundle_identifier"])

    apply_template(data, app, template)
    update_release_channel(app, meta)
    update_storefront(app, meta)  # after the tracks: it mirrors the stable one
    update_news(data, meta, template)

    save_source(source_file, data)


if __name__ == "__main__":
    main()