import XCTest
@testable import StoplightCore

final class SearchTests: XCTestCase {
    private func pr(_ id: String, title: String, repo: String = "acme/api", author: String = "bob", branch: String = "feat/x",
                    state: CheckState = .success, draft: Bool = false, status: PRStatus = .open, number: Int = 1) -> PullRequest {
        PullRequest(id: id, repo: repo, number: number, title: title, url: URL(string: "https://github.com/\(repo)/pull/\(number)")!,
                    isDraft: draft, updatedAt: .now, headSha: "s", checks: [CheckResult(name: "ci", state: state, url: nil)],
                    author: author, status: status, headRefName: branch)
    }
    private let ctx = SearchQuery.Context(names: { $0 == "dholliday3" ? ["Daniel Holliday", "Daniel"] : [] },
                                          nickname: { $0 == "n" ? "the big one" : nil }, myLogin: "tim")

    func testBareWordsMatchTitleAndNickname() {
        XCTAssertTrue(SearchQuery("deploy").matches(pr("a", title: "Fix deploy"), ctx))
        XCTAssertTrue(SearchQuery("big").matches(pr("n", title: "unrelated"), ctx))
        XCTAssertFalse(SearchQuery("deploy web").matches(pr("a", title: "Fix deploy"), ctx))
    }

    func testAuthorMatchesLoginDisplayNameAndLabel() {
        let dan = pr("d", title: "t", author: "dholliday3")
        XCTAssertTrue(SearchQuery("author:dan").matches(dan, ctx))
        XCTAssertTrue(SearchQuery("author:@dholl").matches(dan, ctx))
        XCTAssertFalse(SearchQuery("author:tim").matches(dan, ctx))
    }

    func testPastedLinkFindsThatPR() {
        let target = pr("t", title: "t", repo: "acme/api", number: 439)
        let link = SearchQuery("https://github.com/acme/api/pull/439/files#diff-1")
        XCTAssertTrue(link.matches(target, ctx))
        XCTAssertFalse(link.matches(pr("o", title: "t", repo: "acme/web", number: 439), ctx))
        XCTAssertFalse(link.matches(pr("n", title: "t", repo: "acme/api", number: 12), ctx))
        XCTAssertEqual(link.pullRequest?.key, "acme/api#439")
        XCTAssertTrue(SearchQuery("acme/api#439").matches(target, ctx))
        XCTAssertNil(SearchQuery("deploy #439").pullRequest)
    }

    func testFlagsAndNumbers() {
        let red = pr("r", title: "t", state: .failure, number: 439)
        XCTAssertTrue(SearchQuery("is:red").matches(red, ctx))
        XCTAssertFalse(SearchQuery("is:green").matches(red, ctx))
        XCTAssertTrue(SearchQuery("#439").matches(red, ctx))
        XCTAssertTrue(SearchQuery("439").matches(red, ctx))
        XCTAssertTrue(SearchQuery("is:mine").matches(pr("m", title: "t", author: "tim"), ctx))
        XCTAssertTrue(SearchQuery("is:draft repo:api").matches(pr("x", title: "t", draft: true), ctx))
        XCTAssertTrue(SearchQuery("is:bogus").matches(red, ctx))  // unknown flags are ignored, not fatal
    }

    private func open(_ id: String, state: CheckState = .success, review: ReviewDecision = .none, merge: MergeState = .clean,
                      draft: Bool = false, queue: MergeQueueInfo? = nil) -> PullRequest {
        PullRequest(id: id, repo: "acme/api", number: 1, title: id, url: URL(string: "https://github.com/acme/api/pull/1")!,
                    isDraft: draft, updatedAt: .now, headSha: "s", checks: [CheckResult(name: "ci", state: state, url: nil)],
                    mergeQueue: queue, mergeState: merge, review: review)
    }

    func testReviewAndMergeFlags() {
        XCTAssertTrue(SearchQuery("is:approved").matches(open("a", review: .approved), ctx))
        XCTAssertFalse(SearchQuery("is:approved").matches(open("b", review: .reviewRequired), ctx))
        XCTAssertTrue(SearchQuery("is:changes").matches(open("c", review: .changesRequested), ctx))
        XCTAssertTrue(SearchQuery("is:review").matches(open("r", review: .reviewRequired), ctx))
        XCTAssertTrue(SearchQuery("is:conflicts").matches(open("x", merge: .conflicting), ctx))
        XCTAssertTrue(SearchQuery("is:behind").matches(open("y", merge: .behind), ctx))
    }

    func testReadyMeansNothingInTheWayOfMerging() {
        XCTAssertTrue(SearchQuery("is:ready").matches(open("ok", review: .approved), ctx))
        XCTAssertTrue(SearchQuery("is:ready").matches(open("no-review-needed"), ctx))
        for blocked in [open("running", state: .pending, review: .approved), open("red", state: .failure, review: .approved),
                        open("unreviewed", review: .reviewRequired), open("changes", review: .changesRequested),
                        open("conflicts", review: .approved, merge: .conflicting), open("behind", review: .approved, merge: .behind),
                        open("draft", review: .approved, draft: true),
                        open("queued", review: .approved, queue: MergeQueueInfo(position: 1, state: "QUEUED"))] {
            XCTAssertFalse(SearchQuery("is:ready").matches(blocked, ctx), blocked.id)
        }
    }

    func testMinusHidesMatches() {
        let draft = pr("d", title: "Spike: caching", draft: true), real = pr("r", title: "Fix deploy", repo: "acme/web")
        XCTAssertFalse(SearchQuery("-is:draft").matches(draft, ctx))
        XCTAssertTrue(SearchQuery("-is:draft").matches(real, ctx))
        XCTAssertFalse(SearchQuery("-repo:web").matches(real, ctx))
        XCTAssertFalse(SearchQuery("-spike").matches(draft, ctx))
        XCTAssertTrue(SearchQuery("deploy -is:draft").matches(real, ctx))
        XCTAssertTrue(SearchQuery("-is:typo").matches(draft, ctx))  // an unknown flag hides nothing
        XCTAssertTrue(SearchQuery("-").matches(draft, ctx))
    }

    func testSuggestionsAndCompletion() {
        let prs = [pr("d", title: "t", author: "dholliday3"), pr("b", title: "t", repo: "acme/web", author: "bob")]
        XCTAssertEqual(SearchQuery.suggestions(for: "", prs: prs, ctx).map(\.insert), SearchQuery.prefixes)
        XCTAssertEqual(SearchQuery.suggestions(for: "author:dan", prs: prs, ctx).map(\.insert), ["author:dholliday3"])
        XCTAssertEqual(SearchQuery.suggestions(for: "is:re", prs: prs, ctx).map(\.label), ["red", "green", "ready", "review"])
        XCTAssertEqual(Set(SearchQuery.suggestions(for: "repo:", prs: prs, ctx).map(\.label)), ["api", "web"])
        XCTAssertEqual(SearchQuery.complete("is:red auth", with: "author:"), "is:red author:")
        XCTAssertEqual(SearchQuery.complete("author:dan", with: "author:dholliday3"), "author:dholliday3 ")
    }
}
