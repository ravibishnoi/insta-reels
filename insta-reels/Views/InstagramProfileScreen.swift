//
//  InstagramProfileScreen.swift
//  insta-reels
//
//  Created by Codex on 26/03/26.
//

import Combine
import UIKit

final class InstagramProfileScreen: UIViewController {
    private let viewModel: InstagramProfileViewModel

    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let errorView = ProfileErrorView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()
    private let headerBar = ProfileHeaderBarView()
    private let summaryView = ProfileSummaryView()
    private let actionButtonsView = ProfileActionButtonsView()
    private let highlightsView = ProfileHighlightsView()
    private let tabsView = ProfileTabsView()
    private let gridCollectionView: UICollectionView

    private var gridHeightConstraint: NSLayoutConstraint?
    private var currentModel: InstagramProfileScreenModel?
    private var hiddenGridPostID: String?

    private weak var feedController: InstagramPostFeedScreen?
    private var isFeedDismissInProgress = false
    private var currentFeedPostID: String?
    private var currentFeedTransitionContent: InstagramFeedTransitionContent?
    private var currentFeedTransitionFrame: CGRect?

    private var cancellables = Set<AnyCancellable>()

    init(viewModel: InstagramProfileViewModel) {
        self.viewModel = viewModel

        let gridLayout = UICollectionViewFlowLayout()
        gridLayout.scrollDirection = .vertical
        gridLayout.minimumInteritemSpacing = 1
        gridLayout.minimumLineSpacing = 1

        self.gridCollectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureViewHierarchy()
        configureCollectionView()
        bindViewModel()

        viewModel.loadIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGridLayoutIfNeeded()
    }

