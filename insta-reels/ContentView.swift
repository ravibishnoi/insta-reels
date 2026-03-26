//
//  ContentView.swift
//  insta-reels
//
//  Created by Ravi Bishnoi on 26/03/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: InstagramProfileViewModel
    @State private var launchBeganAt = Date()
    @State private var isShowingLaunchOverlay = true
    @State private var launchBackgroundOpacity = 1.0
    @State private var launchImageOpacity = 1.0
    @State private var launchImageScale: CGFloat = 1.0
    @State private var hasScheduledLaunchDismissal = false

    init() {
        _viewModel = StateObject(
            wrappedValue: InstagramProfileViewModel(
                username: "fitwithsana",
                gridSource: .allPosts
            )
        )
    }

    var body: some View {
        ZStack {
            InstagramProfileScreen(viewModel: viewModel)

            if isShowingLaunchOverlay {
                LaunchOverlayView(
                    backgroundOpacity: launchBackgroundOpacity,
                    imageOpacity: launchImageOpacity,
                    imageScale: launchImageScale
                )
                .transition(.opacity)
            }
        }
        .background(AppLaunchStyle.backgroundColor.ignoresSafeArea())
        .onAppear {
            launchBeganAt = Date()
            scheduleLaunchDismissalIfNeeded(for: viewModel.state)
        }
        .onReceive(viewModel.$state) { state in
            scheduleLaunchDismissalIfNeeded(for: state)
        }
    }

    private func scheduleLaunchDismissalIfNeeded(for state: InstagramProfileViewState) {
        guard hasScheduledLaunchDismissal == false else {
            return
        }

        guard state.isReadyForLaunchTransition else {
            return
        }

        hasScheduledLaunchDismissal = true

        Task { @MainActor in
            let minimumVisibleDuration: TimeInterval = 0.05
            let elapsed = Date().timeIntervalSince(launchBeganAt)
            let remaining = max(0, minimumVisibleDuration - elapsed)

            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }

            withAnimation(.easeOut(duration: 0.42)) {
                launchBackgroundOpacity = 0
                launchImageOpacity = 0
                launchImageScale = 1.06
            }

            try? await Task.sleep(for: .milliseconds(210))

            isShowingLaunchOverlay = false
        }
    }
}

private struct LaunchOverlayView: View {
    let backgroundOpacity: Double
    let imageOpacity: Double
    let imageScale: CGFloat

    var body: some View {
        ZStack {
            AppLaunchStyle.backgroundColor
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .opacity(imageOpacity)
                .scaleEffect(imageScale)
                .accessibilityHidden(true)
        }
    }
}

private enum AppLaunchStyle {
    static let backgroundColor = Color(
        red: 10.0 / 255.0,
        green: 14.0 / 255.0,
        blue: 20.0 / 255.0
    )
}

private extension InstagramProfileViewState {
    var isReadyForLaunchTransition: Bool {
        switch self {
        case .loaded, .failed:
            return true
        case .loading:
            return false
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
