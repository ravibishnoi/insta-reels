//
//  InstagramProfileScreen.swift
//  insta-reels
//
//  Created by Codex on 26/03/26.
//

import SwiftUI
import UIKit

struct InstagramProfileScreen: View {
    @ObservedObject var viewModel: InstagramProfileViewModel
    @Namespace private var feedTransitionNamespace
    @State private var feedPresentation: InstagramFeedPresentation?
    @State private var currentFeedPostID: String?
    @State private var hiddenGridPostID: String?
    @State private var gridItemFrames: [String: CGRect] = [:]
    @State private var transitionHero: InstagramFeedTransitionHeroState?
    @State private var isTransitionHeroVisible = false
    @State private var isFeedTransitionExpanded = false
    @State private var isFeedContentVisible = false
    @State private var feedBackgroundOpacity = 0.0
    @State private var currentFeedTransitionContent: InstagramFeedTransitionContent?
    @State private var currentFeedTransitionFrame: CGRect?
    @State private var isFeedInteractionEnabled = false
    @State private var isFeedDismissInProgress = false
    @State private var dismissSnapshotImage: UIImage?
    @State private var dismissSnapshotFrame: CGRect = .zero
    @State private var closingGridRevealPostID: String?
    @State private var closingGridRevealOpacity = 0.0
    @State private var returningGridPostID: String?
    @State private var isGridReturnAnimationActive = false
    @State private var gridReturnAnimationSequence = 0
    @State private var feedTransitionSequence = 0

    private let backgroundColor = Color(red: 10.0 / 255.0, green: 14.0 / 255.0, blue: 20.0 / 255.0)
    private let secondaryTextColor = Color(red: 166.0 / 255.0, green: 172.0 / 255.0, blue: 184.0 / 255.0)
    private let buttonColor = Color(red: 44.0 / 255.0, green: 49.0 / 255.0, blue: 58.0 / 255.0)
    private let dividerColor = Color.white.opacity(0.08)
    private let profileCoordinateSpaceName = "profileScreen"
    private let feedTransitionFadeDuration = 0.18
    private let feedTransitionDismissBackgroundFadeDuration = 0.24
    private let feedTransitionInteractionDelay = 0.26
    private let feedTransitionHeroCleanupDelay = 0.38

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea()

