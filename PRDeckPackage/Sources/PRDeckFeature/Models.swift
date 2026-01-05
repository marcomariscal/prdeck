import Foundation

public struct PRItem: Identifiable, Codable, Hashable, Sendable {
    public struct Author: Codable, Hashable, Sendable {
        public let login: String
        public let avatarUrl: URL?

        public init(login: String, avatarUrl: URL?) {
            self.login = login
            self.avatarUrl = avatarUrl
        }
    }

    public struct Repository: Codable, Hashable, Sendable {
        public let nameWithOwner: String
        public let url: URL

        public init(nameWithOwner: String, url: URL) {
            self.nameWithOwner = nameWithOwner
            self.url = url
        }
    }

    public enum Mergeable: String, Codable, Sendable {
        case mergeable = "MERGEABLE"
        case conflicting = "CONFLICTING"
        case unknown = "UNKNOWN"
    }

    public enum ReviewDecision: String, Codable, Sendable {
        case approved = "APPROVED"
        case changesRequested = "CHANGES_REQUESTED"
        case reviewRequired = "REVIEW_REQUIRED"
    }

    public enum CIState: String, Codable, Sendable {
        case none
        case running
        case success
        case failed
        case unknown
    }

    public struct StatusCheckRollup: Codable, Hashable, Sendable {
        public enum State: String, Codable, Sendable {
            case error = "ERROR"
            case expected = "EXPECTED"
            case failure = "FAILURE"
            case pending = "PENDING"
            case success = "SUCCESS"
        }

        public struct Contexts: Codable, Hashable, Sendable {
            public let nodes: [ContextNode]
        }

        public enum ContextNode: Codable, Hashable, Sendable {
            case checkRun(CheckRun)
            case statusContext(StatusContext)
            case unknown

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = (try? container.decode(String.self, forKey: .typename)) ?? ""
                switch type {
                case "CheckRun":
                    self = .checkRun(try CheckRun(from: decoder))
                case "StatusContext":
                    self = .statusContext(try StatusContext(from: decoder))
                default:
                    self = .unknown
                }
            }

            public func encode(to encoder: Encoder) throws {
                switch self {
                case .checkRun(let value):
                    try value.encode(to: encoder)
                case .statusContext(let value):
                    try value.encode(to: encoder)
                case .unknown:
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode("Unknown", forKey: .typename)
                }
            }

            private enum CodingKeys: String, CodingKey {
                case typename = "__typename"
            }
        }

        public struct CheckRun: Codable, Hashable, Sendable {
            public let name: String
            public let conclusion: String?
            public let status: String?
            public let detailsUrl: URL?
        }

        public struct StatusContext: Codable, Hashable, Sendable {
            public let context: String
            public let state: String?
            public let targetUrl: URL?
        }

        public let state: State?
        public let contexts: Contexts?
    }

    public let id: String
    public let number: Int
    public let title: String
    public let url: URL
    public let updatedAt: Date
    public let isDraft: Bool
    public let mergeable: Mergeable?
    public let reviewDecision: ReviewDecision?
    public let author: Author?
    public let repository: Repository
    public let statusCheckRollup: StatusCheckRollup?
    public var isReviewRequestedToMe: Bool

    public init(
        id: String,
        number: Int,
        title: String,
        url: URL,
        updatedAt: Date,
        isDraft: Bool,
        mergeable: Mergeable?,
        reviewDecision: ReviewDecision?,
        author: Author?,
        repository: Repository,
        statusCheckRollup: StatusCheckRollup?,
        isReviewRequestedToMe: Bool
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.url = url
        self.updatedAt = updatedAt
        self.isDraft = isDraft
        self.mergeable = mergeable
        self.reviewDecision = reviewDecision
        self.author = author
        self.repository = repository
        self.statusCheckRollup = statusCheckRollup
        self.isReviewRequestedToMe = isReviewRequestedToMe
    }
}

public extension PRItem {
    var mergeConflict: Bool { mergeable == .conflicting }

    var ciState: CIState {
        guard let state = statusCheckRollup?.state else { return .none }
        switch state {
        case .failure, .error:
            return .failed
        case .pending, .expected:
            return .running
        case .success:
            return .success
        }
    }

    var failingCheckURL: URL? {
        guard let nodes = statusCheckRollup?.contexts?.nodes else { return nil }

        for node in nodes {
            switch node {
            case .checkRun(let run):
                guard
                    let conclusion = run.conclusion?.uppercased(),
                    ["FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED"].contains(conclusion),
                    let url = run.detailsUrl
                else { continue }
                return url
            case .statusContext(let ctx):
                guard
                    let state = ctx.state?.uppercased(),
                    ["FAILURE", "ERROR"].contains(state),
                    let url = ctx.targetUrl
                else { continue }
                return url
            case .unknown:
                continue
            }
        }

        return nil
    }

    var needsAttention: Bool {
        mergeConflict
        || ciState == .failed
        || isReviewRequestedToMe
        || reviewDecision == .changesRequested
    }
}
