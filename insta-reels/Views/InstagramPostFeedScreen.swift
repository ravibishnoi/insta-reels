//
//  InstagramPostFeedScreen.swift
//  insta-reels
//
//  Created by Codex on 26/03/26.
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

struct InstagramFeedTransitionContent: Equatable {
    let postID: String
    let media: InstagramMedia
}

struct InstagramPostFeedScreen: View {
    let title: String
    let posts: [InstagramPost]
    let initialPostID: String
    @Binding var visiblePostID: String?
    @Binding var visibleTransitionContent: InstagramFeedTransitionContent?
    @Binding var visibleTransitionFrame: CGRect?
    let onClose: () -> Void
    var contentOpacity: Double = 1
    var chromeOpacity: Double = 1
    var backgroundOpacity: Double = 1
    var isInteractionEnabled = true
    var isPresented = false
    var presentationSequence = 0

    private let backgroundColor = Color.black
    private let secondaryTextColor = Color(red: 168.0 / 255.0, green: 173.0 / 255.0, blue: 184.0 / 255.0)
    private let dividerColor = Color.white.opacity(0.08)
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                backgroundColor
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 26) {
                            ForEach(posts) { post in
                                InstagramPostFeedCard(
                                    post: post,
                                    isCurrentVisible: visiblePostID == post.id,
                                    chromeOpacity: chromeOpacity,
                                    visibleTransitionContent: $visibleTransitionContent,
                                    visibleTransitionFrame: $visibleTransitionFrame
                                )
                                    .id(post.id)
                                    .background {
                                        GeometryReader { geometry in
                                            Color.clear.preference(
                                                key: FeedPostOffsetPreferenceKey.self,
                                                value: [post.id: geometry.frame(in: .named("feedScroll")).minY]
                                            )
                                        }
                                    }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        topBar
                            .opacity(chromeOpacity)
                    }
                    .coordinateSpace(name: "feedScroll")
                    .scrollIndicators(.hidden)
                    .opacity(contentOpacity)
                    .allowsHitTesting(isPresented && isInteractionEnabled)
                    .onAppear {
                        guard isPresented else {
                            return
                        }

                        scrollToInitialPost(using: proxy)
                    }
                    .onChange(of: presentationSequence) { _, _ in
                        guard isPresented else {
                            return
                        }

                        scrollToInitialPost(using: proxy)
                    }
                    .onChange(of: isPresented) { _, newValue in
                        guard newValue else {
                            visibleTransitionFrame = nil
                            return
                        }

                        scrollToInitialPost(using: proxy)
                    }
                    .onPreferenceChange(FeedPostOffsetPreferenceKey.self) { offsets in
                        guard isPresented else {
                            return
                        }

                        guard let closestPostID = currentVisiblePostID(
                            from: offsets,
                            viewportHeight: geometry.size.height,
                            topInset: feedTopInset
                        ) else {
                            return
                        }

                        if visiblePostID != closestPostID {
                            visiblePostID = closestPostID
                        }
                    }
                    .onPreferenceChange(FeedVisibleMediaFramePreferenceKey.self) { frames in
                        guard isPresented else {
                            return
                        }

                        if let visiblePostID, let frame = frames[visiblePostID] {
                            visibleTransitionFrame = frame
                        } else {
                            visibleTransitionFrame = frames.values.first
                        }
                    }
                }
            }
            .simultaneousGesture(edgeBackSwipeGesture)
        }
    }

    private func currentVisiblePostID(from offsets: [String: CGFloat], viewportHeight: CGFloat, topInset: CGFloat) -> String? {
        let visibleOffsets = offsets.filter { _, minY in
            minY < viewportHeight && minY > -viewportHeight
        }

        return visibleOffsets.min { lhs, rhs in
            abs(lhs.value - topInset) < abs(rhs.value - topInset)
        }?.key
    }

    private func scrollToInitialPost(using proxy: ScrollViewProxy) {
        visiblePostID = initialPostID

        DispatchQueue.main.async {
            proxy.scrollTo(initialPostID, anchor: .top)
        }
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)