                content(in: geometry.size)
            }
            .coordinateSpace(name: profileCoordinateSpaceName)
        }
        .task {
            viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func content(in containerSize: CGSize) -> some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .tint(.white)

        case let .failed(message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.yellow)

                Text("Couldn’t load the profile")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(secondaryTextColor)
            }
            .padding(24)

        case let .loaded(model):
            ScrollViewReader { proxy in
                ZStack {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            headerBar(for: model)
                            profileSummary(for: model)
                            actionButtons
                            highlightsSection(for: model)
                            tabsSection
                            mediaGrid(for: model, containerSize: containerSize)
                        }
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .allowsHitTesting(feedPresentation == nil)
                    .onPreferenceChange(GridItemFramePreferenceKey.self) { frames in
                        gridItemFrames = frames
                    }

                    if let presentation = feedPresentation {
                        feedOverlay(
                            presentation: presentation,
                            containerSize: containerSize,
                            proxy: proxy
                        )
                    }
                }
                .onChange(of: currentFeedPostID) { _, newPostID in
                    guard feedPresentation != nil,
                          isFeedDismissInProgress == false,
                          let newPostID
                    else {
                        return
                    }

                    scrollProfileGrid(to: newPostID, using: proxy)
                }
            }
        }
    }

    private func headerBar(for model: InstagramProfileScreenModel) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "chevron.left")
                .font(.system(size: 22, weight: .semibold))

            HStack(spacing: 6) {
                Text(model.user.username)
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                if model.user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(red: 0.0, green: 149.0 / 255.0, blue: 246.0 / 255.0))
                }
            }

            Spacer()

            Image(systemName: "bell")
                .font(.system(size: 20, weight: .regular))

            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .bold))
                .padding(.leading, 12)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 22)
    }

    private func profileSummary(for model: InstagramProfileScreenModel) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ProfileAvatar(url: model.user.avatarURL)

                VStack(alignment: .leading, spacing: 20) {
                    Text(model.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 10) {
                        ForEach(model.stats) { stat in
                            ProfileStatView(stat: stat)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(model.bioLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white)
                }

                Link(destination: model.websiteURL) {
                    Label(model.websiteLabel, systemImage: "link")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 126.0 / 255.0, green: 160.0 / 255.0, blue: 1.0))
                }

                Label(model.featuredAudioLabel, systemImage: "music.note")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white)

                HStack(alignment: .center, spacing: 5) {
                    OverlappingAvatarStrip(users: model.followedByUsers)

                    if model.followedBySummary.isEmpty == false {
                        Text(model.followedBySummary)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
            } label: {
                HStack(spacing: 4) {
                    Text("Following")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(buttonColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
            } label: {
                Text("Message")
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(buttonColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func highlightsSection(for model: InstagramProfileScreenModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 18) {
                ForEach(model.highlights) { highlight in
                    VStack(spacing: 10) {
                        HighlightBubble(
                            imageURL: highlight.imageURL,
                            size: 82
                        )

                        Text(highlight.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(width: 82)
                    }
                }
            }
            .padding(.horizontal, 22)
        }
        .padding(.top, 26)
        .padding(.bottom, 20)
    }

    private var tabsSection: some View {
        VStack(spacing: 0) {
            HStack {
                tabIcon("square.grid.3x3.fill", isSelected: true)
                Spacer()
                tabIcon("play.square", isSelected: false)
                Spacer()
                tabIcon("arrow.2.squarepath", isSelected: false)
                Spacer()
                tabIcon("person.crop.square", isSelected: false)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 12)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
        }
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(.white)
                .frame(width: 88, height: 2)
                .padding(.leading, 22)
                .offset(y: 1)
        }
    }

    private func mediaGrid(for model: InstagramProfileScreenModel, containerSize: CGSize) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 3),
            spacing: 1
        ) {
            ForEach(model.gridItems) { item in
                Button {
                    openFeed(for: item, model: model, containerSize: containerSize)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        gridMediaCell(for: item)
                            .opacity(gridCellOpacity(for: item.id))

                        if let overlaySymbol = item.overlaySymbol,
                           hiddenGridPostID != item.id {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.black.opacity(0.45))

                                Image(systemName: overlaySymbol)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 28, height: 28)
                            .padding(8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .id(item.id)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: GridItemFramePreferenceKey.self,
                            value: [item.id: geometry.frame(in: .global)]
                        )
                    }
                }
            }
        }
    }

    private func tabIcon(_ systemName: String, isSelected: Bool) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: isSelected ? .bold : .regular))
            .foregroundStyle(isSelected ? .white : secondaryTextColor)
            .frame(height: 28)
    }

    private func feedOverlay(
        presentation: InstagramFeedPresentation,
        containerSize: CGSize,
        proxy: ScrollViewProxy
    ) -> some View {
        ZStack(alignment: .topLeading) {
            InstagramPostFeedScreen(
                title: presentation.title,
                posts: presentation.posts,
                initialPostID: presentation.initialPostID,
                visiblePostID: visibleFeedPostIDBinding,
                visibleTransitionContent: visibleFeedTransitionContentBinding,
                visibleTransitionFrame: visibleFeedTransitionFrameBinding,
                onClose: {
                    dismissFeed(using: proxy, presentation: presentation, containerSize: containerSize)
                },
                contentOpacity: isFeedContentVisible ? 1 : 0,
                backgroundOpacity: feedBackgroundOpacity,
                isInteractionEnabled: isFeedInteractionEnabled
            )

            if let transitionHero {
                InstagramFeedTransitionHero(
                    hero: transitionHero,
                    namespace: feedTransitionNamespace,
                    isExpanded: isFeedTransitionExpanded,
                    isVisible: isTransitionHeroVisible,
                    containerSize: containerSize
                )
                .ignoresSafeArea()
                .zIndex(2)
            }

            if let dismissSnapshotImage {
                DismissTransitionSnapshot(
                    image: dismissSnapshotImage,
                    frame: dismissSnapshotFrame
                )
                .ignoresSafeArea()
                .zIndex(3)
            }
        }
        .transition(.identity)
        .zIndex(1)
    }

    private func openFeed(
        for item: InstagramProfileGridItem,
        model: InstagramProfileScreenModel,
        containerSize: CGSize
    ) {
        let sequence = nextFeedTransitionSequence()

        clearGridReturnAnimation()

        isFeedDismissInProgress = false
        currentFeedPostID = item.id
        hiddenGridPostID = item.id
        closingGridRevealPostID = nil
        closingGridRevealOpacity = 0
        isFeedTransitionExpanded = false
        isFeedContentVisible = false
        feedBackgroundOpacity = 0
        isFeedInteractionEnabled = false

        let presentation = InstagramFeedPresentation(
            title: model.user.username,
            posts: model.feedPosts,
            initialPostID: item.id
        )

        currentFeedTransitionContent = presentation.posts
            .first(where: { $0.id == item.id })
            .flatMap { post in
                post.media.first.map { media in
                    InstagramFeedTransitionContent(postID: post.id, media: media)
                }
            }
        currentFeedTransitionFrame = nil

        let hero = makeTransitionHero(
            for: item.id,
            posts: presentation.posts
        )

        feedPresentation = presentation
        transitionHero = hero
        isTransitionHeroVisible = hero != nil

        guard hero != nil else {
            isFeedTransitionExpanded = true
            isFeedContentVisible = true
            feedBackgroundOpacity = 1
            isFeedInteractionEnabled = true
            return
        }

        DispatchQueue.main.async {
            guard feedTransitionSequence == sequence else {
                return
            }

            withAnimation(feedTransitionSpring) {
                isFeedTransitionExpanded = true
            }

            withAnimation(feedTransitionFade) {
                feedBackgroundOpacity = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + feedTransitionFadeDuration) {
            guard feedTransitionSequence == sequence else {
                return
            }

            withAnimation(feedTransitionFade) {
                isFeedContentVisible = true
                isTransitionHeroVisible = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + feedTransitionInteractionDelay) {
            guard feedTransitionSequence == sequence else {
                return
            }

            isFeedInteractionEnabled = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + feedTransitionHeroCleanupDelay) {
            guard feedTransitionSequence == sequence else {
                return
            }

            transitionHero = nil
        }
    }

    private func dismissFeed(
        using proxy: ScrollViewProxy,
        presentation: InstagramFeedPresentation,
        containerSize: CGSize
    ) {
        let sequence = nextFeedTransitionSequence()
        let restoreID = currentFeedPostID ?? presentation.initialPostID

        isFeedDismissInProgress = true
        currentFeedPostID = restoreID
        hiddenGridPostID = restoreID
        closingGridRevealPostID = restoreID
        closingGridRevealOpacity = 0
        isFeedInteractionEnabled = false

        scrollProfileGrid(to: restoreID, using: proxy)

        Task { @MainActor in
            _ = await waitForGridFrame(
                for: restoreID,
                settlingAfterScroll: true
            )

            guard feedTransitionSequence == sequence else {
                return
            }

            if let snapshot = captureTransitionSnapshot(),
               let startFrame = currentFeedTransitionFrame,
               let targetFrame = gridItemFrames[restoreID] {
                transitionHero = nil
                isTransitionHeroVisible = false
                dismissSnapshotImage = snapshot
                dismissSnapshotFrame = startFrame
                isFeedContentVisible = false
                feedBackgroundOpacity = 0

                withAnimation(feedTransitionDismissSnapshotAnimation, completionCriteria: .logicallyComplete) {
                    dismissSnapshotFrame = targetFrame
                } completion: {
                    guard feedTransitionSequence == sequence,
                          closingGridRevealPostID == restoreID
                    else {
                        return
                    }

                    var transaction = Transaction()
                    transaction.animation = nil

                    withTransaction(transaction) {
                        dismissSnapshotImage = nil
                        dismissSnapshotFrame = .zero
                        resetFeedPresentation()
                    }
                }
                return
            }

            let collapseHero = makeTransitionHero(
                for: restoreID,
                posts: presentation.posts
            )

            guard let collapseHero else {
                isFeedContentVisible = false
                feedBackgroundOpacity = 0
                closingGridRevealOpacity = 1

                DispatchQueue.main.asyncAfter(deadline: .now() + feedTransitionDismissBackgroundFadeDuration) {
                    guard feedTransitionSequence == sequence else {
                        return
                    }

                    resetFeedPresentation(playGridReturnAnimationFor: restoreID)
                }
                return
            }

            transitionHero = collapseHero
            isTransitionHeroVisible = true

            isFeedContentVisible = false
            feedBackgroundOpacity = 0
            closingGridRevealOpacity = 0

            withAnimation(feedTransitionDismissSpring, completionCriteria: .logicallyComplete) {
                isFeedTransitionExpanded = false
            } completion: {
                guard feedTransitionSequence == sequence,
                      closingGridRevealPostID == restoreID
                else {
                    return
                }

                var transaction = Transaction()
                transaction.animation = nil

                withTransaction(transaction) {
                    resetFeedPresentation()
                }
            }
        }
    }

    @MainActor
    private func waitForGridFrame(
        for postID: String,
        timeout: TimeInterval = 0.35,
        settlingAfterScroll: Bool = false
    ) async -> CGRect? {
        if settlingAfterScroll {
            try? await Task.sleep(for: .milliseconds(16))
        } else if let frame = gridItemFrames[postID] {
            return frame
        }

        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(16))

            if let frame = gridItemFrames[postID] {
                return frame
            }
        }

        return gridItemFrames[postID]
    }

    private func scrollProfileGrid(to postID: String, using proxy: ScrollViewProxy) {
        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            proxy.scrollTo(postID, anchor: .center)
        }
    }

    private func nextFeedTransitionSequence() -> Int {
        feedTransitionSequence += 1
        return feedTransitionSequence
    }

    @ViewBuilder
    private func gridMediaCell(for item: InstagramProfileGridItem) -> some View {
        let cell = GridMediaCell(
            imageURL: transitionImageURL(for: item),
            isReturningFromFeed: returningGridPostID == item.id,
            isReturnAnimationActive: returningGridPostID == item.id && isGridReturnAnimationActive
        )

        if transitionHero?.postID == item.id {
            cell.matchedGeometryEffect(
                id: item.id,
                in: feedTransitionNamespace,
                properties: .frame,
                anchor: .center,
                isSource: isFeedTransitionExpanded == false
            )
        } else {
            cell
        }
    }

    private func gridCellOpacity(for postID: String) -> Double {
        guard hiddenGridPostID == postID else {
            return 1
        }

        guard closingGridRevealPostID == postID else {
            return 0.001
        }

        return max(closingGridRevealOpacity, 0.001)
    }

    private func transitionImageURL(for item: InstagramProfileGridItem) -> URL? {
        guard let currentFeedTransitionContent,
              currentFeedTransitionContent.postID == item.id
        else {
            return item.imageURL
        }

        return currentFeedTransitionContent.media.thumbnailURL ?? currentFeedTransitionContent.media.mediaURL
    }

    private func resetFeedPresentation(playGridReturnAnimationFor postID: String? = nil) {
        feedPresentation = nil
        transitionHero = nil
        isTransitionHeroVisible = false
        isFeedTransitionExpanded = false
        isFeedContentVisible = false
        feedBackgroundOpacity = 0
        currentFeedTransitionContent = nil
        currentFeedTransitionFrame = nil
        isFeedInteractionEnabled = false
        isFeedDismissInProgress = false
        dismissSnapshotImage = nil
        dismissSnapshotFrame = .zero
        hiddenGridPostID = nil
        closingGridRevealPostID = nil
        closingGridRevealOpacity = 0

        if let postID {
            playGridReturnAnimation(for: postID)
        }
    }

    private var feedTransitionSpring: Animation {
        .interactiveSpring(response: 0.52, dampingFraction: 0.92, blendDuration: 0.18)
    }

    private var feedTransitionDismissSpring: Animation {
        .interactiveSpring(response: 0.44, dampingFraction: 0.96, blendDuration: 0.08)
    }

    private var feedTransitionFade: Animation {
        .easeOut(duration: feedTransitionFadeDuration)
    }

    private var feedTransitionDismissSnapshotAnimation: Animation {
        .easeInOut(duration: 0.24)
    }

    private var visibleFeedPostIDBinding: Binding<String?> {
        Binding(
            get: { currentFeedPostID },
            set: { newValue in
                guard isFeedDismissInProgress == false else {
                    return
                }

                currentFeedPostID = newValue
            }
        )
    }

    private var visibleFeedTransitionContentBinding: Binding<InstagramFeedTransitionContent?> {
        Binding(
            get: { currentFeedTransitionContent },
            set: { newValue in
                guard isFeedDismissInProgress == false else {
                    return
                }

                currentFeedTransitionContent = newValue
            }
        )
    }

    private var visibleFeedTransitionFrameBinding: Binding<CGRect?> {
        Binding(
            get: { currentFeedTransitionFrame },
            set: { newValue in
                guard isFeedDismissInProgress == false else {
                    return
                }

                currentFeedTransitionFrame = newValue
            }
        )
    }

    private func makeTransitionHero(
        for postID: String,
        posts: [InstagramPost]
    ) -> InstagramFeedTransitionHeroState? {
        guard let post = posts.first(where: { $0.id == postID }) else {
            return nil
        }

        guard let media = transitionMedia(for: post) else {
            return nil
        }

        return InstagramFeedTransitionHeroState(
            postID: postID,
            media: media
        )
    }

    private func transitionMedia(for post: InstagramPost) -> InstagramMedia? {
        if let currentFeedTransitionContent, currentFeedTransitionContent.postID == post.id {
            return currentFeedTransitionContent.media
        }

        return post.media.first
    }

    private func feedHeroDestinationFrame(for media: InstagramMedia, containerSize: CGSize) -> CGRect {
        let width = containerSize.width
        let height = width / feedHeroAspectRatio(for: media)
        let minY: CGFloat = 124

        return CGRect(x: 0, y: minY, width: width, height: height)
    }

    private func feedHeroAspectRatio(for media: InstagramMedia) -> CGFloat {
        let ratio = CGFloat(media.width) / CGFloat(max(media.height, 1))
        return min(max(ratio, 0.5625), 1.0)
    }

    @MainActor
    private func captureTransitionSnapshot() -> UIImage? {
        guard let frame = currentFeedTransitionFrame,
              frame.width > 1,
              frame.height > 1,
              let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: \.isKeyWindow) ?? windowScene.windows.first
        else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let snapshot = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }

        let scale = snapshot.scale
        let imageBounds = CGRect(
            x: 0,
            y: 0,
            width: snapshot.size.width * scale,
            height: snapshot.size.height * scale
        )
        let cropRect = CGRect(
            x: frame.minX * scale,
            y: frame.minY * scale,
            width: frame.width * scale,
            height: frame.height * scale
        ).integral.intersection(imageBounds)

        guard cropRect.isNull == false,
              cropRect.isEmpty == false,
              let cgImage = snapshot.cgImage?.cropping(to: cropRect)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private func playGridReturnAnimation(for postID: String) {
        gridReturnAnimationSequence += 1
        let sequence = gridReturnAnimationSequence

        returningGridPostID = postID
        isGridReturnAnimationActive = true

        DispatchQueue.main.async {
            guard gridReturnAnimationSequence == sequence else {
                return
            }

            withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.12)) {
                isGridReturnAnimationActive = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            guard gridReturnAnimationSequence == sequence else {
                return
            }

            returningGridPostID = nil
        }
    }

    private func clearGridReturnAnimation() {
        gridReturnAnimationSequence += 1
        returningGridPostID = nil
        isGridReturnAnimationActive = false
    }
}

