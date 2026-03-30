---
name: insta-reels-ios
description: Use this skill when working on the insta-reels iOS SwiftUI project, especially for the profile screen, reels or feed overlay, transitions, media playback, caching, repository or view-model boundaries, and mock Instagram data.
metadata:
  short-description: Project-specific guidance for the insta-reels SwiftUI app
---

# Insta Reels iOS

## Read first

- Read `ARCHITECTURE.md` before making structural changes.
- Inspect the touched Swift files before editing so changes stay aligned with existing patterns.

## Architecture rules

- Keep `insta_reelsApp` and `ContentView` thin.
- Put raw loading, decoding, and payload shaping in `insta-reels/Data/`.
- Put screen-ready transformation in `insta-reels/ViewModels/`.
- Keep geometry, animation, and presentation state in `insta-reels/Views/`, not in view models.
- Reuse `CachedAsyncImage` for remote image loading and caching behavior.
- Reuse `InstagramMediaPlaybackResolver` for playback URL handling and mock fallbacks.

## Transition invariants

- Opening the feed uses the existing single-hierarchy live overlay motion.
- Closing the feed uses the snapshot-based dismiss path.
- Do not replace the current feed flow with a navigation push unless explicitly requested.
- Do not let the visible post or media change during dismiss.
- Clean up transition state in one non-animated step to avoid end-of-animation flicker.

## File ownership

- Profile UI and transition coordination live in `insta-reels/Views/InstagramProfileScreen.swift`.
- Feed UI, scrolling, visible-media tracking, and close behavior live in `insta-reels/Views/InstagramPostFeedScreen.swift`.
- Screen-facing derived state belongs in `insta-reels/ViewModels/InstagramProfileViewModel.swift`.
- Mock loading and payload shaping belong in `insta-reels/Data/`.
- Shared image and media helpers belong in `insta-reels/Views/CachedAsyncImage.swift` and `insta-reels/Data/InstagramMediaPlaybackResolver.swift`.

## Working agreements

1. Read `ARCHITECTURE.md` before significant structural or transition changes.
2. Keep edits minimal and consistent with the existing SwiftUI architecture.
3. Update `ARCHITECTURE.md` whenever screens, shared helpers, transition behavior, or data flow change.
4. Prefer project-local fixes over introducing new abstractions unless repetition or complexity clearly justifies them.

## Validation

- Prefer validating with `xcodebuild -project insta-reels.xcodeproj -scheme insta-reels build`.
- If simulator-related warnings appear in the CLI environment, focus on whether the project and scheme resolve correctly and note any environment-specific limitations.
