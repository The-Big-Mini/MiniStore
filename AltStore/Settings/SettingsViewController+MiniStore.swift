//
//  SettingsViewController+MiniStore.swift
//  AltStore
//
//  Gives the stock settings table MiniStore's look without restructuring it.
//

@preconcurrency import UIKit

private struct SettingsRowIcon
{
    let symbol: String
    let color: UIColor
}

/// Leading tiles keyed by the static table's `[section][row]` position.
///
/// Positions rather than the `Section` / `*Row` enums because those are private to
/// `SettingsViewController.swift`, and mirroring them here would be a second copy to keep in
/// step with upstream. The table is static, so a position is as stable as an enum case — and
/// a row that moves loses its icon rather than misbehaving.
///
/// Sections 0 (sign in) and 1 (account) are deliberately absent: those rows are values, not
/// destinations, and MiniStore leaves them plain. Section 2 is the Patreon row.
///
/// Section 3 is the root's category list; sections 4 and up are only ever shown inside the
/// category screen that owns them.
private let miniStoreRowIcons: [Int: [Int: SettingsRowIcon]] = [
    // Categories — the root list
    3: [
        0: SettingsRowIcon(symbol: "paintbrush.fill", color: .systemBlue),
        1: SettingsRowIcon(symbol: "arrow.clockwise", color: .systemGreen),
        2: SettingsRowIcon(symbol: "wrench.and.screwdriver.fill", color: .systemOrange),
        3: SettingsRowIcon(symbol: "flask.fill", color: .systemPink),
        4: SettingsRowIcon(symbol: "slider.horizontal.3", color: .systemRed),
        5: SettingsRowIcon(symbol: "sparkles", color: .systemYellow),
        6: SettingsRowIcon(symbol: "wand.and.stars", color: .systemTeal),
        7: SettingsRowIcon(symbol: "chevron.left.forwardslash.chevron.right", color: .systemPurple),
    ],

    // Refreshing Apps
    4: [
        0: SettingsRowIcon(symbol: "arrow.clockwise", color: .systemGreen),
        1: SettingsRowIcon(symbol: "moon.zzz.fill", color: .systemIndigo),
        2: SettingsRowIcon(symbol: "mic.fill", color: .systemPurple),
        3: SettingsRowIcon(symbol: "infinity", color: .systemOrange),
    ],

    // How it works
    5: [0: SettingsRowIcon(symbol: "questionmark.circle.fill", color: .systemTeal)],

    // Techy Things
    6: [
        0: SettingsRowIcon(symbol: "heart.text.square.fill", color: .systemPink),
        1: SettingsRowIcon(symbol: "doc.text.fill", color: .systemOrange),
        2: SettingsRowIcon(symbol: "folder.fill", color: .systemBlue),
        3: SettingsRowIcon(symbol: "trash.fill", color: .systemRed),
    ],

    // Credits
    7: [
        0: SettingsRowIcon(symbol: "hammer.fill", color: .systemGray),
        1: SettingsRowIcon(symbol: "paintbrush.pointed.fill", color: .systemPink),
        2: SettingsRowIcon(symbol: "paintpalette.fill", color: .systemOrange),
        3: SettingsRowIcon(symbol: "doc.plaintext.fill", color: .systemGray),
    ],

    // Beta Testing
    8: [
        0: SettingsRowIcon(symbol: "ant.fill", color: .systemGreen),
        1: SettingsRowIcon(symbol: "arrow.triangle.branch", color: .systemTeal),
    ],

    // Advanced Settings
    9: [
        0: SettingsRowIcon(symbol: "envelope.fill", color: .systemBlue),
        1: SettingsRowIcon(symbol: "list.bullet.rectangle", color: .systemGreen),
        2: SettingsRowIcon(symbol: "bolt.fill", color: .systemYellow),
        3: SettingsRowIcon(symbol: "arrow.triangle.2.circlepath", color: .systemOrange),
        4: SettingsRowIcon(symbol: "server.rack", color: .systemIndigo),
        5: SettingsRowIcon(symbol: "network", color: .systemTeal),
        6: SettingsRowIcon(symbol: "checkmark.seal.fill", color: .systemGreen),
        7: SettingsRowIcon(symbol: "externaldrive.fill", color: .systemBrown),
    ],

    // Diagnostics
    10: [
        0: SettingsRowIcon(symbol: "chevron.left.forwardslash.chevron.right", color: .systemPurple),
        1: SettingsRowIcon(symbol: "wand.and.stars", color: .systemTeal),
    ],
]