//                    Text("\(posts.count.formatted()) posts")
//                        .font(.system(size: 13, weight: .medium))
//                        .foregroundStyle(secondaryTextColor)
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
        }
        .background(backgroundColor.opacity(0.97))
    }

    private var feedTopInset: CGFloat { 78 }

    private var edgeBackSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                let startedFromEdge = value.startLocation.x < 36
                let movedMostlyHorizontally = abs(value.translation.width) > abs(value.translation.height)
                let movedFarEnough = value.translation.width > 84

                guard startedFromEdge, movedMostlyHorizontally, movedFarEnough else {
                    return
                }

                onClose()
            }
    }
}

private struct InstagramPostFeedCard: View {
    let post: InstagramPost
    let isCurrentVisible: Bool
    let chromeOpacity: Double
    @Binding var visibleTransitionContent: InstagramFeedTransitionContent?
    @Binding var visibleTransitionFrame: CGRect?

    private let secondaryTextColor = Color(red: 168.0 / 255.0, green: 173.0 / 255.0, blue: 184.0 / 255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .opacity(chromeOpacity)
            mediaPager
            actionRow
                .opacity(chromeOpacity)
            metaSection
                .opacity(chromeOpacity)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            FeedCircularAsyncImage(url: post.author.avatarURL)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.author.username)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    if post.author.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.0, green: 149.0 / 255.0, blue: 246.0 / 255.0))
                    }
                }

                if let locationName = post.locationName {
                    Text(locationName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }
            }

            Spacer()

            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var mediaPager: some View {
        FeedMediaPager(
            post: post,
            isCurrentVisible: isCurrentVisible,
            visibleTransitionContent: $visibleTransitionContent,
            visibleTransitionFrame: $visibleTransitionFrame
        )
    }

    private var actionRow: some View {
        HStack {
            HStack(spacing: 16) {
                Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                    .foregroundStyle(post.isLikedByCurrentUser ? .red : .white)
                Image(systemName: "bubble.right")
                Image(systemName: "paperplane")
            }
            .font(.system(size: 22, weight: .regular))

            Spacer()

            Image(systemName: post.isSavedByCurrentUser ? "bookmark.fill" : "bookmark")
                .font(.system(size: 21, weight: .regular))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
    }

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(post.metrics.likeCount.formatted()) likes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            Text("\(Text(post.author.username).fontWeight(.semibold)) \(Text(post.caption))")
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .lineLimit(3)

            if post.metrics.commentCount > 0 {
                Text("View all \(post.metrics.commentCount.formatted()) comments")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
            }

            if post.isSponsored, let sponsorName = post.sponsorName {
                Text("Sponsored • \(sponsorName)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
            }

            Text(timestampText(for: post.createdAt))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 14)
    }

    private func timestampText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

private struct FeedMediaPager: View {
    let post: InstagramPost
    let isCurrentVisible: Bool
    @Binding var visibleTransitionContent: InstagramFeedTransitionContent?
    @Binding var visibleTransitionFrame: CGRect?

    @State private var selectedPage = 0
    @State private var containerWidth = UIScreen.main.bounds.width

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedPage) {
                ForEach(Array(post.media.enumerated()), id: \.element.id) { index, media in
                    FeedMediaPage(
                        media: media,
                        isActive: selectedPage == index
                    )
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: post.media.count > 1 ? .automatic : .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.18), value: selectedPage)

            if post.media.count > 1 {
                Text("\(selectedPage + 1)/\(post.media.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: mediaHeight)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        updateContainerWidth(geometry.size.width)
                    }
                    .onChange(of: geometry.size.width) { _, newValue in
                        updateContainerWidth(newValue)
                    }
                    .preference(
                        key: FeedVisibleMediaFramePreferenceKey.self,
                        value: isCurrentVisible
                        ? [post.id: geometry.frame(in: .global)]
                        : [:]
                    )
            }
        }
        .clipped()
        .onAppear {
            syncVisibleTransitionContent()
        }
        .onChange(of: selectedPage) { _, _ in
            syncVisibleTransitionContent()
        }
        .onChange(of: isCurrentVisible) { _, _ in
            syncVisibleTransitionContent()
        }
    }

    private var currentAspectRatio: CGFloat {
        let media = post.media[selectedPage]
        let ratio = CGFloat(media.width) / CGFloat(max(media.height, 1))
        return min(max(ratio, 0.5625), 1.0)
    }

    private var mediaHeight: CGFloat {
        containerWidth / currentAspectRatio
    }

    private func updateContainerWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0 else {
            return
        }

        if abs(containerWidth - width) > 0.5 {
            containerWidth = width
        }
    }

    private func syncVisibleTransitionContent() {
        guard isCurrentVisible, post.media.indices.contains(selectedPage) else {
            return
        }

        let content = InstagramFeedTransitionContent(
            postID: post.id,
            media: post.media[selectedPage]
        )

        if visibleTransitionContent != content {
            visibleTransitionContent = content
        }
    }
}