private struct InstagramFeedPresentation: Identifiable {
    let id = UUID()
    let title: String
    let posts: [InstagramPost]
    let initialPostID: String
}

private struct InstagramFeedTransitionHeroState {
    let postID: String
    let media: InstagramMedia
}

private struct GridItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct InstagramFeedTransitionHero: View {
    let hero: InstagramFeedTransitionHeroState
    let namespace: Namespace.ID
    let isExpanded: Bool
    let isVisible: Bool
    let containerSize: CGSize

    var body: some View {
        InstagramTransitionHeroMedia(media: hero.media)
            .matchedGeometryEffect(
                id: hero.postID,
                in: namespace,
                properties: .frame,
                anchor: .center,
                isSource: isExpanded
            )
            .frame(width: containerSize.width, height: mediaHeight)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 0,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(isExpanded ? 0.12 : 0),
                radius: isExpanded ? 18 : 0,
                y: isExpanded ? 8 : 0
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 124)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.16), value: isVisible)
            .allowsHitTesting(false)
    }

    private var mediaHeight: CGFloat {
        let ratio = CGFloat(hero.media.width) / CGFloat(max(hero.media.height, 1))
        let clampedRatio = min(max(ratio, 0.5625), 1.0)
        return containerSize.width / clampedRatio
    }
}