    private func configureViewHierarchy() {
        view.backgroundColor = AppTheme.backgroundColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentView.addSubview(contentStack)

        headerBar.translatesAutoresizingMaskIntoConstraints = false
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        actionButtonsView.translatesAutoresizingMaskIntoConstraints = false
        highlightsView.translatesAutoresizingMaskIntoConstraints = false
        tabsView.translatesAutoresizingMaskIntoConstraints = false
        gridCollectionView.translatesAutoresizingMaskIntoConstraints = false

        contentStack.addArrangedSubview(headerBar)
        contentStack.addArrangedSubview(summaryView)
        contentStack.addArrangedSubview(actionButtonsView)
        contentStack.addArrangedSubview(highlightsView)
        contentStack.addArrangedSubview(tabsView)
        contentStack.addArrangedSubview(gridCollectionView)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .white
        view.addSubview(loadingIndicator)

        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.isHidden = true
        view.addSubview(errorView)

        gridHeightConstraint = gridCollectionView.heightAnchor.constraint(equalToConstant: 0)
        gridHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            errorView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])

        summaryView.onWebsiteTap = { [weak self] url in
            UIApplication.shared.open(url)
        }
    }

    private func configureCollectionView() {
        gridCollectionView.backgroundColor = .clear
        gridCollectionView.isScrollEnabled = false
        gridCollectionView.showsVerticalScrollIndicator = false
        gridCollectionView.contentInset = .zero
        gridCollectionView.dataSource = self
        gridCollectionView.delegate = self
        gridCollectionView.register(ProfileGridCell.self, forCellWithReuseIdentifier: ProfileGridCell.reuseIdentifier)
    }

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.render(state)
            }
            .store(in: &cancellables)
    }

    private func render(_ state: InstagramProfileViewState) {
        switch state {
        case .loading:
            currentModel = nil
            scrollView.isHidden = true
            errorView.isHidden = true
            loadingIndicator.startAnimating()

        case let .failed(message):
            currentModel = nil
            loadingIndicator.stopAnimating()
            scrollView.isHidden = true
            errorView.isHidden = false
            errorView.configure(message: message)

        case let .loaded(model):
            currentModel = model
            loadingIndicator.stopAnimating()
            errorView.isHidden = true
            scrollView.isHidden = false

            headerBar.configure(username: model.user.username, isVerified: model.user.isVerified)
            summaryView.configure(model: model)
            highlightsView.configure(highlights: model.highlights)
            gridCollectionView.reloadData()
            updateGridLayoutIfNeeded()
        }
    }

    private func updateGridLayoutIfNeeded() {
        guard let model = currentModel else {
            gridHeightConstraint?.constant = 0
            return
        }

        let availableWidth = view.bounds.width
        guard availableWidth > 0 else {
            return
        }

        let cellWidth = floor((availableWidth - 2) / 3)
        let rows = CGFloat((model.gridItems.count + 2) / 3)
        let height = rows > 0 ? (rows * cellWidth) + max(0, rows - 1) : 0

        gridHeightConstraint?.constant = height

        if let flowLayout = gridCollectionView.collectionViewLayout as? UICollectionViewFlowLayout,
           flowLayout.itemSize.width != cellWidth {
            flowLayout.itemSize = CGSize(width: cellWidth, height: cellWidth)
            flowLayout.invalidateLayout()
        }
    }

    private func openFeed(for postID: String) {
        guard let model = currentModel,
              feedController == nil,
              let sourceFrame = frameForGridItem(withID: postID, in: view)
        else {
            return
        }

        let feedController = InstagramPostFeedScreen(
            title: model.user.username,
            posts: model.feedPosts,
            initialPostID: postID
        )
        feedController.delegate = self
        feedController.loadViewIfNeeded()
        feedController.setChromeAlpha(0)
        feedController.setInteractionEnabled(false)
        feedController.prepareForPresentation()

        addChild(feedController)
        feedController.view.frame = view.bounds
        feedController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(feedController.view)
        setAnchorPoint(CGPoint(x: 0, y: 0), for: feedController.view)

        let scaleX = sourceFrame.width / max(view.bounds.width, 1)
        let scaleY = sourceFrame.height / max(view.bounds.height, 1)
        feedController.view.transform = CGAffineTransform(translationX: sourceFrame.minX, y: sourceFrame.minY)
            .scaledBy(x: scaleX, y: scaleY)
        feedController.didMove(toParent: self)

        hiddenGridPostID = postID
        currentFeedPostID = postID
        currentFeedTransitionContent = transitionContent(for: postID, posts: model.feedPosts)
        currentFeedTransitionFrame = sourceFrameInWindow(from: sourceFrame)
        isFeedDismissInProgress = false
        gridCollectionView.reloadData()

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            feedController.view.transform = .identity
            self.scrollView.alpha = 0.3
        } completion: { _ in
            feedController.setInteractionEnabled(true)

            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
                feedController.setChromeAlpha(1)
            }
        }

        self.feedController = feedController
    }

    private func dismissFeed() {
        guard let feedController else {
            return
        }

        let restoreID = currentFeedPostID ?? feedController.visiblePostID ?? feedController.initialPostID
        isFeedDismissInProgress = true
        hiddenGridPostID = restoreID
        gridCollectionView.reloadData()

        feedController.lockTransitionUpdates = true
        scrollGridItemIntoView(postID: restoreID)
        view.layoutIfNeeded()

        guard let targetFrame = frameForGridItem(withID: restoreID, in: view) else {
            cleanupFeedPresentation()
            return
        }

        currentFeedTransitionContent = feedController.visibleTransitionContent
        currentFeedTransitionFrame = feedController.visibleTransitionFrame

        let startFrameInWindow = currentFeedTransitionFrame ?? sourceFrameInWindow(from: view.bounds)
        let fallbackTargetTransform = transformForTargetFrame(targetFrame)

        if let startFrameInWindow,
           let snapshotImage = captureTransitionSnapshot(frameInWindow: startFrameInWindow) {
            let snapshotImageView = UIImageView(image: snapshotImage)
            snapshotImageView.contentMode = .scaleAspectFill
            snapshotImageView.clipsToBounds = true
            snapshotImageView.frame = view.convert(startFrameInWindow, from: nil)
            view.addSubview(snapshotImageView)

            feedController.view.isHidden = true

            UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseInOut]) {
                snapshotImageView.frame = targetFrame
                self.scrollView.alpha = 1
            } completion: { _ in
                snapshotImageView.removeFromSuperview()
                self.cleanupFeedPresentation(revealedPostID: restoreID)
            }

            return
        }

        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseInOut]) {
            feedController.setChromeAlpha(0)
            feedController.view.transform = fallbackTargetTransform
            self.scrollView.alpha = 1
        } completion: { _ in
            self.cleanupFeedPresentation(revealedPostID: restoreID)
        }
    }

    private func cleanupFeedPresentation(revealedPostID: String? = nil) {
        if let feedController {
            feedController.willMove(toParent: nil)
            feedController.view.removeFromSuperview()
            feedController.removeFromParent()
        }

        feedController = nil
        isFeedDismissInProgress = false
        currentFeedTransitionContent = nil
        currentFeedTransitionFrame = nil
        currentFeedPostID = nil
        scrollView.alpha = 1
        hiddenGridPostID = nil
        gridCollectionView.reloadData()

        if let revealedPostID {
            animateGridReturn(for: revealedPostID)
        }
    }

    private func frameForGridItem(withID postID: String, in coordinateSpace: UIView) -> CGRect? {
        guard let index = currentModel?.gridItems.firstIndex(where: { $0.id == postID }) else {
            return nil
        }

        let indexPath = IndexPath(item: index, section: 0)
        gridCollectionView.layoutIfNeeded()

        guard let attributes = gridCollectionView.layoutAttributesForItem(at: indexPath) else {
            return nil
        }

        return gridCollectionView.convert(attributes.frame, to: coordinateSpace)
    }

    private func scrollGridItemIntoView(postID: String) {
        guard let index = currentModel?.gridItems.firstIndex(where: { $0.id == postID }) else {
            return
        }

        let indexPath = IndexPath(item: index, section: 0)
        gridCollectionView.layoutIfNeeded()

        guard let attributes = gridCollectionView.layoutAttributesForItem(at: indexPath) else {
            return
        }

        let frameInContent = gridCollectionView.convert(attributes.frame, to: contentView)
        let visibleHeight = scrollView.bounds.height - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom
        let centeredOffset = frameInContent.midY - (visibleHeight / 2)
        let maxOffset = max(-scrollView.adjustedContentInset.top, contentView.bounds.height - visibleHeight)
        let targetOffsetY = max(-scrollView.adjustedContentInset.top, min(centeredOffset, maxOffset))

        scrollView.setContentOffset(CGPoint(x: 0, y: targetOffsetY), animated: false)
        view.layoutIfNeeded()
    }

    private func animateGridReturn(for postID: String) {
        guard let index = currentModel?.gridItems.firstIndex(where: { $0.id == postID }) else {
            return
        }

        let indexPath = IndexPath(item: index, section: 0)
        gridCollectionView.layoutIfNeeded()

        guard let cell = gridCollectionView.cellForItem(at: indexPath) as? ProfileGridCell else {
            return
        }

        cell.animateReturn()
    }

    private func transitionContent(for postID: String, posts: [InstagramPost]) -> InstagramFeedTransitionContent? {
        guard let post = posts.first(where: { $0.id == postID }),
              let media = post.media.first
        else {
            return nil
        }

        return InstagramFeedTransitionContent(postID: postID, media: media)
    }

    private func setAnchorPoint(_ anchorPoint: CGPoint, for view: UIView) {
        let oldOrigin = view.frame.origin
        view.layer.anchorPoint = anchorPoint
        view.frame.origin = oldOrigin
    }

    private func transformForTargetFrame(_ targetFrame: CGRect) -> CGAffineTransform {
        CGAffineTransform(translationX: targetFrame.minX, y: targetFrame.minY)
            .scaledBy(
                x: targetFrame.width / max(view.bounds.width, 1),
                y: targetFrame.height / max(view.bounds.height, 1)
            )
    }

    private func captureTransitionSnapshot(frameInWindow: CGRect) -> UIImage? {
        guard frameInWindow.width > 1,
              frameInWindow.height > 1,
              let window = view.window
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
            x: frameInWindow.minX * scale,
            y: frameInWindow.minY * scale,
            width: frameInWindow.width * scale,
            height: frameInWindow.height * scale
        ).integral.intersection(imageBounds)

        guard cropRect.isNull == false,
              cropRect.isEmpty == false,
              let croppedImage = snapshot.cgImage?.cropping(to: cropRect)
        else {
            return nil
        }

        return UIImage(cgImage: croppedImage, scale: scale, orientation: .up)
    }

    private func sourceFrameInWindow(from frameInView: CGRect) -> CGRect? {
        view.window.map { view.convert(frameInView, to: $0) }
    }
}

