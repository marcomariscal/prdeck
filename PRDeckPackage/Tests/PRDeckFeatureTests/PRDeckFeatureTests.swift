import Testing
@testable import PRDeckFeature

import Foundation

@Test func needsAttention_whenMergeConflict() async throws {
    let item = PRItem(
        id: "1",
        number: 1,
        title: "Test",
        url: URL(string: "https://example.com/pull/1")!,
        updatedAt: .now,
        isDraft: false,
        mergeable: .conflicting,
        reviewDecision: nil,
        author: nil,
        repository: .init(nameWithOwner: "a/b", url: URL(string: "https://example.com")!),
        statusCheckRollup: nil,
        isReviewRequestedToMe: false
    )

    #expect(item.needsAttention == true)
}

@Test func needsAttention_whenCIFailed() async throws {
    let rollup = PRItem.StatusCheckRollup(
        state: .failure,
        contexts: .init(nodes: [])
    )

    let item = PRItem(
        id: "1",
        number: 1,
        title: "Test",
        url: URL(string: "https://example.com/pull/1")!,
        updatedAt: .now,
        isDraft: false,
        mergeable: .mergeable,
        reviewDecision: nil,
        author: nil,
        repository: .init(nameWithOwner: "a/b", url: URL(string: "https://example.com")!),
        statusCheckRollup: rollup,
        isReviewRequestedToMe: false
    )

    #expect(item.ciState == .failed)
    #expect(item.needsAttention == true)
}

@Test func failingCheckURL_prefersFirstFailingCheckRunOrStatusContext() async throws {
    let failingRun = PRItem.StatusCheckRollup.CheckRun(
        name: "build",
        conclusion: "FAILURE",
        status: "COMPLETED",
        detailsUrl: URL(string: "https://example.com/check/1")!
    )

    let failingStatus = PRItem.StatusCheckRollup.StatusContext(
        context: "ci",
        state: "FAILURE",
        targetUrl: URL(string: "https://example.com/status/1")!
    )

    let rollup = PRItem.StatusCheckRollup(
        state: .failure,
        contexts: .init(nodes: [
            .checkRun(failingRun),
            .statusContext(failingStatus),
        ])
    )

    let item = PRItem(
        id: "1",
        number: 1,
        title: "Test",
        url: URL(string: "https://example.com/pull/1")!,
        updatedAt: .now,
        isDraft: false,
        mergeable: .mergeable,
        reviewDecision: nil,
        author: nil,
        repository: .init(nameWithOwner: "a/b", url: URL(string: "https://example.com")!),
        statusCheckRollup: rollup,
        isReviewRequestedToMe: false
    )

    #expect(item.failingCheckURL == URL(string: "https://example.com/check/1")!)
}

@Test func needsAttention_whenReviewRequestedToMe() async throws {
    let item = PRItem(
        id: "1",
        number: 1,
        title: "Test",
        url: URL(string: "https://example.com/pull/1")!,
        updatedAt: .now,
        isDraft: false,
        mergeable: .mergeable,
        reviewDecision: nil,
        author: nil,
        repository: .init(nameWithOwner: "a/b", url: URL(string: "https://example.com")!),
        statusCheckRollup: nil,
        isReviewRequestedToMe: true
    )

    #expect(item.needsAttention == true)
}

@Test func needsAttention_whenChangesRequested() async throws {
    let item = PRItem(
        id: "1",
        number: 1,
        title: "Test",
        url: URL(string: "https://example.com/pull/1")!,
        updatedAt: .now,
        isDraft: false,
        mergeable: .mergeable,
        reviewDecision: .changesRequested,
        author: nil,
        repository: .init(nameWithOwner: "a/b", url: URL(string: "https://example.com")!),
        statusCheckRollup: nil,
        isReviewRequestedToMe: false
    )

    #expect(item.needsAttention == true)
}

@Test func prdeckDecoder_parsesISO8601WithoutFractionalSeconds() async throws {
    struct Wrapper: Decodable {
        let updatedAt: Date
    }

    let json = #"{"updatedAt":"2026-01-05T20:25:27Z"}"#.data(using: .utf8)!
    let decoded = try JSONDecoder.prdeck.decode(Wrapper.self, from: json)
    #expect(decoded.updatedAt.timeIntervalSince1970 > 0)
}
