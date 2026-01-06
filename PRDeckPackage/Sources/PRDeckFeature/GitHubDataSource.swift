import Foundation

struct GitHubDataSourceError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

public struct GitHubDataSource: Sendable {
    public init() {}

    public func fetchAll() async throws -> [PRItem] {
        async let authored = fetch(searchQuery: "is:pr is:open author:@me", reviewRequestedToMe: false)
        async let requested = fetch(searchQuery: "is:pr is:open review-requested:@me", reviewRequestedToMe: true)

        let (a, b) = try await (authored, requested)

        var merged: [PRItem.ID: PRItem] = [:]
        for item in a { merged[item.id] = item }
        for item in b {
            if var existing = merged[item.id] {
                existing.isReviewRequestedToMe = true
                merged[item.id] = existing
            } else {
                merged[item.id] = item
            }
        }
        return Array(merged.values)
    }

    private func fetch(searchQuery: String, reviewRequestedToMe: Bool) async throws -> [PRItem] {
        guard let ghPath = ProcessRunner.findExecutable(named: "gh") else {
            throw GitHubDataSourceError(message: "GitHub CLI (`gh`) not found. Install it and run `gh auth login`.")
        }

        var all: [PRItem] = []
        var endCursor: String?
        var pages = 0

        while pages < 5, all.count < 500 {
            pages += 1
            let page = try await fetchPage(
                ghPath: ghPath,
                searchQuery: searchQuery,
                endCursor: endCursor,
                reviewRequestedToMe: reviewRequestedToMe
            )

            all.append(contentsOf: page.items)

            guard page.pageInfo.hasNextPage, let next = page.pageInfo.endCursor else {
                break
            }
            endCursor = next
        }

        return all
    }

    private func fetchPage(
        ghPath: String,
        searchQuery: String,
        endCursor: String?,
        reviewRequestedToMe: Bool
    ) async throws -> (items: [PRItem], pageInfo: PageInfo) {
        let query = Self.graphQLQuery

        var args: [String] = [
            "api", "graphql",
            "-f", "query=\(query)",
            "-F", "searchQuery=\(searchQuery)",
        ]

        if let endCursor {
            args.append(contentsOf: ["-F", "endCursor=\(endCursor)"])
        } else {
            args.append(contentsOf: ["-F", "endCursor=null"])
        }

        let data = try await ProcessRunner.run(ghPath, arguments: args)
        let decoder = JSONDecoder.prdeck
        let response: GraphQLResponse
        do {
            response = try decoder.decode(GraphQLResponse.self, from: data)
        } catch {
            let preview = String(data: data, encoding: .utf8).map { String($0.prefix(400)) } ?? "<non-utf8 response>"
            throw GitHubDataSourceError(message: "Failed to decode GitHub response: \(error)\n\nOutput:\n\(preview)")
        }

        if let errors = response.errors, !errors.isEmpty, response.data == nil {
            throw GitHubDataSourceError(message: errors.map(\.message).joined(separator: "\n"))
        }

        let search = response.data?.search
        let nodes = search?.nodes ?? []
        let pageInfo = search?.pageInfo ?? .init(hasNextPage: false, endCursor: nil)

        let items = nodes
            .compactMap { $0 }
            .map { node in
                PRItem(
                    id: node.id,
                    number: node.number,
                    title: node.title,
                    url: node.url,
                    updatedAt: node.updatedAt,
                    isDraft: node.isDraft,
                    mergeable: node.mergeable,
                    mergeStateStatus: node.mergeStateStatus,
                    reviewDecision: node.reviewDecision,
                    author: node.author.map { .init(login: $0.login, avatarUrl: $0.avatarUrl) },
                    repository: .init(
                        nameWithOwner: node.repository.nameWithOwner,
                        url: node.repository.url,
                        ownerLogin: node.repository.owner.login,
                        ownerAvatarUrl: node.repository.owner.avatarUrl
                    ),
                    statusCheckRollup: node.statusCheckRollup,
                    isReviewRequestedToMe: reviewRequestedToMe
                )
            }

        return (items, pageInfo)
    }
}

private extension GitHubDataSource {
    static let graphQLQuery =
    #"""
	    query($searchQuery: String!, $endCursor: String) {
	      search(query: $searchQuery, type: ISSUE, first: 100, after: $endCursor) {
	        pageInfo { hasNextPage endCursor }
	        nodes {
	          ... on PullRequest {
	            id
	            number
	            title
	            url
	            updatedAt
	            isDraft
	            mergeable
	            mergeStateStatus
	            reviewDecision
	            author { login avatarUrl }
	            repository { nameWithOwner url owner { login avatarUrl } }
	            commits(last: 1) {
	              nodes {
	                commit {
	                  statusCheckRollup {
	                    state
	                    contexts(first: 50) {
	                      nodes {
	                        __typename
	                        ... on CheckRun {
	                          name
	                          conclusion
	                          status
	                          detailsUrl
	                        }
	                        ... on StatusContext {
	                          context
	                          state
	                          targetUrl
	                        }
	                      }
	                    }
	                  }
	                }
	              }
	            }
	          }
	        }
	      }
	    }
	    """#
}

private struct GraphQLResponse: Decodable {
    let data: GraphQLData?
    let errors: [GraphQLError]?
}

private struct GraphQLData: Decodable {
    let search: GraphQLSearch?
}

private struct GraphQLSearch: Decodable {
    let pageInfo: PageInfo
    let nodes: [PullRequestNode?]
}

private struct GraphQLError: Decodable {
    let message: String
}

private struct PageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor: String?
}

	private struct PullRequestNode: Decodable {
	    let id: String
	    let number: Int
	    let title: String
	    let url: URL
	    let updatedAt: Date
	    let isDraft: Bool
	    let mergeable: PRItem.Mergeable?
	    let mergeStateStatus: PRItem.MergeStateStatus?
	    let reviewDecision: PRItem.ReviewDecision?
	    let author: AuthorNode?
	    let repository: RepoNode
	    let commits: CommitsNode

    var statusCheckRollup: PRItem.StatusCheckRollup? {
        commits.nodes.first?.commit.statusCheckRollup
    }
}

private struct AuthorNode: Decodable {
    let login: String
    let avatarUrl: URL?
}

private struct RepoNode: Decodable {
    let nameWithOwner: String
    let url: URL
    let owner: RepoOwnerNode
}

private struct RepoOwnerNode: Decodable {
    let login: String
    let avatarUrl: URL?
}

private struct CommitsNode: Decodable {
    let nodes: [CommitNode]
}

private struct CommitNode: Decodable {
    let commit: Commit
}

private struct Commit: Decodable {
    let statusCheckRollup: PRItem.StatusCheckRollup?
}
