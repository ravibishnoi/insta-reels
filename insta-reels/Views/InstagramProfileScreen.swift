//
//  InstagramProfileScreen.swift
//  insta-reels
//
//  Created by Codex on 26/03/26.
//

import SwiftUI

struct InstagramProfileScreen: View {
    @ObservedObject var viewModel: InstagramProfileViewModel
    @State private var feedPresentation: InstagramFeedPresentation?
    @State private var currentFeedPostID: String?
    @State private var hiddenGridPostID: String?
    @State private var gridItemFrames: [String: CGRect] = [:]
    @State private var transitionHero: InstagramFeedTransitionHeroState?
    @State private var isTransitionHeroVisible = false
    @State private var isFeedTransitionExpanded = false
    @State private var isFeedContentVisible = false
    @State private var isFeedInteractionEnabled = false
    @State private var returningGridPostID: String?
    @State private var isGridReturnAnimationActive = false
    @State private var gridReturnAnimationSequence = 0

    private let backgroundColor = Color(red: 10.0 / 255.0, green: 14.0 / 255.0, blue: 20.0 / 255.0)
    private let secondaryTextColor = Color(red: 166.0 / 255.0, green: 172.0 / 255.0, blue: 184.0 / 255.0)
    private let buttonColor = Color(red: 44.0 / 255.0, green: 49.0 / 255.0, blue: 58.0 / 255.0)
    private let dividerColor = Color.white.opacity(0.08)
    private let profileCoordinateSpaceName = "profileScreen"

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
                        GridMediaCell(
                            imageURL: item.imageURL,
                            isReturningFromFeed: returningGridPostID == item.id,
                            isReturnAnimationActive: returningGridPostID == item.id && isGridReturnAnimationActive
                        )
                        .opacity(hiddenGridPostID == item.id ? 0.001 : 1)

                        if let overlaySymbol = item.overlaySymbol {
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
                            value: [item.id: geometry.frame(in: .named(profileCoordinateSpaceName))]
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
            Color.black
                .opacity(1)
                .ignoresSafeArea()

            InstagramPostFeedScreen(
                title: presentation.title,
                posts: presentation.posts,
                initialPostID: presentation.initialPostID,
                visiblePostID: $currentFeedPostID,
                onClose: {
                    dismissFeed(using: proxy, presentation: presentation, containerSize: containerSize)
                },
                contentOpacity: isFeedContentVisible ? 1 : 0.001,
                backgroundOpacity: 0,
                isInteractionEnabled: isFeedInteractionEnabled
            )

            if let transitionHero {
                InstagramFeedTransitionHero(
                    hero: transitionHero,
                    isExpanded: isFeedTransitionExpanded,
                    isVisible: isTransitionHeroVisible
                )
                .ignoresSafeArea()
                .zIndex(2)
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
        clearGridReturnAnimation()

        currentFeedPostID = item.id
        hiddenGridPostID = item.id
        isFeedTransitionExpanded = false
        isFeedContentVisible = false
        isFeedInteractionEnabled = false

        let presentation = InstagramFeedPresentation(
            title: model.user.username,
            posts: model.feedPosts,
            initialPostID: item.id
        )

        let hero = makeTransitionHero(
            for: item.id,
            posts: presentation.posts,
            collapsedFrame: gridItemFrames[item.id],
            containerSize: containerSize
        )

        feedPresentation = presentation
        transitionHero = hero
        isTransitionHeroVisible = hero != nil

        guard hero != nil else {
            isFeedTransitionExpanded = true
            isFeedContentVisible = true
            isFeedInteractionEnabled = true
            return
        }

        DispatchQueue.main.async {
            withAnimation(.interactiveSpring(response: 0.44, dampingFraction: 0.86, blendDuration: 0.14)) {
                isFeedTransitionExpanded = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.12)) {
                isFeedContentVisible = true
                isTransitionHeroVisible = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isFeedInteractionEnabled = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            transitionHero = nil
        }
    }

    private func dismissFeed(
        using proxy: ScrollViewProxy,
        presentation: InstagramFeedPresentation,
        containerSize: CGSize
    ) {
        let restoreID = currentFeedPostID ?? presentation.initialPostID

        currentFeedPostID = restoreID
        hiddenGridPostID = restoreID
        isFeedInteractionEnabled = false

        withAnimation(.easeInOut(duration: 0.22)) {
            proxy.scrollTo(restoreID, anchor: .center)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let collapseHero = makeTransitionHero(
                for: restoreID,
                posts: presentation.posts,
                collapsedFrame: gridItemFrames[restoreID],
                containerSize: containerSize
            )

            guard let collapseHero else {
                feedPresentation = nil
                transitionHero = nil
                isTransitionHeroVisible = false
                isFeedTransitionExpanded = false
                isFeedContentVisible = false
                isFeedInteractionEnabled = false
                hiddenGridPostID = nil
                playGridReturnAnimation(for: restoreID)
                return
            }

            transitionHero = collapseHero
            isTransitionHeroVisible = true

            withAnimation(.easeOut(duration: 0.12)) {
                isFeedContentVisible = false
            }

            withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.12)) {
                isFeedTransitionExpanded = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            feedPresentation = nil
            transitionHero = nil
            isTransitionHeroVisible = false
            isFeedTransitionExpanded = false
            isFeedContentVisible = false
            isFeedInteractionEnabled = false
            hiddenGridPostID = nil
        }
    }

