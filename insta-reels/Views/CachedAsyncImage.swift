//
//  CachedAsyncImage.swift
//  insta-reels
//
//  Created by Codex on 28/03/26.
//

import CryptoKit
import Combine
import Foundation
import SwiftUI
import UIKit

enum CachedAsyncImagePhase {
    case empty
    case success(Image)
    case failure
}

struct CachedAsyncImage<Content: View>: View {
    let url: URL?

    private let content: (CachedAsyncImagePhase) -> Content

    @StateObject private var loader: CachedAsyncImageLoader

    init(
        url: URL?,
        @ViewBuilder content: @escaping (CachedAsyncImagePhase) -> Content
    ) {
        self.url = url
        self.content = content
        _loader = StateObject(wrappedValue: CachedAsyncImageLoader())
    }

    var body: some View {
        content(loader.phase)
            .task(id: url) {
                await loader.load(from: url)
            }
    }
}

@MainActor
private final class CachedAsyncImageLoader: ObservableObject {
    @Published private(set) var phase: CachedAsyncImagePhase = .empty

    private var requestedURL: URL?
    private var loadedURL: URL?

    init() {}

    func load(from url: URL?) async {
        requestedURL = url

        guard let url else {
            loadedURL = nil
            phase = .failure
            return
        }

        if loadedURL == url, case .success = phase {
            return
        }

        phase = .empty

        do {
            let data = try await RemoteImageCache.shared.data(for: url)
            try Task.checkCancellation()

            guard requestedURL == url else {
                return
            }

            guard let image = UIImage(data: data) else {
                loadedURL = nil
                phase = .failure
                return
            }

            loadedURL = url
            phase = .success(Image(uiImage: image.preparingForDisplay() ?? image))
        } catch is CancellationError {
            return
        } catch {
            guard requestedURL == url else {
                return
            }

            loadedURL = nil
            phase = .failure
        }
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