extension SettingsViewController
{
    /// Paints the page and this screen's slice of the navigation bar. Also the handler for OLED
    /// mode changing, which the colours themselves cannot pick up — a `UserDefaults` change is
    /// not a trait change, and a bar appearance resolves its colours once, when it is assigned.
    ///
    /// Everything here is assigned to `navigationItem`, never to
    /// `navigationController.navigationBar`. The bar is shared by every screen in the stack, and
    /// UIKit is interpolating its metrics for the whole duration of a push or a pop. Writing
    /// bar-level appearance during that window invalidates the layout mid-flight: the header
    /// settles lower than it should on the way in, and lower again on the way back out. The
    /// per-item properties are the supported way to do this — UIKit cross-fades them between
    /// view controllers, so each screen can differ without any screen touching the shared bar.
    /// Upstream's own `prepare(for:)` already sets pushed controllers up this way.
    @objc func applyMiniStoreStyle()
    {
        self.tableView.backgroundColor = .settingsBackground

        // One appearance, default background, and deliberately no `backgroundColor`.
        //
        // The bar picks scroll-edge at the top of a table and standard once it scrolls, and UIKit
        // cross-fades the *source's* current appearance into the *destination's* across a push.
        // Any difference between the two shows up as a transition artifact, and both halves of
        // the difference were measured on iPhone Air / iOS 26.5:
        //
        // - Source opaque `.settingsBackground`, destination blurred: pushing from a *scrolled*
        //   root left the bar with no background for the whole animation and the rows behind it
        //   showed through. Purple pixels inside the bar band went 0 → 146 → 0.
        // - Colouring the *destination's* scroll edge to match instead moves its first row 43pt
        //   down for the whole transition, snapping back a frame after it ends (522 → 393px).
        //   That is not about opacity: it was measured with `configureWithOpaqueBackground`,
        //   `configureWithDefaultBackground` and `configureWithTransparentBackground`, and with
        //   `extendedLayoutIncludesOpaqueBars = true`. **Any** `backgroundColor` on a pushed
        //   screen's `scrollEdgeAppearance` does it. 053c5510 and 4c60b07f both died here.
        //
        // So the colour has to go, not move. It also keeps the large title: on iOS 26 an opaque
        // scroll-edge background suppresses it entirely.
        //
        // The trade is visible and accepted. On iOS 26 the default background is a thin blur, so
        // while the table scrolls the rows passing behind the bar show through — it does not read
        // as a solid fill. That was checked on device and kept deliberately: the artifact-free
        // property comes from scroll-edge and standard being *identical*, and `backgroundColor`
        // is the one way to make them solid that measurement has already ruled out. Any future
        // attempt has to change **both** appearances together and be measured on both metrics
        // (at-top `cardTop` step, scrolled bar-band bleed) before it ships. `backgroundImage` and
        // `backgroundEffect` are untried and are not `backgroundColor`, so the law above may not
        // bind them — that is a hypothesis, not a plan.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.shadowColor = nil

        self.navigationItem.standardAppearance = appearance
        self.navigationItem.scrollEdgeAppearance = appearance
        self.navigationItem.compactAppearance = appearance
    }

