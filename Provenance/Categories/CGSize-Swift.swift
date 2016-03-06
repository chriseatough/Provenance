//
//  CGSize-Swift.swift
//  Provenance
//
//  Created by Christopher Eatough on 19/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation

extension CGSize {
    func isEmpty() -> Bool {
        if self.height == 0 && self.width == 0 {
            return true
        }
        return false
    }
}