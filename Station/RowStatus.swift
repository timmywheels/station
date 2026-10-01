import StationKit
import StoplightCore

/// A PR row's status in a few words, instead of a row of tags: the most urgent thing first,
/// then at most one more. "Merge conflicts · Waiting for review", "Ready to merge".
/// Ranked by rules, not a language model: the facts are structured, so rules are instant and
/// never drop the one that matters (Apple's on-device model took ~4 s a line and did).
struct RowStatus: Equatable {
    enum Level: Int, Comparable {
        case info, good, waiting, blocking, needsYou // you're the only one who can unblock "needs you"
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }
    struct Part: Equatable { let text: String; let level: Level }
    let parts: [Part]
    /// Set when the headline is an agent: clicking the status goes to it.
    let agent: ReviewContext.Agent?

    var headline: Part? { parts.first }

    /// `reported`: what an agent hook said about this PR ("working", "attention", "done").
    /// `isQueueRow`: the merge queue list, where position is already in the gutter.
    static func of(_ pr: PullRequest, reported: String?, agent: ReviewContext.Agent?, isQueueRow: Bool) -> RowStatus {
        var facts: [Part] = []
        func add(_ text: String, _ level: Level) { facts.append(Part(text: text, level: level)) }
        let needsYou = reported == "attention" || agent?.state == .needsYou

        switch pr.status {
        case .closed:
            return RowStatus(parts: [Part(text: "Closed", level: .info)], agent: nil)
        case .merged:
            if pr.baseState == .failure { add("Merged · \(pr.baseRefName) failing", .blocking) }
            else { add("Merged", .good) }
            return RowStatus(parts: facts, agent: nil)
        case .open:
            break
        }

        if needsYou { add("Agent needs you", .needsYou) }
        if pr.mergeState == .conflicting { add("Merge conflicts", .blocking) }
        if let q = pr.mergeQueue, q.isBlocked { add("Blocked in queue", .blocking) }
        let failing = pr.failingChecks
        if failing.count == 1 { add("\(failing[0].name) failing", .blocking) }
        else if failing.count > 1 { add("\(failing.count) checks failing", .blocking) }
        if pr.review == .changesRequested { add("Changes requested", .blocking) }
        if failing.isEmpty, pr.checks.contains(where: { $0.state == .pending }) { add("Checks running", .waiting) }
        if let q = pr.mergeQueue, !q.isBlocked, !isQueueRow { add("Queue #\(q.position)", .waiting) }
        if pr.isDraft { add("Draft", .info) }
        else if pr.review == .reviewRequired { add("Waiting for review", .waiting) }
        if pr.mergeState == .behind { add("Behind \(pr.baseRefName)", .info) }
        if !needsYou, reported == "working" || agent?.state == .running { add("Agent working", .info) }
        if facts.isEmpty, !pr.isDraft, pr.state != .failure, pr.state != .pending {
            add(pr.review == .approved || pr.review == .none ? "Ready to merge" : "Checks passing", .good)
        }

        // The most urgent first; ties keep the order above, which is how much each one blocks.
        let ranked = facts.enumerated().sorted { a, b in
            a.element.level != b.element.level ? a.element.level > b.element.level : a.offset < b.offset
        }.map(\.element)
        let headlineIsAgent = ranked.first?.text.hasPrefix("Agent") ?? false
        return RowStatus(parts: Array(ranked.prefix(2)), agent: headlineIsAgent ? agent : nil)
    }
}