private struct DismissTransitionSnapshot: View {
    let image: UIImage
    let frame: CGRect

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: frame.width, height: frame.height)
            .clipped()
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
    }
}

private struct InstagramTransitionHeroMedia: View {
    let media: InstagramMedia

    var body: some View {
        RectangularAsyncImage(url: media.thumbnailURL ?? media.mediaURL)
    }
}

private struct ProfileAvatar: View {
    let url: URL

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.56, blue: 0.23),
                            Color(red: 0.96, green: 0.17, blue: 0.44),
                            Color(red: 0.49, green: 0.24, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)

            Circle()
                .fill(Color.white)
                .frame(width: 80, height: 80)

            CircularAsyncImage(url: url)
                .frame(width: 72, height: 72)
        }
    }
}

private struct ProfileStatView: View {
    let stat: InstagramProfileStat

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(stat.value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(stat.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

private struct OverlappingAvatarStrip: View {
    let users: [InstagramUser]

    var body: some View {
        HStack(spacing: -10) {
            ForEach(users) { user in
                CircularAsyncImage(url: user.avatarURL)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Circle()
                            .stroke(Color(red: 10.0 / 255.0, green: 14.0 / 255.0, blue: 20.0 / 255.0), lineWidth: 2)
                    }
            }
        }
    }
}

private struct HighlightBubble: View {
    let imageURL: URL?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: size, height: size)

            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                .frame(width: size - 4, height: size - 4)

            CircularAsyncImage(url: imageURL)
                .frame(width: size - 14, height: size - 14)
        }
    }
}

