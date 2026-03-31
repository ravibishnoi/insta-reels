//
//  RootViewController.swift
//  insta-reels
//
//  Created by Codex on 31/03/26.
//

import Combine
import UIKit

final class RootViewController: UIViewController {
    private let viewModel: InstagramProfileViewModel
    private let profileController: InstagramProfileScreen
    private let launchOverlayView = LaunchOverlayView()

    private var cancellables = Set<AnyCancellable>()
    private var launchBeganAt = Date()
    private var hasScheduledLaunchDismissal = false

    init(viewModel: InstagramProfileViewModel) {
        self.viewModel = viewModel
        self.profileController = InstagramProfileScreen(viewModel: viewModel)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = AppTheme.backgroundColor
        launchBeganAt = Date()

        addChild(profileController)
        profileController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(profileController.view)
        profileController.didMove(toParent: self)

        launchOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(launchOverlayView)

        NSLayoutConstraint.activate([
            profileController.view.topAnchor.constraint(equalTo: view.topAnchor),
            profileController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            profileController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            profileController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            launchOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            launchOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            launchOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            launchOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        bindViewModel()
        scheduleLaunchDismissalIfNeeded(for: viewModel.state)
    }

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.scheduleLaunchDismissalIfNeeded(for: state)
            }
            .store(in: &cancellables)
    }

    private func scheduleLaunchDismissalIfNeeded(for state: InstagramProfileViewState) {
        guard hasScheduledLaunchDismissal == false else {
            return
        }

        guard state.isReadyForLaunchTransition else {
            return
        }

        hasScheduledLaunchDismissal = true

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let minimumVisibleDuration: TimeInterval = 0.05
            let elapsed = Date().timeIntervalSince(launchBeganAt)
            let remaining = max(0, minimumVisibleDuration - elapsed)

            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }

            UIView.animate(withDuration: 0.42, delay: 0, options: [.curveEaseOut]) {
                self.launchOverlayView.fadeOut()
            }

            try? await Task.sleep(for: .milliseconds(210))

            self.launchOverlayView.removeFromSuperview()
        }
    }
}

private final class LaunchOverlayView: UIView {
    private let imageView = UIImageView(image: UIImage(named: "LaunchLogo"))

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = AppTheme.backgroundColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 180),
            imageView.heightAnchor.constraint(equalToConstant: 180)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func fadeOut() {
        alpha = 0
        imageView.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
    }
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