    private func makeTransitionHero(
        for postID: String,
        posts: [InstagramPost],
        collapsedFrame: CGRect?,
        containerSize: CGSize
    ) -> InstagramFeedTransitionHeroState? {
        guard let post = posts.first(where: { $0.id == postID }) else {
            return nil
        }

        guard let collapsedFrame else {
            return nil
        }

        return InstagramFeedTransitionHeroState(
            imageURL: post.media.first?.thumbnailURL ?? post.media.first?.mediaURL,
            collapsedFrame: collapsedFrame,
            expandedFrame: feedHeroDestinationFrame(for: post, containerSize: containerSize)
        )
    }

    private func feedHeroDestinationFrame(for post: InstagramPost, containerSize: CGSize) -> CGRect {
        let width = containerSize.width
        let height = width / feedHeroAspectRatio(for: post)
        let minY: CGFloat = 124

        return CGRect(x: 0, y: minY, width: width, height: height)
    }

    private func feedHeroAspectRatio(for post: InstagramPost) -> CGFloat {
        guard let media = post.media.first else {
            return 1
        }

        let ratio = CGFloat(media.width) / CGFloat(max(media.height, 1))
        return min(max(ratio, 0.5625), 1.0)
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
    let imageURL: URL?
    let collapsedFrame: CGRect
    let expandedFrame: CGRect
}

private struct GridItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct InstagramFeedTransitionHero: View {
    let hero: InstagramFeedTransitionHeroState
    let isExpanded: Bool
    let isVisible: Bool

    var body: some View {
        let frame = isExpanded ? hero.expandedFrame : hero.collapsedFrame

        RectangularAsyncImage(url: hero.imageURL)
            .background(Color.white.opacity(0.04))
        .frame(width: frame.width, height: frame.height)
        .clipShape(
            RoundedRectangle(
                cornerRadius: isExpanded ? 0 : 2,
                style: .continuous
            )
        )
        .shadow(
            color: Color.black.opacity(isExpanded ? 0.18 : 0),
            radius: isExpanded ? 26 : 0,
            y: isExpanded ? 14 : 0
        )
        .position(x: frame.midX, y: frame.midY)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: isVisible)
        .allowsHitTesting(false)
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
            .aspectRatio(1, contentMode: .fit)
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
        AsyncImage(url: url) { phase in
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
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()

            case .empty:
                ZStack {
                    Color.white.opacity(0.06)
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
                Color.white.opacity(0.08),
                Color.white.opacity(0.18)
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
