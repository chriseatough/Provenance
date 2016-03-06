//
//  PVMediaCache.swift
//  Provenance
//
//  Created by Christopher Eatough on 23/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation


class PVMediaCache: NSObject {
    
    class func cachePath() -> NSString {

        var cachePath: NSString = ""
        
        let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
        if let first = paths.first {
            cachePath = first
        }
        
        cachePath = cachePath.stringByAppendingPathComponent(kPVCachePath)
        
        if !NSFileManager.defaultManager().fileExistsAtPath(cachePath as String) {
            
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(cachePath as String, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating cache directory at \(cachePath): \(error)")
            }
        }
        
        return cachePath
    }
    
    
    class func imageForKey(key: NSString) -> UIImage? {
        print("\(__FUNCTION__) (\(key)) in \(self.dynamicType)")
        
        guard key.length > 0 else {
            return nil
        }
        
        let keyHash = key.MD5Hash()
        let cachePath = self.cachePath().stringByAppendingPathComponent(keyHash)
        
        guard NSFileManager.defaultManager().fileExistsAtPath(cachePath) else {
            print("\(__FUNCTION__) No image exists at \(cachePath)")
            return nil
        }
        
        return UIImage(contentsOfFile: cachePath)
    }
    
    
    
    class func filePathForKey(key: NSString) -> NSString? {
        print("\(__FUNCTION__) (\(key)) in \(self.dynamicType)")
        
        guard key.length > 0 else {
            return nil
        }
        
        let keyHash = key.MD5Hash()
        let cachePath = self.cachePath().stringByAppendingPathComponent(keyHash)
        
        let fileExists = NSFileManager.defaultManager().fileExistsAtPath(cachePath)
        return fileExists ? cachePath : nil
    }
    
    class func writeImageToDisk(image: UIImage, withKey key: NSString) -> NSString? {
        guard key.length > 0 else {
            return nil
        }
        
        let imageData = UIImagePNGRepresentation(image)
        
        return self.writeDataToDisk(imageData!, withKey: key)
    }
    
    class func writeDataToDisk(data: NSData, withKey key: NSString) -> NSString {
        print("\(__FUNCTION__) in \(self.dynamicType)")
        
        guard key.length > 0 else {
            return ""
        }
        
        let keyHash = key.MD5Hash()
        let cachePath = self.cachePath().stringByAppendingPathComponent(keyHash)
        
        let success = data.writeToFile(cachePath, atomically: true)
        return success ? cachePath : ""
    }
    
    class func deleteImageForKey(key: NSString) -> Bool {
        print("\(__FUNCTION__) in \(self.dynamicType)")
        
        guard key.length > 0 else {
            return false
        }
        
        let keyHash = key.MD5Hash()
        let cachePath = self.cachePath().stringByAppendingPathComponent(keyHash)
        
        guard !NSFileManager.defaultManager().fileExistsAtPath(cachePath) else {
            return true
        }
        
        do {
            try NSFileManager.defaultManager().removeItemAtPath(cachePath)
            return true
        } catch {
            
            print("Unable to delete cache item: \(cachePath) because: \(error)")
            return false
        }
    }
    
    
    class func emptyCache() {
        print("\(__FUNCTION__) in \(self.dynamicType)")
        
        
        let cachePath = self.cachePath()
        if NSFileManager.defaultManager().fileExistsAtPath(cachePath as String) {
            let _ = try? NSFileManager.defaultManager().removeItemAtPath(cachePath as String)
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(PVMediaCacheWasEmptiedNotification, object: nil)
    }
}
























