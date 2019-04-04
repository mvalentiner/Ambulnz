//
//	UIView+Anchoring.swift
//	PlacesNear
//
//	Created by Michael Valentiner on 3/15/19.
//	Copyright © 2019 Michael Valentiner. All rights reserved.
//

import UIKit

extension UIView {
	func anchorTo(left: NSLayoutXAxisAnchor? = nil, top: NSLayoutYAxisAnchor? = nil, right: NSLayoutXAxisAnchor? = nil, bottom: NSLayoutYAxisAnchor? = nil,
			leftPadding: CGFloat = 0.0, topPadding: CGFloat = 0.0, rightPadding: CGFloat = 0.0, bottomPadding: CGFloat = 0.0) {
		self.translatesAutoresizingMaskIntoConstraints = false
		 if let left = left {
			self.leftAnchor.constraint(equalTo: left, constant: leftPadding).isActive = true
		}
		if let top = top {
			self.topAnchor.constraint(equalTo: top, constant: topPadding).isActive = true
		}
		if let right = right {
			self.rightAnchor.constraint(equalTo: right, constant: -rightPadding).isActive = true
		}
		if let bottom = bottom {
			self.bottomAnchor.constraint(equalTo: bottom, constant: -bottomPadding).isActive = true
		}
	}

	func anchorToXCenterOfParent() {
		guard let parentView = superview else {
			fatalError("\(#function), superview is nil")
		}
		self.translatesAutoresizingMaskIntoConstraints = false
		self.centerXAnchor.constraint(equalTo: parentView.centerXAnchor).isActive = true
	}

	func anchorToYCenterOfParent() {
		guard let parentView = superview else {
			fatalError("\(#function), superview is nil")
		}
		self.translatesAutoresizingMaskIntoConstraints = false
		self.centerYAnchor.constraint(equalTo: parentView.centerYAnchor).isActive = true
	}

	func anchorToXYCenterOfParent() {
		guard let parentView = superview else {
			fatalError("\(#function), superview is nil")
		}
		self.translatesAutoresizingMaskIntoConstraints = false
		self.centerXAnchor.constraint(equalTo: parentView.centerXAnchor).isActive = true
		self.centerYAnchor.constraint(equalTo: parentView.centerYAnchor).isActive = true
	}

	func constrainTo(width: CGFloat) {
		self.translatesAutoresizingMaskIntoConstraints = false
		self.widthAnchor.constraint(equalToConstant: width).isActive = true
	}
	
	func constrainTo(height: CGFloat) {
		self.translatesAutoresizingMaskIntoConstraints = false
		self.heightAnchor.constraint(equalToConstant: height).isActive = true
	}
}
