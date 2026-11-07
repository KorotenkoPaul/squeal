//
//  UIView+Extension.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit

var lastPath: [Int: UIBezierPath] = [:]

extension UIView {
    func makeRoundedCorners(topLeftRad: Double, topRightRad: Double, bottomRightRad: Double, bottomLeftRad: Double, index: Int) {

        let maskLayer = CAShapeLayer()
        
        let fromPath = UIBezierPath(roundedRect: self.bounds, cornersRadii: UIBezierPath.CornersRadii(topLeft: 10, topRight: CGFloat(topRightRad), bottomRight: CGFloat(bottomRightRad), bottomLeft: 10))
        let toPath = UIBezierPath(roundedRect: self.bounds, cornersRadii: UIBezierPath.CornersRadii(topLeft: CGFloat(topLeftRad), topRight: CGFloat(topRightRad), bottomRight: CGFloat(bottomRightRad), bottomLeft: CGFloat(bottomLeftRad)))
        
        let animation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.path))
        
        if lastPath.keys.contains(index) {
            animation.fromValue = lastPath[index]!
        } else {
            lastPath[index] = toPath
        }
        
        animation.toValue = toPath.cgPath
        animation.duration = 0.3
        animation.fillMode = kCAFillModeForwards
        animation.isRemovedOnCompletion = false
        
        maskLayer.path = fromPath.cgPath
        maskLayer.add(animation, forKey: nil)
        
        self.layer.mask = maskLayer
    }
}