private struct FeedMediaPage: View {
    let media: InstagramMedia
    let isActive: Bool
    private let playbackResolver = InstagramMediaPlaybackResolver()

    var body: some View {
        ZStack {
            Color.black

            FeedRectangularAsyncImage(url: media.thumbnailURL ?? media.mediaURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if media.type == .video, let playbackURL = playbackResolver.playbackURL(for: media) {
                FeedInlineVideoPlayer(
                    url: playbackURL,
                    isActive: isActive
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if media.type == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .clipped()
        .accessibilityLabel(media.altText)
    }
}

private struct FeedInlineVideoPlayer: View {
    let url: URL
    let isActive: Bool

    @StateObject private var playbackController: FeedVideoPlaybackController

    init(url: URL, isActive: Bool) {
        self.url = url
        self.isActive = isActive
        _playbackController = StateObject(
            wrappedValue: FeedVideoPlaybackController(url: url)
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            FeedPlayerLayer(player: playbackController.player)
                .opacity(playbackController.isReadyToDisplay ? 1 : 0.001)

            if playbackController.isReadyToDisplay == false {
                ProgressView()
                    .tint(.white)
            }

            Button {
                playbackController.toggleMuted()
            } label: {
                Image(systemName: playbackController.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(12)
        }
        .onAppear {
            playbackController.setActive(isActive)
        }
        .onDisappear {
            playbackController.setActive(false)
        }
        .onChange(of: isActive) { _, newValue in
            playbackController.setActive(newValue)
        }
    }
}

@MainActor
private final class FeedVideoPlaybackController: ObservableObject {
    let player: AVPlayer

    @Published private(set) var isMuted = true
    @Published private(set) var isReadyToDisplay = false

    private var isActive = false
    private var endObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 2
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false

        self.player = AVPlayer(playerItem: playerItem)
        self.player.isMuted = true
        self.player.actionAtItemEnd = .none
        self.player.automaticallyWaitsToMinimizeStalling = true

        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isReadyToDisplay = status == .readyToPlay
            }
            .store(in: &cancellables)

        self.endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.player.seek(to: .zero)

                if self.isActive {
                    self.player.play()
                }
            }
        }
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        player.pause()
    }

    func setActive(_ active: Bool) {
        isActive = active

        if active {
            player.play()
        } else {
            player.pause()
        }
    }

    func toggleMuted() {
        isMuted.toggle()
        player.isMuted = isMuted
    }
}

private struct FeedPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> FeedPlayerContainerView {
        let view = FeedPlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: FeedPlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class FeedPlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        guard let playerLayer = layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer backing for FeedPlayerContainerView.")
        }

        return playerLayer
    }
}

private struct FeedPostOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct FeedVisibleMediaFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct FeedCircularAsyncImage: View {
    let url: URL?

    var body: some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFit()

            case .empty:
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }

            case .failure:
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white.opacity(0.7))
                    }

            @unknown default:
                Circle()
                    .fill(Color.white.opacity(0.1))
            }
        }
        .clipShape(Circle())
    }
}

private struct FeedRectangularAsyncImage: View {
    let url: URL?

    var body: some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()

            case .empty:
                ZStack {
                    Color.white.opacity(0.05)

                    ProgressView()
                        .tint(.white)
                }

            case .failure:
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.75))
                }

            @unknown default:
                Color.white.opacity(0.05)
            }
        }
    }
}

struct InstagramPostFeedScreen_Previews: PreviewProvider {
    static var previews: some View {
        InstagramPostFeedScreen(
            title: "Posts",
            posts: Array(MockInstagramDataset.posts.prefix(6)),
            initialPostID: MockInstagramDataset.samplePost.id,
            visiblePostID: .constant(MockInstagramDataset.samplePost.id),
            visibleTransitionContent: .constant(nil),
            visibleTransitionFrame: .constant(nil),
            onClose: {}
        )
    }
}
