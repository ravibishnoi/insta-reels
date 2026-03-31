//
//  InstagramPostFeedScreen.swift
//  insta-reels
//
//  Created by Codex on 26/03/26.
//

import AVFoundation
import UIKit

struct InstagramFeedTransitionContent: Equatable {
    let postID: String
    let media: InstagramMedia
}

protocol InstagramPostFeedScreenDelegate: AnyObject {
    func feedScreenDidRequestClose(_ screen: InstagramPostFeedScreen)
    func feedScreen(
        _ screen: InstagramPostFeedScreen,
        didUpdateVisiblePostID postID: String?,
        transitionContent: InstagramFeedTransitionContent?,
        transitionFrame: CGRect?
    )
}

final class InstagramPostFeedScreen: UIViewController {
    weak var delegate: InstagramPostFeedScreenDelegate?

    let posts: [InstagramPost]
    let initialPostID: String

    private let topBar = FeedTopBarView()
    private let collectionView: UICollectionView

    private var hasScrolledToInitialPost = false
    private var chromeAlpha: CGFloat = 1

    private(set) var visiblePostID: String?
    private(set) var visibleTransitionContent: InstagramFeedTransitionContent?
    private(set) var visibleTransitionFrame: CGRect?

    var lockTransitionUpdates = false

    init(title: String, posts: [InstagramPost], initialPostID: String) {
        self.posts = posts
        self.initialPostID = initialPostID

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 26
        layout.minimumInteritemSpacing = 0

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.onClose = { [weak self] in
            guard let self else {
                return
            }

            delegate?.feedScreenDidRequestClose(self)
        }
        view.addSubview(topBar)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 32, right: 0)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FeedPostCell.self, forCellWithReuseIdentifier: FeedPostCell.reuseIdentifier)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            collectionView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout,
           layout.itemSize.width != collectionView.bounds.width {
            layout.itemSize = CGSize(
                width: collectionView.bounds.width,
                height: collectionView.bounds.height
            )
            layout.invalidateLayout()
        }

        scrollToInitialPostIfNeeded()
        updateVisibleState()
    }

    func prepareForPresentation() {
        hasScrolledToInitialPost = false
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
    }

    func setChromeAlpha(_ alpha: CGFloat) {
        chromeAlpha = alpha
        topBar.alpha = alpha

        collectionView.visibleCells
            .compactMap { $0 as? FeedPostCell }
            .forEach { $0.setChromeAlpha(alpha) }
    }

    func setInteractionEnabled(_ enabled: Bool) {
        topBar.isUserInteractionEnabled = enabled
        collectionView.isUserInteractionEnabled = enabled
    }

    private func scrollToInitialPostIfNeeded() {
        guard hasScrolledToInitialPost == false,
              collectionView.bounds.height > 0
        else {
            return
        }

        let targetIndex = posts.firstIndex(where: { $0.id == initialPostID }) ?? 0
        let indexPath = IndexPath(item: targetIndex, section: 0)

        collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
        hasScrolledToInitialPost = true
    }

    private func updateVisibleState() {
        guard lockTransitionUpdates == false else {
            return
        }

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems

        let currentIndexPath = visibleIndexPaths.min { lhs, rhs in
            guard let left = collectionView.layoutAttributesForItem(at: lhs),
                  let right = collectionView.layoutAttributesForItem(at: rhs)
            else {
                return false
            }

            let leftDistance = abs(left.frame.minY - collectionView.contentOffset.y)
            let rightDistance = abs(right.frame.minY - collectionView.contentOffset.y)
            return leftDistance < rightDistance
        }

        for cell in collectionView.visibleCells {
            guard let feedCell = cell as? FeedPostCell,
                  let indexPath = collectionView.indexPath(for: feedCell)
            else {
                continue
            }

            let isCurrentVisible = indexPath == currentIndexPath
            feedCell.setCurrentVisible(isCurrentVisible)
            feedCell.setChromeAlpha(chromeAlpha)
        }

        guard let currentIndexPath,
              posts.indices.contains(currentIndexPath.item),
              let currentCell = collectionView.cellForItem(at: currentIndexPath) as? FeedPostCell
        else {
            visiblePostID = nil
            visibleTransitionContent = nil
            visibleTransitionFrame = nil
            delegate?.feedScreen(self, didUpdateVisiblePostID: nil, transitionContent: nil, transitionFrame: nil)
            return
        }

        let post = posts[currentIndexPath.item]
        visiblePostID = post.id
        visibleTransitionContent = currentCell.currentTransitionContent
        visibleTransitionFrame = currentCell.currentTransitionFrameInWindow()
        delegate?.feedScreen(
            self,
            didUpdateVisiblePostID: visiblePostID,
            transitionContent: visibleTransitionContent,
            transitionFrame: visibleTransitionFrame
        )
    }
}