extension InstagramProfileScreen: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        currentModel?.gridItems.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ProfileGridCell.reuseIdentifier,
            for: indexPath
        ) as? ProfileGridCell,
              let item = currentModel?.gridItems[indexPath.item]
        else {
            return UICollectionViewCell()
        }

        cell.configure(item: item, isHiddenForTransition: hiddenGridPostID == item.id)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let postID = currentModel?.gridItems[indexPath.item].id else {
            return
        }

        openFeed(for: postID)
    }
}

extension InstagramProfileScreen: InstagramPostFeedScreenDelegate {
    func feedScreenDidRequestClose(_ screen: InstagramPostFeedScreen) {
        dismissFeed()
    }

    func feedScreen(
        _ screen: InstagramPostFeedScreen,
        didUpdateVisiblePostID postID: String?,
        transitionContent: InstagramFeedTransitionContent?,
        transitionFrame: CGRect?
    ) {
        guard isFeedDismissInProgress == false else {
            return
        }

        currentFeedPostID = postID
        currentFeedTransitionContent = transitionContent
        currentFeedTransitionFrame = transitionFrame
    }
}

private final class ProfileHeaderBarView: UIView {
    private let usernameLabel = UILabel()
    private let verifiedIconView = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))

    override init(frame: CGRect) {
        super.init(frame: frame)

        let backImage = UIImageView(image: UIImage(systemName: "chevron.left"))
        backImage.tintColor = .white
        backImage.contentMode = .scaleAspectFit
        backImage.translatesAutoresizingMaskIntoConstraints = false
        backImage.widthAnchor.constraint(equalToConstant: 22).isActive = true

        usernameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        usernameLabel.textColor = .white

        verifiedIconView.tintColor = AppTheme.verifiedBlue
        verifiedIconView.contentMode = .scaleAspectFit

        let titleStack = UIStackView(arrangedSubviews: [usernameLabel, verifiedIconView])
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 6

        let bellView = UIImageView(image: UIImage(systemName: "bell"))
        bellView.tintColor = .white
        bellView.contentMode = .scaleAspectFit
        bellView.translatesAutoresizingMaskIntoConstraints = false
        bellView.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let ellipsisView = UIImageView(image: UIImage(systemName: "ellipsis"))
        ellipsisView.tintColor = .white
        ellipsisView.contentMode = .scaleAspectFit
        ellipsisView.translatesAutoresizingMaskIntoConstraints = false
        ellipsisView.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let rightStack = UIStackView(arrangedSubviews: [bellView, ellipsisView])
        rightStack.axis = .horizontal
        rightStack.alignment = .center
        rightStack.spacing = 18

        let contentStack = UIStackView(arrangedSubviews: [backImage, titleStack, UIView(), rightStack])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 14
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(username: String, isVerified: Bool) {
        usernameLabel.text = username
        verifiedIconView.isHidden = isVerified == false
    }
}

