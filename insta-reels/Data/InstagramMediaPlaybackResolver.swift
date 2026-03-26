//
//  InstagramMediaPlaybackResolver.swift
//  insta-reels
//
//  Created by Codex on 27/03/26.
//

import Foundation

protocol InstagramMediaPlaybackResolving {
    func playbackURL(for media: InstagramMedia) -> URL?
}

struct InstagramMediaPlaybackResolver: InstagramMediaPlaybackResolving {
    private static let mockVideoFallbackURL = URL(
        string: "https://tungsten.aaplimg.com/VOD/bipbop_adv_fmp4_example/master.m3u8"
    )

    func playbackURL(for media: InstagramMedia) -> URL? {
        guard media.type == .video else {
            return media.mediaURL
        }

        if media.mediaURL.host != "cdn.insta-reels.dev" {
            return media.mediaURL
        }

        return Self.mockVideoFallbackURL
    }
}