extension InstagramPostFeedScreen: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        posts.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FeedPostCell.reuseIdentifier,
            for: indexPath
        ) as? FeedPostCell else {
            return UICollectionViewCell()
        }

        let post = posts[indexPath.item]
        cell.delegate = self
        cell.configure(post: post, chromeAlpha: chromeAlpha)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = collectionView.bounds.width
        let post = posts[indexPath.item]
        return CGSize(width: width, height: FeedPostCell.height(for: post, width: width))
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisibleState()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateVisibleState()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate == false {
            updateVisibleState()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateVisibleState()
    }
}

extension InstagramPostFeedScreen: FeedPostCellDelegate {
    func feedPostCellDidUpdateVisibleMedia(_ cell: FeedPostCell) {
        guard lockTransitionUpdates == false,
              let indexPath = collectionView.indexPath(for: cell),
              posts.indices.contains(indexPath.item),
              visiblePostID == posts[indexPath.item].id
        else {
            return
        }

        visibleTransitionContent = cell.currentTransitionContent
        visibleTransitionFrame = cell.currentTransitionFrameInWindow()
        delegate?.feedScreen(
            self,
            didUpdateVisiblePostID: visiblePostID,
            transitionContent: visibleTransitionContent,
            transitionFrame: visibleTransitionFrame
        )
    }
}

private final class FeedTopBarView: UIView {
    var onClose: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.black.withAlphaComponent(0.97)