private final class ProfileSummaryView: UIView {
    private let avatarView = ProfileAvatarView()
    private let displayNameLabel = UILabel()
    private let statsStack = UIStackView()
    private let bioStack = UIStackView()
    private let websiteButton = UIButton(type: .system)
    private let websiteRow = UIStackView()
    private let audioRow = UIStackView()
    private let audioLabel = UILabel()
    private let followedByRow = UIStackView()
    private let avatarStripView = OverlappingAvatarStripView()
    private let followedByLabel = UILabel()

    var onWebsiteTap: ((URL) -> Void)?
    private var websiteURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false

        displayNameLabel.font = .systemFont(ofSize: 18, weight: .bold)
        displayNameLabel.textColor = .white

        statsStack.axis = .horizontal
        statsStack.alignment = .fill
        statsStack.distribution = .fillEqually
        statsStack.spacing = 10

        bioStack.axis = .vertical
        bioStack.alignment = .leading
        bioStack.spacing = 5

        let linkImage = UIImageView(image: UIImage(systemName: "link"))
        linkImage.tintColor = AppTheme.linkColor

        websiteButton.tintColor = AppTheme.linkColor
        websiteButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        websiteButton.contentHorizontalAlignment = .leading
        websiteButton.addAction(UIAction { [weak self] _ in
            guard let self, let websiteURL else {
                return
            }

            onWebsiteTap?(websiteURL)
        }, for: .touchUpInside)

