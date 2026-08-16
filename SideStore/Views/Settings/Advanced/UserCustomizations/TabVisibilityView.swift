//
//  TabVisibilityView.swift
//  SideStore
//
//  Lets the user switch individual tabs off and pick which one opens on launch.
//

import SwiftUI
import UIKit

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

    /// Drag-to-reorder state. `dragStartIndex` is where the lifted row began, so the target
    /// index can be derived from the total translation rather than accumulated deltas — the
    /// rows shuffle underneath while the lifted one stays under the finger.
    @State private var draggingID: Int?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragStartIndex: Int?

    /// Pinned rather than intrinsic: translation is converted to a row count, which needs a
    /// height that cannot drift with the label.
    private static let rowHeight: CGFloat = 56

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

                    Text("Touch and hold a tab, then drag it to change the order tabs appear in. The last visible tab cannot be switched off. Hidden tabs stay reachable from links and notifications — opening one switches it back on.")
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
        let isDragging = draggingID == tab.id

        return HStack {
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
        .frame(height: Self.rowHeight)
        // The lifted row rides above its neighbours and follows the finger; the rest animate
        // into their new slots as `tabs` is reordered underneath.
        .background(isDragging ? Color.white.opacity(0.12) : Color.clear)
        .scaleEffect(isDragging ? 1.02 : 1)
        .offset(y: isDragging ? liftedOffset(for: tab) : 0)
        .zIndex(isDragging ? 1 : 0)
        .gesture(reorderGesture(for: tab))
    }

    /// Long-press to lift, then drag. `.onMove` would be less code but needs a `List`, and a
    /// `List` here means either an iOS 16 API (`scrollContentBackground`) against a deployment
    /// target of 15, or clearing `UITableView.appearance()` globally — both worse than this.
    ///
    /// Attached with `.gesture` rather than `.highPriorityGesture` so the row's `Toggle` keeps
    /// its own touches.
    private func reorderGesture(for tab: Tab) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }

                if draggingID != tab.id
                {
                    draggingID = tab.id
                    dragStartIndex = tabs.firstIndex(of: tab)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                dragTranslation = drag.translation.height
                moveIfNeeded(tab)
            }
            .onEnded { _ in
                if draggingID != nil
                {
                    MiniStore.tabOrder = tabs.map(\.id)
                    debugLog("[MiniStore] Tab order set to \(tabs.map(\.id)).")
                }

                withAnimation(.easeOut(duration: 0.15)) {
                    draggingID = nil
                    dragTranslation = 0
                    dragStartIndex = nil
                }
            }
    }

    /// How far the lifted row is drawn from its *current* slot: the raw translation less the
    /// distance it has already been moved by reordering, so it stays under the finger.
    private func liftedOffset(for tab: Tab) -> CGFloat {
        guard let start = dragStartIndex, let index = tabs.firstIndex(of: tab) else { return 0 }
        return dragTranslation - CGFloat(index - start) * Self.rowHeight
    }

    private func moveIfNeeded(_ tab: Tab) {
        guard let start = dragStartIndex, let index = tabs.firstIndex(of: tab) else { return }

        let target = min(max(start + Int((dragTranslation / Self.rowHeight).rounded()), 0), tabs.count - 1)
        guard target != index else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            let moved = tabs.remove(at: index)
            tabs.insert(moved, at: target)
        }
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
