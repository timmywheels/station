import AppKit

/// The right-hand panel: this review's comments. (Pull requests have one home, the Pull Requests tab.)
final class SidebarController: NSViewController {
    let comments: CommentsPanel

    init(comments: CommentsPanel) {
        self.comments = comments
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView()
        addChild(comments)
        comments.view.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(comments.view)
        NSLayoutConstraint.activate([
            comments.view.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor, constant: 8),
            comments.view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            comments.view.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            comments.view.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        view = root
    }
}