        websiteRow.addArrangedSubview(linkImage)
        websiteRow.addArrangedSubview(websiteButton)
        websiteRow.axis = .horizontal
        websiteRow.alignment = .center
        websiteRow.spacing = 8

        let audioImage = UIImageView(image: UIImage(systemName: "music.note"))
        audioImage.tintColor = .white
        audioImage.translatesAutoresizingMaskIntoConstraints = false
        audioImage.widthAnchor.constraint(equalToConstant: 16).isActive = true

        audioLabel.font = .systemFont(ofSize: 14, weight: .regular)
        audioLabel.textColor = .white
        audioLabel.numberOfLines = 2

        audioRow.axis = .horizontal
        audioRow.alignment = .top
        audioRow.spacing = 8
        audioRow.addArrangedSubview(audioImage)
        audioRow.addArrangedSubview(audioLabel)

        followedByLabel.font = .systemFont(ofSize: 14, weight: .regular)
        followedByLabel.textColor = .white
        followedByLabel.numberOfLines = 2

        followedByRow.axis = .horizontal
        followedByRow.alignment = .center
        followedByRow.spacing = 5
        followedByRow.addArrangedSubview(avatarStripView)
        followedByRow.addArrangedSubview(followedByLabel)

        let detailsStack = UIStackView(arrangedSubviews: [displayNameLabel, statsStack])
        detailsStack.axis = .vertical
        detailsStack.alignment = .fill
        detailsStack.spacing = 20

        let topRow = UIStackView(arrangedSubviews: [avatarView, detailsStack])
        topRow.axis = .horizontal
        topRow.alignment = .top
        topRow.spacing = 16

        let mainStack = UIStackView(arrangedSubviews: [topRow, bioStack])
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.spacing = 18
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: InstagramProfileScreenModel) {
        avatarView.configure(url: model.user.avatarURL)
        displayNameLabel.text = model.displayName

        statsStack.removeAllArrangedSubviews()
        model.stats.forEach { statsStack.addArrangedSubview(ProfileStatView(stat: $0)) }

        bioStack.removeAllArrangedSubviews()

        model.bioLines.forEach { line in
            let label = UILabel()
            label.font = .systemFont(ofSize: 14, weight: .regular)
            label.textColor = .white
            label.numberOfLines = 0
            label.text = line
            bioStack.addArrangedSubview(label)
        }

        websiteURL = model.websiteURL
        websiteButton.setTitle(model.websiteLabel, for: .normal)
        bioStack.addArrangedSubview(websiteRow)

        audioLabel.text = model.featuredAudioLabel
        bioStack.addArrangedSubview(audioRow)

        avatarStripView.configure(users: model.followedByUsers)
        followedByLabel.text = model.followedBySummary
        followedByRow.isHidden = model.followedBySummary.isEmpty
        bioStack.addArrangedSubview(followedByRow)
    }
}

private final class ProfileActionButtonsView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        let followingButton = makeButton(title: "Following", showsChevron: true)
        let messageButton = makeButton(title: "Message", showsChevron: false)

        let stack = UIStackView(arrangedSubviews: [followingButton, messageButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 12
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeButton(title: String, showsChevron: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.backgroundColor = AppTheme.buttonColor
        button.layer.cornerRadius = 12
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true

        if showsChevron {
            var configuration = UIButton.Configuration.plain()
            configuration.baseForegroundColor = .white
            configuration.attributedTitle = AttributedString(title, attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]))
            configuration.image = UIImage(systemName: "chevron.down")
            configuration.imagePlacement = .trailing
            configuration.imagePadding = 4
            button.configuration = configuration
        } else {
            button.setTitle(title, for: .normal)
        }

        return button
    }
}

