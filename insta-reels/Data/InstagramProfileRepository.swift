//
//  InstagramProfileRepository.swift
//  insta-reels
//
//  Created by Codex on 26/03/26.
//

import Foundation

enum InstagramProfileGridSource {
    case authoredPosts
    case allPosts
}

protocol InstagramProfileRepositoryProtocol {
    nonisolated func fetchProfile(
        username: String,
        gridSource: InstagramProfileGridSource,
        in bundle: Bundle
    ) throws -> InstagramProfilePayload
}

struct InstagramProfilePayload {
    let user: InstagramUser
    let profilePosts: [InstagramPost]
    let gridPosts: [InstagramPost]
    let relatedUsers: [InstagramUser]
}

struct InstagramProfileRepository: InstagramProfileRepositoryProtocol {
    nonisolated func fetchProfile(
        username: String,
        gridSource: InstagramProfileGridSource,
        in bundle: Bundle = .main
    ) throws -> InstagramProfilePayload {
        let posts = try MockInstagramDataset.decodePosts(in: bundle)
        let allPosts = posts
            .sorted { $0.createdAt > $1.createdAt }
        let profilePosts = allPosts
            .filter { $0.author.username == username }

        guard let user = profilePosts.first?.author else {
            throw InstagramProfileRepositoryError.profileNotFound(username)
        }

        let userDirectory = buildUserDirectory(from: allPosts)
        let gridPosts: [InstagramPost]

        switch gridSource {
        case .authoredPosts:
            gridPosts = profilePosts
        case .allPosts:
            gridPosts = allPosts
        }

        let relatedUsers = buildRelatedUsers(
            excluding: user.username,
            from: gridPosts,
            userDirectory: userDirectory
        )

        return InstagramProfilePayload(
            user: user,
            profilePosts: profilePosts,
            gridPosts: gridPosts,
            relatedUsers: relatedUsers
        )
    }

    nonisolated private func buildUserDirectory(from posts: [InstagramPost]) -> [String: InstagramUser] {
        var usersByUsername: [String: InstagramUser] = [:]

        for post in posts {
            usersByUsername[post.author.username] = post.author

            for collaborator in post.collaborators {
                usersByUsername[collaborator.username] = collaborator
            }

            for comment in post.comments {
                usersByUsername[comment.author.username] = comment.author
            }
        }

        return usersByUsername
    }

    nonisolated private func buildRelatedUsers(
        excluding username: String,
        from posts: [InstagramPost],
        userDirectory: [String: InstagramUser]
    ) -> [InstagramUser] {
        var orderedUsernames: [String] = []
        var seenUsernames = Set<String>()

        for post in posts {
            append(post.likedByUsernames, excluding: username, to: &orderedUsernames, seen: &seenUsernames)
            append(post.taggedUsers, excluding: username, to: &orderedUsernames, seen: &seenUsernames)
            append(post.mentions, excluding: username, to: &orderedUsernames, seen: &seenUsernames)
            append(post.collaborators.map(\.username), excluding: username, to: &orderedUsernames, seen: &seenUsernames)
            append(post.comments.map(\.author.username), excluding: username, to: &orderedUsernames, seen: &seenUsernames)
        }

        return orderedUsernames.compactMap { userDirectory[$0] }
    }

    nonisolated private func append(
        _ usernames: [String],
        excluding profileUsername: String,
        to orderedUsernames: inout [String],
        seen: inout Set<String>
    ) {
        for username in usernames where username != profileUsername {
            if seen.insert(username).inserted {
                orderedUsernames.append(username)
            }
        }
    }
}

enum InstagramProfileRepositoryError: LocalizedError {
    case profileNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .profileNotFound(username):
            return "No posts were found for @\(username) in the bundled JSON dataset."
        }
    }
}
