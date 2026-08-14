//
//  TabVisibilityView.swift
//  SideStore
//
//  Lets the user switch individual tabs off and pick which one opens on launch.
//

import SwiftUI

struct TabVisibilityView: View
{
    /// Read off the live tab bar rather than a hard-coded list, so a tab added upstream
    /// shows up here without this screen needing to know about it.
    private struct Tab: Identifiable, Equatable
    {
        let id: Int
        let title: String
    }

    @State private var tabs: [Tab] = []
    @State private var hiddenTabs = MiniStore.hiddenTabs
    @State private var defaultTab = MiniStore.defaultTab

    private var visibleTabs: [Tab] {
        tabs.filter { !hiddenTabs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    header("TABS")

                    VStack(spacing: 0) {
                        ForEach(tabs) { tab in
                            visibilityRow(for: tab)

                            if tab.id != tabs.last?.id {
                                divider
                            }
                        }
                    }
                    .background(Color.miniStoreCard)
                    .cornerRadius(16)

                    Text("The last visible tab cannot be switched off. Hidden tabs stay reachable from links and notifications — opening one switches it back on.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 8) {
                    header("OPENS ON LAUNCH")

                    VStack(spacing: 0) {
                        defaultTabRow
                    }
                    .background(Color.miniStoreCard)
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .miniStoreBackground()
        .navigationTitle("Tab Bar")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            tabs = MiniStore.tabBarController()?.allViewControllers.enumerated().map { index, viewController in
                Tab(id: index, title: viewController.tabBarItem?.title ?? "Tab \(index + 1)")
            } ?? []
        }
    }

    private func visibilityRow(for tab: Tab) -> some View {
        HStack {
            Text(tab.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Toggle("", isOn: Binding(
                get: { !hiddenTabs.contains(tab.id) },
                set: { setVisible($0, for: tab) }
            ))
            .labelsHidden()
            .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
    }

    private func setVisible(_ isVisible: Bool, for tab: Tab) {
        debugLog("[MiniStore] Tab \(tab.id) (\(tab.title)) set to visible=\(isVisible).")

        // Switching off the last visible tab would leave an empty tab bar and no way back
        // here. Refused in the setter rather than with `.disabled`, which stops the whole
        // Toggle from responding to touches.
        guard isVisible || visibleTabs.count > 1 else { return }

        if isVisible { hiddenTabs.remove(tab.id) } else { hiddenTabs.insert(tab.id) }
        MiniStore.hiddenTabs = hiddenTabs

        // A hidden tab can't be the one the app opens on.
        if hiddenTabs.contains(defaultTab), let fallback = visibleTabs.first {
            defaultTab = fallback.id
            MiniStore.defaultTab = fallback.id
        }
    }

    private var defaultTabRow: some View {
        HStack {
            Text("Default Tab")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Menu {
                // Only tabs that are actually on the bar — the app cannot open on a hidden one.
                ForEach(visibleTabs) { tab in
                    SwiftUI.Button {
                        defaultTab = tab.id
                        MiniStore.defaultTab = tab.id
                    } label: {
                        if defaultTab == tab.id {
                            Label(tab.title, systemImage: "checkmark")
                        } else {
                            Text(tab.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(tabs.first { $0.id == defaultTab }?.title ?? "")
                        .font(.system(size: 17))
                        .foregroundColor(Color.white.opacity(0.8))

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
    }

    private func header(_ title: String) -> some View {
        Text(NSLocalizedString(title, comment: ""))
            .font(.system(size: 14))
            .foregroundColor(Color.white.opacity(0.75))
            .padding(.horizontal, 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.miniStoreSeparator)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}
