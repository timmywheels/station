import AppKit

/// Above the diff while reviewing a pull request: title, who, where, state —
/// click to show the description.
final class PullRequestBar: NSView {
    static let collapsedHeight: CGFloat = 36
    private(set) var expanded = false
    private var pr: GitHub.PR?
    private let bodyScroll = NSScrollView()
    private let bodyText = NSTextView()
    private let openButton = CapsuleButton()
    private let syncButton = CapsuleButton()
    private let checkoutButton = CapsuleButton()
    /// Not checked out here: you can read and comment, not edit.
    private var readOnly = false
    private var mine = false
    var onCheckout: (() -> Void)?
    private var syncedAt: Date?
    let mergeButton = CapsuleButton()
    var onToggle: (() -> Void)?
    var onMerge: (() -> Void)?
    var onSync: (() -> Void)?

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        bodyText.isEditable = false
        bodyText.drawsBackground = false
        bodyText.textContainerInset = NSSize(width: 14, height: 4)
        bodyScroll.documentView = bodyText
        bodyScroll.hasVerticalScroller = true
        bodyScroll.autohidesScrollers = true
        bodyScroll.drawsBackground = false
        bodyText.autoresizingMask = [.width]
        bodyScroll.isHidden = true
        addSubview(bodyScroll)
        openButton.setText("Open on GitHub ↗")
        openButton.horizontalPadding = 10
        openButton.target = self
        openButton.action = #selector(openOnGitHub)
        addSubview(openButton)
        mergeButton.setText("Merge…")
        mergeButton.horizontalPadding = 10
        mergeButton.target = self
        mergeButton.action = #selector(mergeClicked)
        mergeButton.isHidden = true
        mergeButton.toolTip = "Merge this pull request on GitHub"
        addSubview(mergeButton)
        syncButton.horizontalPadding = 10
        syncButton.target = self
        syncButton.action = #selector(syncClicked)
        syncButton.isHidden = true
        addSubview(syncButton)
        setSyncing(false)
        checkoutButton.horizontalPadding = 10
        checkoutButton.target = self
        checkoutButton.action = #selector(checkoutClicked)
        checkoutButton.isHidden = true
        addSubview(checkoutButton)
    }

    /// Read-only (the PR's branch isn't checked out here): a chip says so, and "Check out" offers to change that.
    func setReadOnly(_ readOnly: Bool) {
        self.readOnly = readOnly
        checkoutButton.isHidden = !readOnly
        updateCheckout()
    }

    func setMine(_ mine: Bool) {
        self.mine = mine
        updateCheckout()
    }

    func setCheckingOut(_ busy: Bool) {
        checkoutButton.isEnabled = !busy
        updateCheckout(busy: busy)
    }

    private func updateCheckout(busy: Bool = false) {
        checkoutButton.setText(busy ? "Checking out…" : "Check Out", symbol: "arrow.down.circle", color: busy ? .secondaryLabelColor : .labelColor)
        checkoutButton.toolTip = "Switch this repo to the PR's branch (gh pr checkout), so you can edit, commit and push."
            + (mine ? "" : " It's someone else's PR: pushing needs their permission.")
        needsLayout = true
        needsDisplay = true
    }

    @objc private func checkoutClicked() { onCheckout?() }

    /// "Sync": bring GitHub's comments in now (they also come every 90 s). Hidden when comments don't sync.
    func showSync(_ show: Bool) {
        syncButton.isHidden = !show
        needsLayout = true
        needsDisplay = true
    }

    func setSyncing(_ syncing: Bool, done: Bool = false) {
        if done { syncedAt = Date() }
        syncButton.isEnabled = !syncing
        syncButton.setText(syncing ? "Syncing…" : "Sync", symbol: "arrow.triangle.2.circlepath", color: syncing ? .secondaryLabelColor : .labelColor)
        let last = syncedAt.map { "Last synced " + RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date()) + "." } ?? ""
        syncButton.toolTip = "Get this PR's comments from GitHub now (⌘R does too). " + last
        needsLayout = true
        needsDisplay = true
    }

    @objc private func syncClicked() { onSync?() }

    /// Show "Merge…" (your own open PR).
    func showMerge(_ show: Bool) {
        mergeButton.isHidden = !show
        needsLayout = true
        needsDisplay = true
    }

    @objc private func mergeClicked() { onMerge?() }

    required init?(coder: NSCoder) { fatalError() }

    func set(_ pr: GitHub.PR?) {
        self.pr = pr
        let body = (pr?.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        bodyText.textStorage?.setAttributedString(body.isEmpty
            ? NSAttributedString(string: "No description.", attributes: [.font: NSFont.systemFont(ofSize: 12.5), .foregroundColor: NSColor.secondaryLabelColor])
            : CommentMarkdown.render(body, font: .systemFont(ofSize: 12.5), color: .labelColor))
        needsLayout = true
        needsDisplay = true
    }

    /// Height wanted: the bar, plus the description (up to `max`) when open.
    func height(max: CGFloat) -> CGFloat {
        guard expanded, let lm = bodyText.layoutManager, let tc = bodyText.textContainer else { return Self.collapsedHeight }
        bodyText.frame.size.width = bounds.width
        lm.ensureLayout(for: tc)
        let body = lm.usedRect(for: tc).height + 2 * bodyText.textContainerInset.height + 10
        return Self.collapsedHeight + min(body, max)
    }

    override func layout() {
        super.layout()
        openButton.fit()
        openButton.frame.origin = NSPoint(x: bounds.width - 12 - openButton.frame.width, y: (Self.collapsedHeight - CapsuleButton.height) / 2)
        mergeButton.fit()
        mergeButton.frame.origin = NSPoint(x: openButton.frame.minX - 8 - mergeButton.frame.width, y: openButton.frame.minY)
        var beside = mergeButton.isHidden ? openButton.frame.minX : mergeButton.frame.minX
        for b in [syncButton, checkoutButton] where !b.isHidden {
            b.fit()
            b.frame.origin = NSPoint(x: beside - 8 - b.frame.width, y: openButton.frame.minY)
            beside = b.frame.minX
        }
        bodyScroll.isHidden = !expanded
        bodyScroll.frame = NSRect(x: 0, y: Self.collapsedHeight, width: bounds.width, height: max(0, bounds.height - Self.collapsedHeight - 6))
        bodyText.frame.size.width = bodyScroll.contentSize.width
    }

    override func draw(_ dirtyRect: NSRect) {
        DiffStyle.headerBackground.setFill()
        bounds.fill()
        DiffStyle.separator.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
        guard let pr else { return }
        let mid = Self.collapsedHeight / 2
        // Chevron
        let c = NSBezierPath()
        let cx: CGFloat = 17, s: CGFloat = 3.5
        if expanded {
            c.move(to: NSPoint(x: cx - s, y: mid - s / 2)); c.line(to: NSPoint(x: cx, y: mid + s / 2)); c.line(to: NSPoint(x: cx + s, y: mid - s / 2))
        } else {
            c.move(to: NSPoint(x: cx - s / 2, y: mid - s)); c.line(to: NSPoint(x: cx + s / 2, y: mid)); c.line(to: NSPoint(x: cx - s / 2, y: mid + s))
        }
        c.lineWidth = 1.6; c.lineCapStyle = .round; c.lineJoinStyle = .round
        DiffStyle.headerText.withAlphaComponent(0.55).setStroke()
        c.stroke()
        // State chip
        let (state, color): (String, NSColor) = pr.isDraft ? ("Draft", .secondaryLabelColor)
            : pr.state == "MERGED" ? ("Merged", .systemPurple) : pr.state == "CLOSED" ? ("Closed", DiffStyle.deletedAccent) : ("Open", DiffStyle.addedAccent)
        let chip = NSAttributedString(string: state, attributes: [.font: NSFont.systemFont(ofSize: 10.5, weight: .semibold), .foregroundColor: color])
        let cs = chip.size()
        let chipRect = NSRect(x: 30, y: mid - 8, width: cs.width + 12, height: 16)
        color.withAlphaComponent(0.16).setFill()
        NSBezierPath(roundedRect: chipRect, xRadius: 8, yRadius: 8).fill()
        chip.draw(at: NSPoint(x: chipRect.minX + 6, y: chipRect.minY + (16 - cs.height) / 2))
        var afterChips = chipRect.maxX
        if readOnly { // "Read-only", with a lock: you're looking, not editing
            let ro = NSMutableAttributedString()
            if let lock = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 9, weight: .semibold)) {
                let a = NSTextAttachment(); a.image = lock
                ro.append(NSAttributedString(attachment: a))
                ro.append(NSAttributedString(string: " "))
            }
            ro.append(NSAttributedString(string: "Read-only", attributes: [.font: NSFont.systemFont(ofSize: 10.5, weight: .semibold)]))
            ro.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: NSRange(location: 0, length: ro.length))
            let rs = ro.size()
            let r = NSRect(x: chipRect.maxX + 6, y: mid - 8, width: rs.width + 12, height: 16)
            NSColor.systemOrange.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8).fill()
            ro.draw(at: NSPoint(x: r.minX + 6, y: r.minY + (16 - rs.height) / 2))
            afterChips = r.maxX
        }
        // "#123 Title · author · base ← head · +a −d"
        let line = NSMutableAttributedString(string: "#\(pr.number)  ", attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .regular), .foregroundColor: DiffStyle.headerText.withAlphaComponent(0.6)])
        line.append(NSAttributedString(string: pr.title, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: DiffStyle.headerText]))
        let meta: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11.5), .foregroundColor: DiffStyle.headerText.withAlphaComponent(0.6)]
        line.append(NSAttributedString(string: "   \(pr.author) · \(pr.baseRefName) ← \(pr.headRefName)", attributes: meta))
        if !pr.labels.isEmpty { line.append(NSAttributedString(string: " · " + pr.labels.joined(separator: ", "), attributes: meta)) }
        let x = afterChips + 10
        let lh = line.size().height
        let rightEdge = [openButton, mergeButton, syncButton, checkoutButton].filter { !$0.isHidden }.map(\.frame.minX).min() ?? bounds.width
        line.draw(with: NSRect(x: x, y: mid - lh / 2, width: rightEdge - 12 - x, height: lh), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard p.y < Self.collapsedHeight else { return }
        expanded.toggle()
        needsDisplay = true
        onToggle?()
    }

    @objc private func openOnGitHub() {
        if let url = pr.flatMap({ URL(string: $0.url) }) { NSWorkspace.shared.open(url) }
    }
}
