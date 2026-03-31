//
//  SceneDelegate.swift
//  insta-reels
//
//  Created by Codex on 31/03/26.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootViewController(
            viewModel: InstagramProfileViewModel(
                username: "fitwithsana",
                gridSource: .allPosts
            )
        )
        window.makeKeyAndVisible()
        self.window = window
    }
}
