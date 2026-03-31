//
//  InstagramProfileViewModel.swift
//  insta-reels
//
//  Created by Codex on 26/03/26.
//

import Combine
import Foundation

enum InstagramProfileViewState {
    case loading
    case loaded(InstagramProfileScreenModel)
    case failed(String)
}

struct InstagramProfileScreenModel {
    let user: InstagramUser
    let displayName: String
    let stats: [InstagramProfileStat]
    let bioLines: [String]
    let websiteLabel: String
    let websiteURL: URL
    let featuredAudioLabel: String
    let followedBySummary: String
    let followedByUsers: [InstagramUser]
    let highlights: [InstagramProfileHighlight]
    let gridItems: [InstagramProfileGridItem]
    let feedPosts: [InstagramPost]
}

struct InstagramProfileStat: Identifiable {
    let id: String
    let value: String
    let label: String
}

struct InstagramProfileHighlight: Identifiable {
    let id: String
    let title: String
    let imageURL: URL?
}

struct InstagramProfileGridItem: Identifiable {
    let id: String
    let imageURL: URL?
    let overlaySymbol: String?
}

@MainActor
final class InstagramProfileViewModel: ObservableObject {
    @Published private(set) var state: InstagramProfileViewState = .loading

    private let username: String
    private let gridSource: InstagramProfileGridSource
    private let repository: InstagramProfileRepositoryProtocol
    private let bundle: Bundle
    private var hasLoaded = false

    convenience init(
        username: String,
        gridSource: InstagramProfileGridSource = .authoredPosts
    ) {
        self.init(
            username: username,
            gridSource: gridSource,
            repository: InstagramProfileRepository(),
            bundle: .main
        )
    }

    init(
        username: String,
        gridSource: InstagramProfileGridSource,
        repository: InstagramProfileRepositoryProtocol,
        bundle: Bundle = .main
    ) {
        self.username = username
        self.gridSource = gridSource
        self.repository = repository
        self.bundle = bundle
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        hasLoaded = true
        load()
    }

