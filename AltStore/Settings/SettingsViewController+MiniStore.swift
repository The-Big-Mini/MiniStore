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
        0: SettingsRowIcon(symbol: "display", color: .systemBlue),
        1: SettingsRowIcon(symbol: "arrow.clockwise", color: .systemGreen),
        2: SettingsRowIcon(symbol: "wrench.and.screwdriver.fill", color: .systemOrange),
        3: SettingsRowIcon(symbol: "flask.fill", color: .systemPink),
        4: SettingsRowIcon(symbol: "slider.horizontal.3", color: .systemRed),
        5: SettingsRowIcon(symbol: "sparkles", color: .systemYellow),
        6: SettingsRowIcon(symbol: "wand.and.stars", color: .systemTeal),
        7: SettingsRowIcon(symbol: "chevron.left.forwardslash.chevron.right", color: .systemPurple),
    ],

    // Display
    4: [0: SettingsRowIcon(symbol: "paintbrush.fill", color: .systemBlue)],

    // Refreshing Apps
    5: [
        0: SettingsRowIcon(symbol: "arrow.clockwise", color: .systemGreen),
        1: SettingsRowIcon(symbol: "moon.zzz.fill", color: .systemIndigo),
        2: SettingsRowIcon(symbol: "mic.fill", color: .systemPurple),
        3: SettingsRowIcon(symbol: "infinity", color: .systemOrange),
    ],

    // How it works
    6: [0: SettingsRowIcon(symbol: "questionmark.circle.fill", color: .systemTeal)],

    // Techy Things
    7: [
        0: SettingsRowIcon(symbol: "heart.text.square.fill", color: .systemPink),
        1: SettingsRowIcon(symbol: "doc.text.fill", color: .systemOrange),
        2: SettingsRowIcon(symbol: "folder.fill", color: .systemBlue),
        3: SettingsRowIcon(symbol: "trash.fill", color: .systemRed),
    ],

    // Credits
    8: [
        0: SettingsRowIcon(symbol: "hammer.fill", color: .systemGray),
        1: SettingsRowIcon(symbol: "paintbrush.pointed.fill", color: .systemPink),
        2: SettingsRowIcon(symbol: "paintpalette.fill", color: .systemOrange),
        3: SettingsRowIcon(symbol: "doc.plaintext.fill", color: .systemGray),
    ],

    // Beta Testing
    9: [
        0: SettingsRowIcon(symbol: "ant.fill", color: .systemGreen),
        1: SettingsRowIcon(symbol: "arrow.triangle.branch", color: .systemTeal),
    ],

    // Advanced Settings
    10: [
        0: SettingsRowIcon(symbol: "envelope.fill", color: .systemBlue),
        1: SettingsRowIcon(symbol: "list.bullet.rectangle", color: .systemGreen),
        2: SettingsRowIcon(symbol: "bolt.fill", color: .systemYellow),
        3: SettingsRowIcon(symbol: "arrow.triangle.2.circlepath", color: .systemOrange),
        4: SettingsRowIcon(symbol: "server.rack", color: .systemIndigo),
        5: SettingsRowIcon(symbol: "network", color: .systemTeal),
        6: SettingsRowIcon(symbol: "checkmark.seal.fill", color: .systemGreen),
        7: SettingsRowIcon(symbol: "externaldrive.fill", color: .systemBrown),
        8: SettingsRowIcon(symbol: "slider.horizontal.3", color: .systemRed),
    ],

    // Diagnostics
    11: [
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

        let standard = UINavigationBarAppearance()
        standard.configureWithOpaqueBackground()
        standard.backgroundColor = .settingsBackground
        standard.titleTextAttributes = [.foregroundColor: UIColor.white]
        standard.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        standard.shadowColor = nil

        // The scroll-edge appearance keeps its default (blurred) background: iOS 26 needs one
        // to render a large title at all, and an opaque one suppresses it.
        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithDefaultBackground()
        scrollEdge.titleTextAttributes = [.foregroundColor: UIColor.white]
        scrollEdge.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        scrollEdge.shadowColor = nil

        self.navigationItem.standardAppearance = standard
        self.navigationItem.scrollEdgeAppearance = scrollEdge
        self.navigationItem.compactAppearance = standard
    }

    /// The one thing that has to land on the *shared* navigation bar, applied after the
    /// transition has finished — the one point where writing to the bar cannot disturb an
    /// animation in progress. `tintColor` has no per-item equivalent, so it has no other home.
    ///
    /// A bar-level appearance used to be written here as well, to keep titles white on the plain
    /// screens pushed out of Settings under iOS 26. Measured on an iPhone 17 Pro, it cost a
    /// 28-frame (~0.47s) artifact on every pop: the bar held the outgoing screen's expanded
    /// height for the whole transition and then snapped up, clipping ~37pt off the top of the
    /// destination. Those screens now carry `MiniStore.pushedScreenBarAppearance` on their own
    /// `navigationItem` instead, which is the supported way and costs nothing.
    @objc func applyMiniStoreBarTint()
    {
        self.navigationController?.navigationBar.tintColor = .white
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
