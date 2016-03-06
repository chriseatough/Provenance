//
//  DeviceTarget.swift
//  Provenance
//
//  Created by Christopher Eatough on 20/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation

enum Device {
    case iOS
    case tvOS
}

struct Target {
    static func TargetDevice() -> Device {
        #if TARGET_OS_TV
            return .tvOS
        #else
            return .iOS
        #endif
    }
}