    func load() {
        state = .loading

        do {
            let payload = try repository.fetchProfile(
                username: username,
                gridSource: gridSource,
                in: bundle
            )
            state = .loaded(makeScreenModel(from: payload))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func makeScreenModel(from payload: InstagramProfilePayload) -> InstagramProfileScreenModel {
        let identityPosts = payload.profilePosts
        let gridPosts = payload.gridPosts
        let latestIdentityPost = identityPosts[0]
        let followersCount = gridPosts.reduce(0) { $0 + $1.metrics.reachCount }
        let followingCount = payload.relatedUsers.count
        let topLocations = orderedLocations(from: gridPosts)
        let topHashtags = topHashtags(from: gridPosts)

        return InstagramProfileScreenModel(
            user: payload.user,
            displayName: payload.user.displayName,
            stats: [
                InstagramProfileStat(id: "posts", value: abbreviated(gridPosts.count), label: "posts"),
                InstagramProfileStat(id: "followers", value: abbreviated(followersCount), label: "followers"),
                InstagramProfileStat(id: "following", value: abbreviated(followingCount), label: "following")
            ],
            bioLines: makeBioLines(from: latestIdentityPost, locations: topLocations, hashtags: topHashtags),
            websiteLabel: "instagram.com/\(payload.user.username)",
            websiteURL: URL(string: "https://www.instagram.com/\(payload.user.username)")!,
            featuredAudioLabel: "\(latestIdentityPost.audio.title) • \(latestIdentityPost.audio.artistName)",
            followedBySummary: makeFollowedBySummary(from: payload.relatedUsers),
            followedByUsers: Array(payload.relatedUsers.prefix(3)),
            highlights: makeHighlights(from: gridPosts),
            gridItems: gridPosts.map(makeGridItem(from:)),
            feedPosts: gridPosts
        )
    }

    private func makeBioLines(from latestPost: InstagramPost, locations: [String], hashtags: [String]) -> [String] {
        let headline = firstSentence(in: latestPost.caption)
        let locationLine = locations.prefix(2).joined(separator: " • ")
        let hashtagLine = hashtags.prefix(3).joined(separator: " • ")

        return [headline, locationLine, hashtagLine]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private func makeFollowedBySummary(from users: [InstagramUser]) -> String {
        guard let firstUser = users.first else {
            return ""
        }

        if users.count == 1 {
            return "Followed by \(firstUser.username)"
        }

        if users.count == 2 {
            return "Followed by \(firstUser.username) and \(users[1].username)"
        }

        return "Followed by \(firstUser.username), \(users[1].username) and \(users.count - 2) others"
    }

    private func makeHighlights(from posts: [InstagramPost]) -> [InstagramProfileHighlight] {
        var usedTitles = Set<String>()

        return posts.prefix(5).map { post in
            let baseTitle = highlightTitle(for: post)
            let title = uniquedTitle(baseTitle, seenTitles: &usedTitles)

            return InstagramProfileHighlight(
                id: post.id,
                title: title,
                imageURL: highlightImageURL(for: post)
            )
        }
    }

    private func highlightTitle(for post: InstagramPost) -> String {
        if let locationName = post.locationName {
            return shortLocation(from: locationName)
        }

        if let firstHashtag = post.hashtags.first {
            return prettifyTag(firstHashtag)
        }

        return post.audio.title
    }

    private func uniquedTitle(_ title: String, seenTitles: inout Set<String>) -> String {
        guard seenTitles.insert(title).inserted == false else {
            return title
        }

        var candidateIndex = 2

        while true {
            let candidate = "\(title) \(candidateIndex)"
            if seenTitles.insert(candidate).inserted {
                return candidate
            }

            candidateIndex += 1
        }
    }

    private func makeGridItem(from post: InstagramPost) -> InstagramProfileGridItem {
        InstagramProfileGridItem(
            id: post.id,
            imageURL: gridImageURL(for: post),
            overlaySymbol: overlaySymbol(for: post)
        )
    }

    private func highlightImageURL(for post: InstagramPost) -> URL? {
        post.media.first?.thumbnailURL ?? post.media.first?.mediaURL
    }

    private func gridImageURL(for post: InstagramPost) -> URL? {
        return post.media.first?.thumbnailURL ?? post.media.first?.mediaURL
    }

    private func overlaySymbol(for post: InstagramPost) -> String? {
        if post.media.contains(where: { $0.type == .video }) {
            return "play.fill"
        }

        if post.media.count > 1 {
            return "square.on.square.fill"
        }

        return nil
    }

    private func orderedLocations(from posts: [InstagramPost]) -> [String] {
        var locations: [String] = []
        var seen = Set<String>()

        for locationName in posts.compactMap(\.locationName) {
            let shortName = shortLocation(from: locationName)
            if seen.insert(shortName).inserted {
                locations.append(shortName)
            }
        }

        return locations
    }

    private func topHashtags(from posts: [InstagramPost]) -> [String] {
        var hashtagCounts: [String: Int] = [:]

        for post in posts {
            for hashtag in post.hashtags {
                hashtagCounts[hashtag, default: 0] += 1
            }
        }

        return hashtagCounts
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }

                return $0.value > $1.value
            }
            .map { prettifyTag($0.key) }
    }

    private func firstSentence(in text: String) -> String {
        let sentence = text
            .split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let sentence, sentence.isEmpty == false {
            return sentence
        }

        return text
    }

    private func shortLocation(from location: String) -> String {
        location
            .split(separator: ",", omittingEmptySubsequences: true)
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? location
    }

    private func prettifyTag(_ hashtag: String) -> String {
        let trimmed = hashtag.replacingOccurrences(of: "#", with: "")
        return trimmed.capitalized
    }

    private func abbreviated(_ value: Int) -> String {
        if value < 1_000 {
            return value.formatted()
        }

        return value
            .formatted(
                .number
                    .notation(.compactName)
                    .precision(.fractionLength(0...1))
            )
            .uppercased()
    }
}