        let titleLabel = UILabel()
        titleLabel.text = "Posts"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        let backButton = UIButton(type: .system)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = .white
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .touchUpInside)

        let titleContainer = UIView()
        titleContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleContainer)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(backButton)
        titleContainer.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleContainer.topAnchor.constraint(equalTo: topAnchor),
            titleContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerXAnchor.constraint(equalTo: titleContainer.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

protocol FeedPostCellDelegate: AnyObject {
    func feedPostCellDidUpdateVisibleMedia(_ cell: FeedPostCell)
}

final class FeedPostCell: UICollectionViewCell {
    static let reuseIdentifier = "FeedPostCell"

    weak var delegate: FeedPostCellDelegate?

    private let headerView = FeedPostHeaderView()
    private let mediaPagerView = FeedMediaPagerView()
    private let actionRowView = FeedActionRowView()
    private let metaView = FeedMetaView()
    private let contentStack = UIStackView()
    private var mediaHeightConstraint: NSLayoutConstraint?

    private(set) var post: InstagramPost?
    private(set) var currentTransitionContent: InstagramFeedTransitionContent?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .black

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 12
        contentView.addSubview(contentStack)

        mediaPagerView.delegate = self

        contentStack.addArrangedSubview(headerView)
        contentStack.addArrangedSubview(mediaPagerView)
        contentStack.addArrangedSubview(actionRowView)
        contentStack.addArrangedSubview(metaView)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        mediaHeightConstraint = mediaPagerView.heightAnchor.constraint(equalToConstant: 300)
        mediaHeightConstraint?.isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        post = nil
        currentTransitionContent = nil
        headerView.prepareForReuse()
        mediaPagerView.prepareForReuse()
        contentView.transform = .identity
    }

    func configure(post: InstagramPost, chromeAlpha: CGFloat) {
        self.post = post

        headerView.configure(post: post)
        actionRowView.configure(post: post)
        metaView.configure(post: post)
        mediaPagerView.configure(postID: post.id, media: post.media, isCurrentVisible: false)

        let mediaHeight = Self.mediaHeight(for: post, width: bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width)
        mediaHeightConstraint?.constant = mediaHeight

        setChromeAlpha(chromeAlpha)
        currentTransitionContent = mediaPagerView.currentTransitionContent
    }

    func setCurrentVisible(_ isCurrentVisible: Bool) {
        mediaPagerView.setCurrentVisible(isCurrentVisible)
        currentTransitionContent = mediaPagerView.currentTransitionContent
    }

    func setChromeAlpha(_ alpha: CGFloat) {
        headerView.alpha = alpha
        actionRowView.alpha = alpha
        metaView.alpha = alpha
    }

    func currentTransitionFrameInWindow() -> CGRect? {
        mediaPagerView.currentMediaFrameInWindow()
    }

    static func height(for post: InstagramPost, width: CGFloat) -> CGFloat {
        let mediaHeight = mediaHeight(for: post, width: width)
        let contentWidth = max(width - 28, 1)
        let captionHeight = textHeight(
            text: "\(post.author.username) \(post.caption)",
            width: contentWidth,
            font: .systemFont(ofSize: 14),
            maxLines: 3
        )

        var metaHeight: CGFloat = 0
        metaHeight += 17
        metaHeight += 6
        metaHeight += captionHeight

        if post.metrics.commentCount > 0 {
            metaHeight += 6 + 17
        }

        if post.isSponsored, post.sponsorName != nil {
            metaHeight += 6 + 16
        }

        metaHeight += 6 + 15

        let headerHeight: CGFloat = post.locationName == nil ? 34 : 38
        return 12 + headerHeight + 12 + mediaHeight + 12 + 24 + 12 + metaHeight + 12
    }

    private static func mediaHeight(for post: InstagramPost, width: CGFloat) -> CGFloat {
        guard let firstMedia = post.media.first else {
            return width
        }

        return width / clampedAspectRatio(for: firstMedia)
    }

    private static func textHeight(text: String, width: CGFloat, font: UIFont, maxLines: Int) -> CGFloat {
        let boundingRect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )

        let lineHeight = font.lineHeight
        return min(ceil(boundingRect.height), lineHeight * CGFloat(maxLines))
    }
}

extension FeedPostCell: FeedMediaPagerViewDelegate {
    func feedMediaPagerViewDidUpdateVisibleMedia(_ view: FeedMediaPagerView) {
        currentTransitionContent = view.currentTransitionContent
        delegate?.feedPostCellDidUpdateVisibleMedia(self)
    }
}

private final class FeedPostHeaderView: UIView {
    private let avatarView = RemoteImageView()
    private let usernameLabel = UILabel()
    private let verifiedImageView = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
    private let locationLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.layer.cornerRadius = 17
        avatarView.backgroundColor = UIColor.white.withAlphaComponent(0.08)

        usernameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        usernameLabel.textColor = .white

        verifiedImageView.tintColor = AppTheme.verifiedBlue
        verifiedImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)

        locationLabel.font = .systemFont(ofSize: 12, weight: .medium)
        locationLabel.textColor = AppTheme.secondaryTextColor

        let usernameRow = UIStackView(arrangedSubviews: [usernameLabel, verifiedImageView])
        usernameRow.axis = .horizontal
        usernameRow.alignment = .center
        usernameRow.spacing = 4

        let labelsStack = UIStackView(arrangedSubviews: [usernameRow, locationLabel])
        labelsStack.axis = .vertical
        labelsStack.alignment = .leading
        labelsStack.spacing = 2

        let ellipsisImageView = UIImageView(image: UIImage(systemName: "ellipsis"))
        ellipsisImageView.tintColor = .white
        ellipsisImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)

        let contentStack = UIStackView(arrangedSubviews: [avatarView, labelsStack, UIView(), ellipsisImageView])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 10
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 34),
            avatarView.heightAnchor.constraint(equalToConstant: 34),

            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(post: InstagramPost) {
        avatarView.setImageURL(post.author.avatarURL)
        usernameLabel.text = post.author.username
        verifiedImageView.isHidden = post.author.isVerified == false
        locationLabel.text = post.locationName
        locationLabel.isHidden = post.locationName == nil
    }

    func prepareForReuse() {
        avatarView.cancelImageLoad()
    }
}

