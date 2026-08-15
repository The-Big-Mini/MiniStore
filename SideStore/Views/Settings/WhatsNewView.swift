//
//  WhatsNewView.swift
//  SideStore
//
//  Release notes, read from this fork's own GitHub releases.
//

import SwiftUI

private struct ReleaseEntry: Identifiable
{
    let id: String
    let name: String
    let body: String
    let date: String
    let isPrerelease: Bool
}

@MainActor
private final class WhatsNewViewModel: ObservableObject
{
    @Published var entries: [ReleaseEntry] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private static let releasesURL = URL(string: "https://api.github.com/repos/The-Big-Mini/SideStore/releases?per_page=10")!

    func load() async
    {
        guard !self.isLoading else { return }

        self.isLoading = true
        self.errorMessage = nil
        defer { self.isLoading = false }

        var request = URLRequest(url: Self.releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do
        {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let statusCode = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(statusCode)
            {
                debugLog("[WhatsNew] GitHub returned HTTP \(statusCode) for \(Self.releasesURL)")
                self.errorMessage = String(format: NSLocalizedString("GitHub returned HTTP %d.", comment: ""), statusCode)
                return
            }

            self.entries = try Self.decode(data)
        }
        catch
        {
            let nsError = error as NSError
            debugLog("[WhatsNew] Failed to load releases: [\(nsError.domain) \(nsError.code)] \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }

    /// Hand-decoded rather than `Codable`: only five of the release payload's ~40 fields are used,
    /// and GitHub adding a field should never fail the whole screen.
    private static func decode(_ data: Data) throws -> [ReleaseEntry]
    {
        guard let releases = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else
        {
            throw CocoaError(.propertyListReadCorrupt)
        }

        let published = ISO8601DateFormatter()
        let displayed = DateFormatter()
        displayed.dateStyle = .medium

        return releases.compactMap { release in
            guard let tag = release["tag_name"] as? String else { return nil }

            let name = (release["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? tag
            let date = (release["published_at"] as? String)
                .flatMap { published.date(from: $0) }
                .map { displayed.string(from: $0) } ?? ""

            return ReleaseEntry(id: tag,
                                name: name,
                                body: (release["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                                date: date,
                                isPrerelease: (release["prerelease"] as? Bool) ?? false)
        }
    }
}

struct WhatsNewView: View
{
    @StateObject private var model = WhatsNewViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let errorMessage = model.errorMessage, model.entries.isEmpty
                {
                    self.errorCard(errorMessage)
                }
                else if model.entries.isEmpty && model.isLoading
                {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                }
                else if model.entries.isEmpty
                {
                    Text("No releases published yet.")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                }
                else
                {
                    ForEach(model.entries) { entry in
                        self.releaseCard(entry)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .miniStoreBackground()
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.large)
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    private func releaseCard(_ entry: ReleaseEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                if entry.isPrerelease
                {
                    Text("BETA")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                }

                Spacer()

                Text(entry.date)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.6))
            }

            if !entry.body.isEmpty
            {
                Rectangle()
                    .fill(Color.miniStoreSeparator)
                    .frame(height: 0.5)

                self.releaseBody(entry.body)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.miniStoreCard)
        .cornerRadius(16)
    }

    /// Release bodies are GitHub Markdown. `Text` renders bold, italics and links on its own once
    /// the string is a `LocalizedStringKey`; headings and bullets it does not, so those are turned
    /// into plain typography here rather than left showing their `#` and `-` markers.
    private func releaseBody(_ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(body.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespaces)

                if line.isEmpty
                {
                    Spacer().frame(height: 2)
                }
                else if line.hasPrefix("#")
                {
                    Text(.init(line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                else if line.hasPrefix("- ") || line.hasPrefix("* ")
                {
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        Text(.init(String(line.dropFirst(2))))
                    }
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                }
                else
                {
                    Text(.init(line))
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(Color.white.opacity(0.75))

            Text("Couldn't load releases.")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Qualified: the app target has its own `Button` type.
            SwiftUI.Button {
                Task { await model.load() }
            } label: {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.miniStoreCard)
        .cornerRadius(16)
    }
}
