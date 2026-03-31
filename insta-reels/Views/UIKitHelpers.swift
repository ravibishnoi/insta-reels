//
//  UIKitHelpers.swift
//  insta-reels
//
//  Created by Codex on 31/03/26.
//

import UIKit

extension UIStackView {
    func removeAllArrangedSubviews() {
        let views = arrangedSubviews

        for view in views {
            removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
}

extension UIView {
    @discardableResult
    func pinEdges(to otherView: UIView, insets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false

        let constraints = [
            topAnchor.constraint(equalTo: otherView.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: otherView.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: otherView.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: otherView.bottomAnchor, constant: -insets.bottom)
        ]

        NSLayoutConstraint.activate(constraints)
        return constraints
    }
}