protocol FeedMediaPagerViewDelegate: AnyObject {
    func feedMediaPagerViewDidUpdateVisibleMedia(_ view: FeedMediaPagerView)
}

final class FeedMediaPagerView: UIView {
    weak var delegate: FeedMediaPagerViewDelegate?

    private let collectionView: UICollectionView
    private let pageLabel = UILabel()

    private var postID: String?
    private var media: [InstagramMedia] = []
    private var currentPage = 0
    private var isCurrentVisible = false

    var currentTransitionContent: InstagramFeedTransitionContent? {
        guard let postID,
              media.indices.contains(currentPage)
        else {
            return nil
        }

        return InstagramFeedTransitionContent(postID: postID, media: media[currentPage])
    }

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: frame)

        backgroundColor = .black
        clipsToBounds = true

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FeedMediaPageCell.self, forCellWithReuseIdentifier: FeedMediaPageCell.reuseIdentifier)
        addSubview(collectionView)

        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        pageLabel.textColor = .white
        pageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        pageLabel.layer.cornerRadius = 14
        pageLabel.layer.masksToBounds = true
        pageLabel.textAlignment = .center
        addSubview(pageLabel)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            pageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            pageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            pageLabel.heightAnchor.constraint(equalToConstant: 28),
            pageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 46)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout,
           layout.itemSize != bounds.size {
            layout.itemSize = bounds.size
            layout.invalidateLayout()
        }
    }

    func configure(postID: String, media: [InstagramMedia], isCurrentVisible: Bool) {
        self.postID = postID
        self.media = media
        self.isCurrentVisible = isCurrentVisible
        currentPage = min(currentPage, max(media.count - 1, 0))
        collectionView.setContentOffset(CGPoint(x: bounds.width * CGFloat(currentPage), y: 0), animated: false)
        collectionView.reloadData()
        updatePageLabel()
    }

    func setCurrentVisible(_ isCurrentVisible: Bool) {
        self.isCurrentVisible = isCurrentVisible
        updateVisiblePageActivity()
        delegate?.feedMediaPagerViewDidUpdateVisibleMedia(self)
    }

    func currentMediaFrameInWindow() -> CGRect? {
        window.map { convert(bounds, to: $0) }
    }

    func prepareForReuse() {
        postID = nil
        media = []
        currentPage = 0
        isCurrentVisible = false
        collectionView.setContentOffset(.zero, animated: false)
        collectionView.reloadData()
    }

    private func updatePageLabel() {
        pageLabel.isHidden = media.count <= 1
        pageLabel.text = "\(currentPage + 1)/\(max(media.count, 1))"
    }

    private func updateVisiblePageActivity() {
        for cell in collectionView.visibleCells {
            guard let mediaCell = cell as? FeedMediaPageCell,
                  let indexPath = collectionView.indexPath(for: mediaCell)
            else {
                continue
            }

            mediaCell.setActive(isCurrentVisible && indexPath.item == currentPage)
        }
    }

    private func syncCurrentPage() {
        let width = max(collectionView.bounds.width, 1)
        currentPage = min(max(Int(round(collectionView.contentOffset.x / width)), 0), max(media.count - 1, 0))
        updatePageLabel()
        updateVisiblePageActivity()
        delegate?.feedMediaPagerViewDidUpdateVisibleMedia(self)
    }
}

extension FeedMediaPagerView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        media.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FeedMediaPageCell.reuseIdentifier,
            for: indexPath
        ) as? FeedMediaPageCell else {
            return UICollectionViewCell()
        }

        cell.configure(media: media[indexPath.item], isActive: isCurrentVisible && indexPath.item == currentPage)
        return cell
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        syncCurrentPage()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate == false {
            syncCurrentPage()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        syncCurrentPage()
    }
}

