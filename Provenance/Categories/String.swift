//
//  String.swift
//  Provenance
//
//  Created by Christopher Eatough on 27/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation

extension String {
    func stringByAppendingPathComponent(pathComponent: String) -> String {
        return (self as NSString).stringByAppendingPathComponent(pathComponent)
    }
    
    func stringByAppendingPathExtension(str: String) -> String {
        return (self as NSString).stringByAppendingPathExtension(str)!
    }
}






