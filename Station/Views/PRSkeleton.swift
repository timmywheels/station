import AppKit
import SwiftUI
import StationKit

/// The diff tab's loading look for pull requests: shimmering rows and a caption, until GitHub answers.
struct PRSkeleton: NSViewRepresentable {
    var caption: String? = "Getting your pull requests from GitHub…"

    func makeNSView(context: Context) -> SkeletonView {
        let view = SkeletonView(.pullRequests)
        view.plateColor = .windowBackgroundColor
        return view
    }

    func updateNSView(_ view: SkeletonView, context: Context) { view.set(caption: caption) }
}
