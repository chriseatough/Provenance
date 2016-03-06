//
//  UIView+FrameAdditions.swift
//  Provenance
//
//  Created by Christopher Eatough on 19/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation

public extension UIView {
    func setOrigin(origin: CGPoint) {
        var frame = self.frame
        frame.origin = origin
        self.frame = frame
    }

    func setOriginX(originX: CGFloat) {
        var frame = self.frame
        frame.origin.x = originX
        self.frame = frame
    }
    
    func setOriginY(originY: CGFloat) {
        var frame = self.frame
        frame.origin.y = originY
        self.frame = frame
    }
    
    func setSize(size: CGSize) {
        var frame = self.frame
        frame.size = size
        self.frame = frame
    }
    
    func setHeight(height: CGFloat) {
        var frame = self.frame
        frame.size.height = height
        self.frame = frame
    }
    
    func setWidth(width: CGFloat) {
        var frame = self.frame
        frame.size.width = width
        self.frame = frame
    }
}