private final class FeedMediaPageCell: UICollectionViewCell {
    static let reuseIdentifier = "FeedMediaPageCell"

    private let imageView = RemoteImageView()
    private let playFallbackView = UIImageView(image: UIImage(systemName: "play.circle.fill"))
    private let videoPlayerView = FeedInlineVideoPlayerView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .black

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        contentView.addSubview(imageView)

        videoPlayerView.translatesAutoresizingMaskIntoConstraints = false
        videoPlayerView.isHidden = true
        contentView.addSubview(videoPlayerView)

        playFallbackView.translatesAutoresizingMaskIntoConstraints = false
        playFallbackView.tintColor = UIColor.white.withAlphaComponent(0.92)
        playFallbackView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 54, weight: .regular)
        playFallbackView.isHidden = true
        contentView.addSubview(playFallbackView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            videoPlayerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            videoPlayerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            videoPlayerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            videoPlayerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            playFallbackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            playFallbackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.cancelImageLoad()
        videoPlayerView.reset()
        playFallbackView.isHidden = true
    }

    func configure(media: InstagramMedia, isActive: Bool) {
        imageView.setImageURL(media.thumbnailURL ?? media.mediaURL)
        accessibilityLabel = media.altText

        if media.type == .video, let playbackURL = InstagramMediaPlaybackResolver().playbackURL(for: media) {
            videoPlayerView.isHidden = false
            playFallbackView.isHidden = true
            videoPlayerView.configure(url: playbackURL, isActive: isActive)
        } else if media.type == .video {
            videoPlayerView.reset()
            videoPlayerView.isHidden = true
            playFallbackView.isHidden = false
        } else {
            videoPlayerView.reset()
            videoPlayerView.isHidden = true
            playFallbackView.isHidden = true
        }
    }

    func setActive(_ isActive: Bool) {
        videoPlayerView.setActive(isActive)
    }
}

private final class FeedInlineVideoPlayerView: UIView {
    private let playerContainerView = FeedPlayerContainerView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let muteButton = UIButton(type: .system)

    private var playbackController: FeedVideoPlaybackController?
    private var currentURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true

        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.playerLayer.videoGravity = .resizeAspectFill
        addSubview(playerContainerView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        addSubview(activityIndicator)

        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.tintColor = .white
        muteButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        muteButton.layer.cornerRadius = 17
        muteButton.addAction(UIAction { [weak self] _ in
            self?.playbackController?.toggleMuted()
        }, for: .touchUpInside)
        addSubview(muteButton)

        NSLayoutConstraint.activate([
            playerContainerView.topAnchor.constraint(equalTo: topAnchor),
            playerContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            playerContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),

            muteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            muteButton.widthAnchor.constraint(equalToConstant: 34),
            muteButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        updateUI(isReadyToDisplay: false, isMuted: true)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(url: URL, isActive: Bool) {
        if currentURL != url {
            playbackController = FeedVideoPlaybackController(url: url)
            playbackController?.onStateChange = { [weak self] controller in
                self?.updateUI(isReadyToDisplay: controller.isReadyToDisplay, isMuted: controller.isMuted)
            }
            playerContainerView.playerLayer.player = playbackController?.player
            currentURL = url
        }

        playbackController?.setActive(isActive)
        updateUI(
            isReadyToDisplay: playbackController?.isReadyToDisplay ?? false,
            isMuted: playbackController?.isMuted ?? true
        )
    }

    func setActive(_ active: Bool) {
        playbackController?.setActive(active)
    }

    func reset() {
        playbackController?.setActive(false)
        playbackController = nil
        currentURL = nil
        playerContainerView.playerLayer.player = nil
        updateUI(isReadyToDisplay: false, isMuted: true)
    }

    private func updateUI(isReadyToDisplay: Bool, isMuted: Bool) {
        playerContainerView.alpha = isReadyToDisplay ? 1 : 0.001
        isReadyToDisplay ? activityIndicator.stopAnimating() : activityIndicator.startAnimating()
        muteButton.setImage(
            UIImage(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"),
            for: .normal
        )
    }
}

private final class FeedVideoPlaybackController {
    let player: AVPlayer

    private(set) var isMuted = true
    private(set) var isReadyToDisplay = false
    var onStateChange: ((FeedVideoPlaybackController) -> Void)?

    private var isActive = false
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?

    init(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 2
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false

        player = AVPlayer(playerItem: playerItem)
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = true

        statusObservation = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else {
                return
            }

            self.isReadyToDisplay = item.status == .readyToPlay
            DispatchQueue.main.async {
                self.onStateChange?(self)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }

            self.player.seek(to: .zero)
            if self.isActive {
                self.player.play()
            }
        }
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        statusObservation?.invalidate()
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
        onStateChange?(self)
    }
}

private final class FeedPlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        guard let layer = layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer backing.")
        }

