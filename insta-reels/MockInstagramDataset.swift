//
//  MockInstagramDataset.swift
//  insta-reels
//
//  Created by Codex on 26/03/26.
//

import Foundation

enum InstagramPostVisibility: String, Codable, Hashable {
    case `public`
    case closeFriends
}

enum InstagramMediaType: String, Codable, Hashable {
    case photo
    case video
}

enum InstagramPostKind: String, Codable, Hashable {
    case post
    case reel
    case carousel
}

struct InstagramUser: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let displayName: String
    let avatarURL: URL
    let isVerified: Bool
    let isPrivate: Bool
}

struct InstagramAudioTrack: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let audioURL: URL
    let coverImageURL: URL
    let duration: TimeInterval
    let isOriginalAudio: Bool
}

struct InstagramMedia: Identifiable, Codable, Hashable {
    let id: String
    let type: InstagramMediaType
    let mediaURL: URL
    let thumbnailURL: URL?
    let width: Int
    let height: Int
    let duration: TimeInterval?
    let altText: String
}

struct InstagramComment: Identifiable, Codable, Hashable {
    let id: String
    let author: InstagramUser
    let text: String
    let createdAt: Date
    let likeCount: Int
    let replyCount: Int
    let isPinned: Bool
}

struct InstagramPostMetrics: Codable, Hashable {
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let saveCount: Int
    let playCount: Int?
    let impressionCount: Int
    let reachCount: Int
}

struct InstagramPost: Identifiable, Codable, Hashable {
    let id: String
    let kind: InstagramPostKind
    let author: InstagramUser
    let collaborators: [InstagramUser]
    let locationName: String?
    let caption: String
    let hashtags: [String]
    let mentions: [String]
    let taggedUsers: [String]
    let media: [InstagramMedia]
    let audio: InstagramAudioTrack
    let metrics: InstagramPostMetrics
    let comments: [InstagramComment]
    let likedByUsernames: [String]
    let createdAt: Date
    let isSponsored: Bool
    let sponsorName: String?
    let allowsComments: Bool
    let isLikedByCurrentUser: Bool
    let isSavedByCurrentUser: Bool
    let visibility: InstagramPostVisibility
}

enum MockInstagramDataset {
    private static let resourceName = "MockInstagramPosts"
    private static let resourceExtension = "json"

    static let posts: [InstagramPost] = loadPosts()

    static let users: [InstagramUser] = {
        var seen = Set<String>()
        var orderedUsers: [InstagramUser] = []

        for post in posts {
            append(post.author, to: &orderedUsers, seen: &seen)

            for collaborator in post.collaborators {
                append(collaborator, to: &orderedUsers, seen: &seen)
            }

            for comment in post.comments {
                append(comment.author, to: &orderedUsers, seen: &seen)
            }
        }

        return orderedUsers
    }()

    static let samplePost: InstagramPost = {
        guard let firstPost = posts.first else {
            fatalError("MockInstagramPosts.json is empty.")
        }

        return firstPost
    }()

    nonisolated static func decodePosts(in bundle: Bundle = .main) throws -> [InstagramPost] {
        guard let resourceURL = locateResource(in: bundle) else {
            throw MockInstagramDatasetError.resourceNotFound(name: resourceName, fileExtension: resourceExtension)
        }

        let data = try Data(contentsOf: resourceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([InstagramPost].self, from: data)
    }

    nonisolated private static func loadPosts() -> [InstagramPost] {
        do {
            return try decodePosts()
        } catch {
            fatalError("Failed to load mock Instagram posts JSON: \(error.localizedDescription)")
        }
    }

    nonisolated private static func locateResource(in bundle: Bundle) -> URL? {
        let candidateBundles = [
            bundle,
            Bundle(for: MockInstagramBundleToken.self)
        ]

        for candidate in candidateBundles {
            if let url = candidate.url(forResource: resourceName, withExtension: resourceExtension) {
                return url
            }
        }

        return nil
    }

    nonisolated private static func append(_ user: InstagramUser, to users: inout [InstagramUser], seen: inout Set<String>) {
        if seen.insert(user.id).inserted {
            users.append(user)
        }
    }
}

private final class MockInstagramBundleToken {}

private enum MockInstagramDatasetError: LocalizedError {
    case resourceNotFound(name: String, fileExtension: String)

    var errorDescription: String? {
        switch self {
        case let .resourceNotFound(name, fileExtension):
            return "Could not find \(name).\(fileExtension) in the app bundle."
        }
    }
}
