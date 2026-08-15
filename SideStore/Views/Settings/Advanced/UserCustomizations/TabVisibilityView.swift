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

    /// Held in display order, not storyboard order — `tab.id` stays the storyboard index.
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

                    Text("Use the arrows to change the order tabs appear in. The last visible tab cannot be switched off. Hidden tabs stay reachable from links and notifications — opening one switches it back on.")
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
            // Titles come off the live tab bar, which is in storyboard order; the rows are then
            // put into the user's order. Reading the bar rather than a hard-coded list means a
            // tab added upstream shows up here without this screen needing to know about it.
            let storyboardTabs = MiniStore.tabBarController()?.allViewControllers.enumerated().map { index, viewController in
                Tab(id: index, title: viewController.tabBarItem?.title ?? "Tab \(index + 1)")
            } ?? []

            let order = MiniStore.resolvedTabOrder(count: storyboardTabs.count)
            tabs = order.compactMap { id in storyboardTabs.first { $0.id == id } }
        }
    }

    private func visibilityRow(for tab: Tab) -> some View {
        HStack {
            Text(tab.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            self.moveButtons(for: tab)

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

    /// Explicit arrows rather than drag-to-reorder. `.onMove` needs a `List`, and a `List` here
    /// would mean either an iOS 16 API (`scrollContentBackground`) against a deployment target of
    /// 15, or clearing `UITableView.appearance()` globally. Neither is worth it for five rows.
    private func moveButtons(for tab: Tab) -> some View {
        let index = tabs.firstIndex(of: tab)

        return HStack(spacing: 2) {
            moveButton(systemImage: "chevron.up", isEnabled: index.map { $0 > 0 } ?? false) {
                move(tab, by: -1)
            }

            moveButton(systemImage: "chevron.down", isEnabled: index.map { $0 < tabs.count - 1 } ?? false) {
                move(tab, by: 1)
            }
        }
        .padding(.trailing, 4)
    }

    private func moveButton(systemImage: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        SwiftUI.Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(isEnabled ? 0.7 : 0.2))
                .frame(width: 30, height: 30)
        }
        .disabled(!isEnabled)
        // Without this each button would inherit the row's tap target and both would fire.
        .buttonStyle(.borderless)
    }

    private func move(_ tab: Tab, by offset: Int) {
        guard let index = tabs.firstIndex(of: tab) else { return }

        let destination = index + offset
        guard tabs.indices.contains(destination) else { return }

        tabs.swapAt(index, destination)
        MiniStore.tabOrder = tabs.map(\.id)

        debugLog("[MiniStore] Tab order set to \(tabs.map(\.id)).")
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
