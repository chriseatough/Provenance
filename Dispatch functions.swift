//
//  Dispatch functions.swift
//  Provenance
//
//  Created by Christopher Eatough on 23/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

// http://stackoverflow.com/questions/24034544/dispatch-after-gcd-in-swift/24318861#24318861

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}