    /// Everything that has to land on the *shared* navigation bar, applied after the transition
    /// has finished — the one point where writing to the bar cannot disturb an animation in
    /// progress. `tintColor` has no per-item equivalent, so it has no other home.
    ///
    /// The iOS 26 title-colour appearance is here for timing, not for this screen: the settings
    /// screens set their own colours on `navigationItem` in `applyMiniStoreStyle()`, which wins
    /// over anything bar-level. It is the plain UIKit screens pushed from here — anisette
    /// servers, certificate management, error details — that have no appearance of their own and
    /// would render a dark title on a dark bar without it.
    @objc func applyMiniStoreBarTint()
    {
        self.navigationController?.navigationBar.tintColor = .white

        if #available(iOS 26.0, *)
        {
            let appearance = UINavigationBarAppearance()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

            self.navigationController?.navigationBar.standardAppearance = appearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
    }

    /// Pushes a screen out of Settings without the header artifact — the header settling low
    /// and snapping into place a beat later, on the way in and again on the way back.
    ///
    /// The cause is the large title. Settings has one; the screens it pushes do not. UIKit
    /// resolves that as a nav-bar height change, and resolves it *late* — the destination's
    /// `adjustedContentInset.top` is still the large-title height as it comes on screen, so
    /// content lands ~37pt low and jumps once the real height is known.
    ///
    /// Three things have to happen together, and each one on its own is visible:
    ///
    /// - The destination is set to a small title *before* the push, so it never flashes a
    ///   large one on entry.
    /// - This screen's large title collapses **in lock-step with the push**, driven by the
    ///   transition coordinator, so the resize is interpolated over the same duration as the
    ///   slide. Collapsing it beforehand instead — `UIView.performWithoutAnimation` plus a
    ///   forced layout pass — trades the late snap for an equally visible one just before the
    ///   push starts. `layoutIfNeeded()` is deliberately absent below for the same reason: a
    ///   synchronous layout inside the animation block snaps the title instead of
    ///   interpolating it.
    /// - `viewWillAppear` puts `.automatic` back, so the large title animates in on the pop.
    ///
    /// Carried over from the discontinued MiniStore rewrite, where this shape was arrived at
    /// over several rounds and is the version that actually held.
    func pushMiniStoreSettingsScreen(_ viewController: UIViewController)
    {
        viewController.navigationItem.largeTitleDisplayMode = .never

        self.navigationController?.pushViewController(viewController, animated: true)

        guard let coordinator = self.navigationController?.transitionCoordinator else
        {
            self.navigationItem.largeTitleDisplayMode = .never
            return
        }

        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.navigationItem.largeTitleDisplayMode = .never
        }, completion: { [weak self] context in
            // A cancelled interactive transition would otherwise leave this screen's title
            // collapsed for good, with no push left to restore it.
            guard context.isCancelled else { return }
            self?.navigationItem.largeTitleDisplayMode = .automatic
        })
    }

    func applyMiniStoreIcon(to cell: UITableViewCell, at indexPath: IndexPath)
    {
        guard let icon = miniStoreRowIcons[indexPath.section]?[indexPath.row] else { return }
        cell.applyMiniStoreIcon(symbol: icon.symbol, color: icon.color)
    }
}

private extension UITableViewCell
{
    static let miniStoreIconTag = 0x4D53_4943 // 'MSIC'

    func applyMiniStoreIcon(symbol: String, color: UIColor)
    {
        // The table is static, so each cell is built once — an existing tile means this row is
        // already done, and re-rendering the image on every pass would be wasted work.
        guard self.contentView.viewWithTag(Self.miniStoreIconTag) == nil else { return }

        let tile = UIImageView(image: MiniStore.settingsIcon(symbol, color: color))
        tile.tag = Self.miniStoreIconTag
        tile.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(tile)

        NSLayoutConstraint.activate([
            tile.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 30),
            tile.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            tile.widthAnchor.constraint(equalToConstant: 28),
            tile.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Every row in this table pins its content to the content view's layout margins, so
        // widening the leading margin is what makes room for the tile. Preserved margins would
        // snap it back to the cell's own 30pt.
        self.contentView.preservesSuperviewLayoutMargins = false
        self.contentView.layoutMargins = UIEdgeInsets(top: 8, left: 70, bottom: 8, right: 30)
    }
}