        return layer
    }
}

private final class FeedActionRowView: UIView {
    private let heartView = UIImageView()
    private let commentView = UIImageView(image: UIImage(systemName: "bubble.right"))
    private let shareView = UIImageView(image: UIImage(systemName: "paperplane"))
    private let bookmarkView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        [heartView, commentView, shareView, bookmarkView].forEach {
            $0.tintColor = .white
            $0.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        }

        let leftStack = UIStackView(arrangedSubviews: [heartView, commentView, shareView])
        leftStack.axis = .horizontal
        leftStack.alignment = .center
        leftStack.spacing = 16

        let contentStack = UIStackView(arrangedSubviews: [leftStack, UIView(), bookmarkView])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(post: InstagramPost) {
        heartView.image = UIImage(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
        heartView.tintColor = post.isLikedByCurrentUser ? .systemRed : .white
        bookmarkView.image = UIImage(systemName: post.isSavedByCurrentUser ? "bookmark.fill" : "bookmark")
        bookmarkView.tintColor = .white
    }
}

private final class FeedMetaView: UIView {
    private let likesLabel = UILabel()
    private let captionLabel = UILabel()
    private let commentsLabel = UILabel()
    private let sponsoredLabel = UILabel()
    private let timestampLabel = UILabel()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        likesLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        likesLabel.textColor = .white

        captionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        captionLabel.textColor = .white
        captionLabel.numberOfLines = 3

        commentsLabel.font = .systemFont(ofSize: 14, weight: .medium)
        commentsLabel.textColor = AppTheme.secondaryTextColor

        sponsoredLabel.font = .systemFont(ofSize: 13, weight: .medium)
        sponsoredLabel.textColor = AppTheme.secondaryTextColor

        timestampLabel.font = .systemFont(ofSize: 12, weight: .medium)
        timestampLabel.textColor = AppTheme.secondaryTextColor

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.addArrangedSubview(likesLabel)
        stack.addArrangedSubview(captionLabel)
        stack.addArrangedSubview(commentsLabel)
        stack.addArrangedSubview(sponsoredLabel)
        stack.addArrangedSubview(timestampLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(post: InstagramPost) {
        likesLabel.text = "\(post.metrics.likeCount.formatted()) likes"

        let captionText = NSMutableAttributedString(
            string: "\(post.author.username) ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
        )
        captionText.append(
            NSAttributedString(
                string: post.caption,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.white
                ]
            )
        )
        captionLabel.attributedText = captionText

        commentsLabel.isHidden = post.metrics.commentCount == 0
        commentsLabel.text = "View all \(post.metrics.commentCount.formatted()) comments"

        if post.isSponsored, let sponsorName = post.sponsorName {
            sponsoredLabel.isHidden = false
            sponsoredLabel.text = "Sponsored • \(sponsorName)"
        } else {
            sponsoredLabel.isHidden = true
            sponsoredLabel.text = nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        timestampLabel.text = formatter.string(from: post.createdAt).uppercased()
    }
}

private func clampedAspectRatio(for media: InstagramMedia) -> CGFloat {
    let ratio = CGFloat(media.width) / CGFloat(max(media.height, 1))
    return min(max(ratio, 0.5625), 1.0)
}
