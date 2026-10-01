import AppKit
import StoplightCore

/// Menu bar image: three horizontal status dots (US-004).
/// A dot is lit when at least one PR is in that state, dim otherwise. Drawn directly with AppKit.
enum StatusGlyph {
    static let dot: CGFloat = 6
    static let gap: CGFloat = 3
    static let height: CGFloat = 18

    static let housingPad: CGFloat = 4

    /// The optional fourth light, after a divider: your agents. Off (nil) is plain Stoplight.
    enum AgentLight: Equatable {
        case idle, working, needsYou(Int)
    }
    static let dividerGap: CGFloat = 4

    /// - housing: draw a dark rounded pill behind the dots (🚥 style) for contrast on busy wallpapers.
    /// - agents: the agent light (Settings → Display), or nil for the three dots alone.
    static func image(for presence: StatusPresence, count: Int?, pop: CGFloat = 0, housing: Bool = false,
                      agents: AgentLight? = nil, colorProfile: ColorProfile = .standard) -> NSImage {
        let pad: CGFloat = housing ? housingPad : 0
        let agentWidth = agents == nil ? 0 : dividerGap * 2 + 1 + dot
        let width = dot * 3 + gap * 2 + agentWidth + pad * 2
        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            if housing {
                let pill = NSRect(x: 0, y: (height - (dot + pad * 2)) / 2, width: width, height: dot + pad * 2)
                NSColor(white: 0.22, alpha: 1).setFill()
                NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
            }
            let dim = housing ? NSColor(white: 1, alpha: 0.28) : NSColor.secondaryLabelColor.withAlphaComponent(0.35)
            let lights: [(on: Bool, color: NSColor, pop: CGFloat)] = [
                (presence.failure, colorProfile.nsColor(for: .failure), 0),
                (presence.pending, colorProfile.nsColor(for: .pending), 0),
                (presence.success, colorProfile.nsColor(for: .success), pop),
            ]
            var x = pad
            for light in lights {
                let grow = light.on ? light.pop : 0
                let rect = NSRect(x: x - grow / 2, y: (height - dot) / 2 - grow / 2, width: dot + grow, height: dot + grow)
                (light.on ? light.color : dim).setFill()
                NSBezierPath(ovalIn: rect).fill()
                x += dot + gap
            }
            if let agents {
                // A hairline, then the agent light: its own little section.
                x += dividerGap - gap
                dim.setFill()
                NSRect(x: x, y: (height - dot - 2) / 2, width: 1, height: dot + 2).fill()
                x += 1 + dividerGap
                let color: NSColor = switch agents {
                case .needsYou: .systemOrange
                case .working: .systemBlue
                case .idle: dim
                }
                color.setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: (height - dot) / 2, width: dot, height: dot)).fill()
            }
            return true
        }
        img.isTemplate = false
        let agentWords: String = switch agents {
        case .needsYou(let n)?: n == 1 ? " · an agent needs you" : " · \(n) agents need you"
        case .working?: " · agents working"
        case .idle?, nil: ""
        }
        img.accessibilityDescription = describe(presence) + agentWords
        guard let count else { return img }
        return withBadge(img, text: "\(count)")
    }

    private static func describe(_ p: StatusPresence) -> String {
        var parts: [String] = []
        if p.failure { parts.append("failing") }
        if p.pending { parts.append("running") }
        if p.success { parts.append("passing") }
        return parts.isEmpty ? "No PRs" : "PRs " + parts.joined(separator: ", ")
    }

    private static func withBadge(_ img: NSImage, text: String) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        let str = NSAttributedString(string: text, attributes: attrs)
        let textSize = str.size()
        let size = NSSize(width: img.size.width + 4 + textSize.width, height: max(img.size.height, textSize.height))
        let out = NSImage(size: size, flipped: false) { rect in
            img.draw(in: NSRect(x: 0, y: (rect.height - img.size.height) / 2, width: img.size.width, height: img.size.height))
            str.draw(at: NSPoint(x: img.size.width + 4, y: (rect.height - textSize.height) / 2))
            return true
        }
        out.isTemplate = false
        return out
    }
}
