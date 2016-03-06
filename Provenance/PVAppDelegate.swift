//
//  PVAppDelegate.swift
//  Provenance
//
//  Created by Christopher Eatough on 17/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation

@UIApplicationMain
class PVAppDelegate : UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var shortcutItemMD5: String?
    
    #if TARGET_OS_TV
    let searchPathDirectory = NSSearchPathDirectory.CachesDirectory
    #else
    let searchPathDirectory = NSSearchPathDirectory.DocumentDirectory
    #endif
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        print("didFinishLaunchingWithOptions in SWIFT!!!")
        
        let app = UIApplication.sharedApplication()
        app.idleTimerDisabled = PVSettingsModel.sharedInstance().disableAutoLock
        
        #if TARGET_OS_TV
            if let _ = NSClassFromString("UIApplicationShortcutItem") {
                let shortcut: UIApplicationShortcutItem = launchOptions[UIApplicationLaunchOptionsShortcutItemKey] as UIApplicationShortcutItem
                if shortcut.type == "kRecentGameShortcut" {
                    shortcutItemMD5 = shortcut.userInfo["PVGameHash"]
                }
            }
        #endif
        
        return true
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
        do {
            #if !TARGET_OS_TV
                guard url.isFileReferenceURL() else {
                    return false
                }
            #else
                let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
                if !url.isFileReferenceURL()
                    && components.path == PVGameControllerKey
                    && components?.queryItems?.first?.name == PVGameMD5Key {
                        shortcutItemMD5 = components?.queryItems?.first?.value
                        return
                }
                
            #endif
            
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            
            guard let documentsDirectory = paths.first, let sourcePath = url.path else {
                return false
            }
            
            let filename = NSString(string: sourcePath).lastPathComponent
            let destinationPath: String = {
                let a = NSString(string: documentsDirectory).stringByAppendingPathComponent("roms")
                let b = NSString(string: a).stringByAppendingPathComponent(filename)
                return b
            }()
            
            let fileManager = NSFileManager.defaultManager()
            try fileManager.moveItemAtPath(sourcePath, toPath: destinationPath)
            
            return true
        } catch {
            print("error has been thrown in application:openURL:sourceApplication:annotation")
            return false
        }
    }
    
    @available(iOS 9.0, *)
    func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
        
        guard let userInfo = shortcutItem.userInfo where shortcutItem.type == "kRecentGameShortcut" else {
            completionHandler(false)
            return
        }
        
        shortcutItemMD5 = String(userInfo["PVGameHash"])
        
        completionHandler(true)
    }
}