private struct GridMediaCell: View {
    let imageURL: URL?
    let isReturningFromFeed: Bool
    let isReturnAnimationActive: Bool
    private let instagramGridAspectRatio: CGFloat = 4.0 / 5.0

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .overlay {
                RectangularAsyncImage(url: imageURL)
            }
            .clipShape(cellShape)
            .overlay {
                if isReturningFromFeed {
                    closingOverlay
                }
            }
            .scaleEffect(
                x: isReturnAnimationActive ? 1.05 : 1.0,
                y: isReturnAnimationActive ? 1.1 : 1.0,
                anchor: .center
            )
            .shadow(
                color: Color.black.opacity(isReturnAnimationActive ? 0.24 : 0),
                radius: isReturnAnimationActive ? 22 : 0,
                y: isReturnAnimationActive ? 12 : 0
            )
            .zIndex(isReturningFromFeed ? 1 : 0)
            .animation(
                .interactiveSpring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.12),
                value: isReturnAnimationActive
            )
            .aspectRatio(instagramGridAspectRatio, contentMode: .fit)
    }

    private var cellShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: isReturnAnimationActive ? 26 : 0,
            style: .continuous
        )
    }

    private var closingOverlay: some View {
        ZStack {
            cellShape
                .fill(Color.black.opacity(isReturnAnimationActive ? 0.14 : 0))

            cellShape
                .strokeBorder(
                    Color.white.opacity(isReturnAnimationActive ? 0.16 : 0),
                    lineWidth: isReturnAnimationActive ? 1.2 : 0
                )
        }
    }
}

private struct CircularAsyncImage: View {
    let url: URL?

    var body: some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()

            case .empty:
                progressPlaceholder

            case .failure:
                fallbackPlaceholder

            @unknown default:
                fallbackPlaceholder
            }
        }
        .clipShape(Circle())
    }

    private var progressPlaceholder: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .overlay {
                ProgressView()
                    .tint(.white)
            }
    }

    private var fallbackPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.75))
            }
    }
}

private struct RectangularAsyncImage: View {
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
                    Color(red: 18.0 / 255.0, green: 22.0 / 255.0, blue: 30.0 / 255.0)
                    ProgressView()
                        .tint(.white)
                }

            case .failure:
                fallback

            @unknown default:
                fallback
            }
        }
    }

    private var fallback: some View {
        LinearGradient(
            colors: [
                Color(red: 20.0 / 255.0, green: 24.0 / 255.0, blue: 33.0 / 255.0),
                Color(red: 32.0 / 255.0, green: 38.0 / 255.0, blue: 49.0 / 255.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "photo")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

struct InstagramProfileScreen_Previews: PreviewProvider {
    static var previews: some View {
        InstagramProfileScreen(
            viewModel: InstagramProfileViewModel(username: "fitwithsana")
        )
    }
}