private final class ProfileHighlightsView: UIView {
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 18
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 26),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 22),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -22),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(highlights: [InstagramProfileHighlight]) {
        stackView.removeAllArrangedSubviews()

        for highlight in highlights {
            stackView.addArrangedSubview(HighlightItemView(highlight: highlight))
        }
    }
}

private final class ProfileTabsView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        let icons = [
            ("square.grid.3x3.fill", true),
            ("play.square", false),
            ("arrow.2.squarepath", false),
            ("person.crop.square", false)
        ]

        let iconViews = icons.map { icon, isSelected -> UIView in
            let imageView = UIImageView(image: UIImage(systemName: icon))
            imageView.tintColor = isSelected ? .white : AppTheme.secondaryTextColor
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.heightAnchor.constraint(equalToConstant: 28).isActive = true
            return imageView
        }

        let iconStack = UIStackView(arrangedSubviews: iconViews)
        iconStack.translatesAutoresizingMaskIntoConstraints = false
        iconStack.axis = .horizontal
        iconStack.alignment = .center
        iconStack.distribution = .fillEqually

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = AppTheme.dividerColor

        let indicator = UIView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white

        addSubview(iconStack)
        addSubview(divider)
        addSubview(indicator)

        NSLayoutConstraint.activate([
            iconStack.topAnchor.constraint(equalTo: topAnchor),
            iconStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            iconStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),

            divider.topAnchor.constraint(equalTo: iconStack.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),

            indicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            indicator.bottomAnchor.constraint(equalTo: divider.bottomAnchor, constant: 1),
            indicator.widthAnchor.constraint(equalToConstant: 88),
            indicator.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ProfileAvatarView: UIView {
    private let imageView = RemoteImageView()
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false

        gradientLayer.colors = [
            UIColor(red: 0.98, green: 0.56, blue: 0.23, alpha: 1).cgColor,
            UIColor(red: 0.96, green: 0.17, blue: 0.44, alpha: 1).cgColor,
            UIColor(red: 0.49, green: 0.24, blue: 0.98, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        let outerRing = UIView()
        outerRing.translatesAutoresizingMaskIntoConstraints = false
        outerRing.layer.cornerRadius = 44
        outerRing.layer.masksToBounds = true
        outerRing.layer.addSublayer(gradientLayer)

        let middleRing = UIView()
        middleRing.translatesAutoresizingMaskIntoConstraints = false
        middleRing.backgroundColor = .white
        middleRing.layer.cornerRadius = 40

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 36
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.08)

        addSubview(outerRing)
        outerRing.addSubview(middleRing)
        middleRing.addSubview(imageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 88),
            heightAnchor.constraint(equalToConstant: 88),

            outerRing.topAnchor.constraint(equalTo: topAnchor),
            outerRing.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerRing.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerRing.bottomAnchor.constraint(equalTo: bottomAnchor),

            middleRing.centerXAnchor.constraint(equalTo: outerRing.centerXAnchor),
            middleRing.centerYAnchor.constraint(equalTo: outerRing.centerYAnchor),
            middleRing.widthAnchor.constraint(equalToConstant: 80),
            middleRing.heightAnchor.constraint(equalToConstant: 80),

            imageView.centerXAnchor.constraint(equalTo: middleRing.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: middleRing.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 72),
            imageView.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(url: URL) {
        imageView.setImageURL(url)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let outerRing = subviews.first else {
            return
        }

        gradientLayer.frame = outerRing.bounds
    }
}

private final class ProfileStatView: UIView {
    init(stat: InstagramProfileStat) {
        super.init(frame: .zero)

        let valueLabel = UILabel()
        valueLabel.font = .systemFont(ofSize: 18, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.8
        valueLabel.text = stat.value

        let labelLabel = UILabel()
        labelLabel.font = .systemFont(ofSize: 14, weight: .medium)
        labelLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        labelLabel.textAlignment = .center
        labelLabel.adjustsFontSizeToFitWidth = true
        labelLabel.minimumScaleFactor = 0.75
        labelLabel.text = stat.label

        let stack = UIStackView(arrangedSubviews: [valueLabel, labelLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 4
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class OverlappingAvatarStripView: UIView {
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = -10
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(users: [InstagramUser]) {
        stackView.removeAllArrangedSubviews()

        for user in users {
            let imageView = RemoteImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.layer.cornerRadius = 17
            imageView.layer.borderWidth = 2
            imageView.layer.borderColor = AppTheme.backgroundColor.cgColor
            imageView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            imageView.widthAnchor.constraint(equalToConstant: 34).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 34).isActive = true
            imageView.setImageURL(user.avatarURL)
            stackView.addArrangedSubview(imageView)
        }
    }
}

private final class HighlightItemView: UIView {
    init(highlight: InstagramProfileHighlight) {
        super.init(frame: .zero)

        let bubble = HighlightBubbleView()
        bubble.configure(url: highlight.imageURL)

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.text = highlight.title

        let stack = UIStackView(arrangedSubviews: [bubble, titleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 82),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class HighlightBubbleView: UIView {
    private let imageView = RemoteImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 82).isActive = true
        heightAnchor.constraint(equalToConstant: 82).isActive = true

        let outerCircle = UIView()
        outerCircle.translatesAutoresizingMaskIntoConstraints = false
        outerCircle.layer.cornerRadius = 41
        outerCircle.layer.borderWidth = 1
        outerCircle.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 36
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.08)

        addSubview(outerCircle)
        outerCircle.addSubview(imageView)

        NSLayoutConstraint.activate([
            outerCircle.topAnchor.constraint(equalTo: topAnchor),
            outerCircle.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerCircle.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerCircle.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: outerCircle.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: outerCircle.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 72),
            imageView.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(url: URL?) {
        imageView.setImageURL(url)
    }
}

private final class ProfileErrorView: UIView {
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let iconView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        iconView.tintColor = .systemYellow
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.text = "Couldn’t load the profile"

        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
        messageLabel.textColor = AppTheme.secondaryTextColor
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(message: String) {
        messageLabel.text = message
    }
}

private final class ProfileGridCell: UICollectionViewCell {
    static let reuseIdentifier = "ProfileGridCell"

    private let imageView = RemoteImageView()
    private let overlayBackgroundView = UIView()
    private let overlayImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .clear
        contentView.clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        contentView.addSubview(imageView)

        overlayBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        overlayBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        overlayBackgroundView.layer.cornerRadius = 9
        contentView.addSubview(overlayBackgroundView)

        overlayImageView.translatesAutoresizingMaskIntoConstraints = false
        overlayImageView.tintColor = .white
        overlayImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        overlayBackgroundView.addSubview(overlayImageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            overlayBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            overlayBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            overlayBackgroundView.widthAnchor.constraint(equalToConstant: 28),
            overlayBackgroundView.heightAnchor.constraint(equalToConstant: 28),

            overlayImageView.centerXAnchor.constraint(equalTo: overlayBackgroundView.centerXAnchor),
            overlayImageView.centerYAnchor.constraint(equalTo: overlayBackgroundView.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.cancelImageLoad()
        contentView.transform = .identity
    }

    func configure(item: InstagramProfileGridItem, isHiddenForTransition: Bool) {
        imageView.setImageURL(item.imageURL)
        imageView.alpha = isHiddenForTransition ? 0.001 : 1

        if let overlaySymbol = item.overlaySymbol, isHiddenForTransition == false {
            overlayBackgroundView.isHidden = false
            overlayImageView.image = UIImage(systemName: overlaySymbol)
        } else {
            overlayBackgroundView.isHidden = true
            overlayImageView.image = nil
        }
    }

    func animateReturn() {
        contentView.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)

        UIView.animate(
            withDuration: 0.42,
            delay: 0,
            usingSpringWithDamping: 0.84,
            initialSpringVelocity: 0,
            options: [.curveEaseOut]
        ) {
            self.contentView.transform = .identity
        }
    }
}
