//
//  UIImage+Scaling.swift
//  Provenance
//
//  Created by Christopher Eatough on 17/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
    func scaledImageWithMaxResolution(maxResolution: NSInteger) -> UIImage {
        let kMaxResolution = CGFloat(maxResolution)
        let imgRef = self.CGImage
        
        let width = CGImageGetWidth(imgRef)
        let height = CGImageGetHeight(imgRef)
        
        var transform = CGAffineTransformIdentity
        var bounds = CGRect(x: 0, y: 0, width: width, height: height)
        
        if width > maxResolution || height > maxResolution {
            let ratio = CGFloat(width/height)
            if ratio > 1 {
                bounds.size.width = kMaxResolution
                bounds.size.height = bounds.size.width/ratio
            } else {
                bounds.size.width = bounds.size.height/ratio
                bounds.size.height = kMaxResolution
            }
        }
        
        let scaleRatio = bounds.size.width / CGFloat(width)
        let imageSize = CGSize(width: width, height: height)
        var boundHeight = CGFloat(0)
        let orientation = self.imageOrientation
        
        if case .Up = orientation {
            transform = CGAffineTransformIdentity
        } else if case .UpMirrored = orientation {
            transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0)
            transform = CGAffineTransformScale(transform, -1.0, 1.0)
        } else if case .Down = orientation {
            transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
            transform = CGAffineTransformRotate(transform, CGFloat(M_PI));
        } else if case .DownMirrored = orientation {
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
            transform = CGAffineTransformScale(transform, 1.0, -1.0);
        } else if case .LeftMirrored = orientation {
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * CGFloat(M_PI) / 2.0);
        } else if case .Left = orientation {
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
            transform = CGAffineTransformRotate(transform, 3.0 * CGFloat(M_PI) / 2.0);
        } else if case .RightMirrored = orientation {
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, CGFloat(M_PI) / 2.0);
        } else if case .Right = orientation {
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
            transform = CGAffineTransformRotate(transform, CGFloat(M_PI) / 2.0);
        }
        
        UIGraphicsBeginImageContext(bounds.size)
        
        let context = UIGraphicsGetCurrentContext()
        
        if case .Right = orientation {
            CGContextScaleCTM(context, -scaleRatio, scaleRatio);
            CGContextTranslateCTM(context, -CGFloat(height), 0);
        } else {
            CGContextScaleCTM(context, scaleRatio, -scaleRatio);
            CGContextTranslateCTM(context, 0, -CGFloat(height));
        }

        CGContextConcatCTM(context, transform);
        
        CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, CGFloat(width), CGFloat(height)), imgRef);
        
        let imageCopy = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return imageCopy
    }
}