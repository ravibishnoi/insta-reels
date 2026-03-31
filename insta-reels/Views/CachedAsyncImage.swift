//
//  CachedAsyncImage.swift
//  insta-reels
//
//  Created by Codex on 28/03/26.
//

import CryptoKit
import Foundation
import UIKit

final class RemoteImageView: UIImageView {
    private var loadTask: Task<Void, Never>?
    private var loadedURL: URL?
    private var currentURL: URL?

    var onLoadStateChange: ((Bool) -> Void)?

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        clipsToBounds = true
        contentMode = .scaleAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImageURL(_ url: URL?, placeholder: UIImage? = nil) {
        loadTask?.cancel()
        currentURL = url
        loadedURL = nil
        image = placeholder
        onLoadStateChange?(true)

        guard let url else {
            onLoadStateChange?(false)
            return
        }

        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let data = try await RemoteImageCache.shared.data(for: url)
                try Task.checkCancellation()

                guard currentURL == url else {
                    return
                }

                let decodedImage = UIImage(data: data)?.preparingForDisplay() ?? UIImage(data: data)

                await MainActor.run {
                    guard self.currentURL == url else {
                        return
                    }

                    self.loadedURL = url
                    self.image = decodedImage
                    self.onLoadStateChange?(false)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard self.currentURL == url else {
                        return
                    }

                    self.loadedURL = nil
                    self.onLoadStateChange?(false)
                }
            }
        }
    }

    func cancelImageLoad() {
        loadTask?.cancel()
        loadTask = nil
    }
}

private actor RemoteImageCache {
    static let shared = RemoteImageCache()

    private let fileManager = FileManager.default
    private let memoryCache = NSCache<NSURL, NSData>()
    private let session: URLSession
    private let cacheDirectory: URL

    private var inFlightTasks: [URL: Task<Data, Error>] = [:]

    init() {
        memoryCache.countLimit = 300
        memoryCache.totalCostLimit = 64 * 1024 * 1024

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            diskPath: "insta-reels-url-cache"
        )
        session = URLSession(configuration: configuration)

        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        cacheDirectory = baseDirectory.appendingPathComponent("insta-reels-image-cache", isDirectory: true)

        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func data(for url: URL) async throws -> Data {
        if let cachedObject = memoryCache.object(forKey: url as NSURL) {
            return cachedObject as Data
        }

        if let cachedData = readFromDisk(for: url) {
            memoryCache.setObject(NSData(data: cachedData), forKey: url as NSURL, cost: cachedData.count)
            return cachedData
        }

        if let task = inFlightTasks[url] {
            return try await task.value
        }

        let session = self.session
        let task = Task<Data, Error> {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ..< 300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            return data
        }

        inFlightTasks[url] = task
        defer { inFlightTasks[url] = nil }

        let data = try await task.value
        memoryCache.setObject(NSData(data: data), forKey: url as NSURL, cost: data.count)
        writeToDisk(data, for: url)
        return data
    }

    private func readFromDisk(for url: URL) -> Data? {
        let fileURL = fileURL(for: url)
        return try? Data(contentsOf: fileURL)
    }

    private func writeToDisk(_ data: Data, for url: URL) {
        let fileURL = fileURL(for: url)
        try? data.write(to: fileURL, options: .atomic)
    }

    private func fileURL(for url: URL) -> URL {
        cacheDirectory.appendingPathComponent(cacheKey(for: url))
    }

    private func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
