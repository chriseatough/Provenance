//
//  PVEmulatorViewController.swift
//  Provenance
//
//  Created by Christopher Eatough on 20/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation

#if TARGET_OS_TV
    typealias PVEmulatorViewControllerParent = GCEventViewController
#else
    typealias PVEmulatorViewControllerParent = UIViewController
#endif


class PVEmulatorViewController : PVEmulatorViewControllerParent {
    let emulatorCore: PVEmulatorCore
    let game: PVGame
    
    var batterySavesPath: NSString = ""
    var saveStatePath: NSString = ""
    var BIOSPath: NSString = ""
    
    var glViewController: PVGLViewController
    var gameAudio: OEGameAudio
    var controllerViewController: PVControllerViewController
    
    var menuButton: UIButton
    
    var menuActionSheet: UIAlertController?
    var isShowingMenu: Bool
    
    var secondaryScreen: UIScreen?
    var secondaryWindow: UIWindow?
    
    init(game: PVGame) {
        self.game = game
        self.emulatorCore = PVEmulatorConfiguration.sharedInstance().emulatorCoreForSystemIdentifier(self.game.systemIdentifier)!
        self.glViewController = PVGLViewController(emulatorCore: emulatorCore)
        self.gameAudio = OEGameAudio(core: emulatorCore)
        
        controllerViewController = PVEmulatorConfiguration.sharedInstance().controllerViewControllerForSystemIdentifier(game.systemIdentifier)!
        
        menuButton = UIButton(type: .Custom)
        self.isShowingMenu = false
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        emulatorCore.stopEmulation()
        
        gameAudio.stopAudio()
        
        controllerViewController.willMoveToParentViewController(nil)
        controllerViewController.view.removeFromSuperview()
        controllerViewController.removeFromParentViewController()
        
        glViewController.willMoveToParentViewController(nil)
        glViewController.view.removeFromSuperview()
        glViewController.removeFromParentViewController()
        
        for controller in GCController.controllers() {
            controller.controllerPausedHandler = nil
        }
    }
    
    class func initWithGame(game: PVGame) -> PVEmulatorViewController {
        return PVEmulatorViewController(game: game)
    }
    
    override func viewDidLoad() {
        defer { super.viewDidLoad() }
        
        self.title = game.title
        self.view.backgroundColor = UIColor.blackColor()
        
        let defaults = NSNotificationCenter.defaultCenter()
        defaults.addObserver(self, selector: "appWillEnterForeground", name: UIApplicationWillEnterForegroundNotification, object: nil)
        defaults.addObserver(self, selector: "appDidEnterBackground", name: UIApplicationDidEnterBackgroundNotification, object: nil)
        defaults.addObserver(self, selector: "appWillResignActive", name: UIApplicationWillResignActiveNotification, object: nil)
        defaults.addObserver(self, selector: "appDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
        defaults.addObserver(self, selector: "controllerDidConnect", name: GCControllerDidConnectNotification, object: nil)
        defaults.addObserver(self, selector: "controllerDidDisconnect", name: GCControllerDidDisconnectNotification, object: nil)
        defaults.addObserver(self, selector: "screenDidConnect", name: UIScreenDidConnectNotification, object: nil)
        defaults.addObserver(self, selector: "screenDidDisconnect", name: UIScreenDidDisconnectNotification, object: nil)
        
        //        self.emulatorCore = PVEmulatorConfiguration.sharedInstance().emulatorCoreForSystemIdentifier(self.game.systemIdentifier)!
        emulatorCore.saveStatesPath = saveStatePath as String
        emulatorCore.batterySavesPath = batterySavesPath as String
        emulatorCore.BIOSPath = BIOSPath as String
        emulatorCore.controller1 = PVControllerManager.sharedManager().player1
        emulatorCore.controller2 = PVControllerManager.sharedManager().player2
        
        controllerViewController = PVEmulatorConfiguration.sharedInstance().controllerViewControllerForSystemIdentifier(game.systemIdentifier)!
        controllerViewController.emulatorCore = emulatorCore
        
        
        glViewController = PVGLViewController.initWithEmulatorCore(emulatorCore)
        
        if UIScreen.screens().count > 1 {
            secondaryScreen = UIScreen.screens()[1]
            
            secondaryWindow = UIWindow(frame: secondaryScreen!.bounds)
            secondaryWindow!.screen = secondaryScreen!
            secondaryWindow!.rootViewController = glViewController
            
            glViewController.view.frame = secondaryWindow!.bounds
            
            secondaryWindow!.addSubview(glViewController.view)
            secondaryWindow!.hidden = false
        } else {
            addChildViewController(glViewController)
            view.addSubview(glViewController.view)
            glViewController.didMoveToParentViewController(self)
        }
        
        addChildViewController(controllerViewController)
        self.view.addSubview(controllerViewController.view)
        controllerViewController.didMoveToParentViewController(self)
        
        let alpha = CGFloat(PVSettingsModel.sharedInstance().controllerOpacity)
        menuButton.frame = CGRectMake((self.view.bounds.size.width - 62) / 2, 10, 62, 22)
        menuButton.autoresizingMask = [.FlexibleLeftMargin, .FlexibleRightMargin, .FlexibleBottomMargin]
        menuButton.setBackgroundImage(UIImage(named: "button-thin"), forState: .Normal)
        menuButton.setBackgroundImage(UIImage(named: "button-thin-pressed"), forState: .Highlighted)
        menuButton.setTitle("Menu", forState: .Normal)
        menuButton.titleLabel?.shadowOffset = CGSize(width: 0, height: 1)
        menuButton.setTitleShadowColor(UIColor.darkGrayColor(), forState: .Normal)
        menuButton.titleLabel?.font = UIFont.boldSystemFontOfSize(15)
        menuButton.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        menuButton.alpha = alpha
        menuButton.addTarget(self, action: "showMenu", forControlEvents: .TouchUpInside)
        menuButton.hidden = { return (GCController.controllers().count > 0) }()
        self.view.addSubview(menuButton)
        
        if !emulatorCore.loadFileAtPath(documentsPath().stringByAppendingPathComponent(game.romPath)) {
            
            // wrap this stuff in a dispatch after block!!!!! TODO!!!!!
            if Target.TargetDevice() == Device.iOS {
                UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: .Fade)
            }
            
            let handler: (UIAlertAction) -> () = { action in
                self.dismissViewControllerAnimated(true, completion: nil)
            }
            
            let alertController = UIAlertController(title: "Unable to load ROM", message: "Maybe it's corrupt? Try deleting and reimporting it.", preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: handler))
            self.presentViewController(alertController, animated: true, completion: nil)
            
            return
        }
        
        emulatorCore.startEmulation()
        
        gameAudio = OEGameAudio(core: emulatorCore)
        gameAudio.volume = PVSettingsModel.sharedInstance().volume
        gameAudio.outputDeviceID = 0
        gameAudio.startAudio()
        
        let autoSavePath = saveStatePath.stringByAppendingPathComponent("auto.svs")
        if NSFileManager.defaultManager().fileExistsAtPath(autoSavePath) {
            let shouldAskToLoadSaveState = PVSettingsModel.sharedInstance().askToAutoLoad
            let shouldAutoLoadSaveState = PVSettingsModel.sharedInstance().autoLoadAutoSaves
            
            if shouldAutoLoadSaveState {
                emulatorCore.loadStateFromFileAtPath(autoSavePath) // weak self??
            } else if shouldAskToLoadSaveState {
                emulatorCore.setPauseEmulation(true)
                
                let alert = UIAlertController(title: "Autosave file detected", message: "Would you like to load it?", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "Yes", style: .Default, handler: { action in
                    self.emulatorCore.loadStateFromFileAtPath(autoSavePath)
                    self.emulatorCore.setPauseEmulation(false)
                }))
                alert.addAction(UIAlertAction(title: "Yes, and stop asking", style: .Default, handler: { action in
                    self.emulatorCore.loadStateFromFileAtPath(autoSavePath)
                    PVSettingsModel.sharedInstance().autoSave = true
                    PVSettingsModel.sharedInstance().askToAutoLoad = false
                }))
                alert.addAction(UIAlertAction(title: "No", style: .Default, handler: { action in
                    self.emulatorCore.setPauseEmulation(false)
                }))
                alert.addAction(UIAlertAction(title: "No, and stop asking", style: .Default, handler: { action in
                    self.emulatorCore.setPauseEmulation(false)
                    PVSettingsModel.sharedInstance().askToAutoLoad = false
                    PVSettingsModel.sharedInstance().autoLoadAutoSaves = false
                }))
                
                self.presentViewController(alert, animated: true, completion: nil)
            }
        }
        
        for controller in GCController.controllers() {
            controller.controllerPausedHandler = { controller in
                self.controllerPauseButtonPressed()
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        if Target.TargetDevice() == Device.iOS {
            let app = UIApplication.sharedApplication()
            app.setStatusBarHidden(true, withAnimation: .Fade)
        }
        
        super.viewWillAppear(animated)
    }
    
    func documentsPath() -> NSString {
        let directory: NSSearchPathDirectory = {
            if Target.TargetDevice() == Device.iOS {
                return .DocumentDirectory
            } else {
                return .CachesDirectory
            }
        }()
        
        let paths = NSSearchPathForDirectoriesInDomains(directory, .UserDomainMask, true)
        return paths.first ?? ""
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func appWillEnterForeground(note: NSNotification) {
        guard !isShowingMenu else {
            return
        }
        
        emulatorCore.setPauseEmulation(false)
        gameAudio.startAudio()
    }
    
    func appDidEnterBackground(note: NSNotification) {
        emulatorCore.autoSaveState()
        emulatorCore.setPauseEmulation(true)
        gameAudio.pauseAudio()
    }
    
    func appWillResignActive(note: NSNotification) {
        emulatorCore.autoSaveState()
        emulatorCore.setPauseEmulation(true)
        gameAudio.pauseAudio()
    }
    
    func appDidBecomeActive(note: NSNotification) {
        guard !isShowingMenu else {
            return
        }
        
        emulatorCore.shouldResyncTime = true
        emulatorCore.setPauseEmulation(false)
        gameAudio.startAudio()
    }
    
    func showMenu() {
        #if TARGET_OS_TV
            controllerUserInteractionEnabled = true
        #endif
        
        emulatorCore.setPauseEmulation(true)
        isShowingMenu = true
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        if traitCollection.userInterfaceIdiom == .Pad {
            actionSheet.popoverPresentationController?.sourceView = self.menuButton
            actionSheet.popoverPresentationController?.sourceRect = self.menuButton.bounds
        }
        
        menuActionSheet = actionSheet
        
        if let _ = PVControllerManager.sharedManager().iCadeController {
            actionSheet.addAction(UIAlertAction(title: "Disconnect iCade", style: .Default, handler: { _ in
                NSNotificationCenter.defaultCenter().postNotificationName(GCControllerDidDisconnectNotification, object: PVControllerManager.sharedManager().iCadeController)
                self.emulatorCore.setPauseEmulation(false)
                self.isShowingMenu = false
                
                #if TARGET_OS_TV
                    controllerUserInteractionEnabled = true
                #endif
                
            }))
        }
        
        
        if Target.TargetDevice() == Device.tvOS {
            let controllerManager = PVControllerManager.sharedManager()
            if controllerManager.player1.extendedGamepad == nil {
                // left trigger bound to start
                // right trigger bound to select
                actionSheet.addAction(UIAlertAction(title: "P1 start", style: .Default, handler: { _ in
                    self.emulatorCore.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController.pressStartForPlayer(0)
                    
                    delay(0.2) {
                        self.controllerViewController.releaseStartForPlayer(0)
                    }
                    
                    #if TARGET_OS_TV
                        controllerUserInteractionEnabled = true
                    #endif
                }))
                
                actionSheet.addAction(UIAlertAction(title: "P1 Select", style: .Default, handler: { _ in
                    self.emulatorCore.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController.pressSelectForPlayer(0)
                    
                    delay(0.2) {
                        self.controllerViewController.releaseSelectForPlayer(0)
                    }
                    
                    #if TARGET_OS_TV
                        controllerUserInteractionEnabled = true
                    #endif
                }))
            }
            
            if controllerManager.player2.extendedGamepad == nil {
                // left trigger bound to start
                // right trigger bound to select
                actionSheet.addAction(UIAlertAction(title: "P2 start", style: .Default, handler: { _ in
                    self.emulatorCore.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController.pressStartForPlayer(1)
                    
                    delay(0.2) {
                        self.controllerViewController.releaseStartForPlayer(1)
                    }
                    
                    #if TARGET_OS_TV
                        controllerUserInteractionEnabled = true
                    #endif
                }))
                
                actionSheet.addAction(UIAlertAction(title: "P2 Select", style: .Default, handler: { _ in
                    self.emulatorCore.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController.pressSelectForPlayer(1)
                    
                    delay(0.2) {
                        self.controllerViewController.releaseSelectForPlayer(1)
                    }
                    
                    #if TARGET_OS_TV
                        controllerUserInteractionEnabled = true
                    #endif
                }))
            }
            
        }
        
        
        if emulatorCore.supportsDiskSwapping() {
            actionSheet.addAction(UIAlertAction(title: "Swap Disk", style: .Default, handler: { _ in
                self.emulatorCore.swapDisk()
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: "Save State", style: .Default, handler: {_ in
            self.performSelector("showSaveStateMenu", withObject: nil, afterDelay: 0.1)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Load State", style: .Default, handler: {_ in
            self.performSelector("showLoadStateMenu", withObject: nil, afterDelay: 0.1)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Toggle Fast Forward", style: .Default, handler: {_ in
            self.emulatorCore.fastForward = !self.emulatorCore.fastForward
            self.emulatorCore.setPauseEmulation(false)
            self.isShowingMenu = false
            #if TARGET_OS_TV
                controllerUserInteractionEnabled = true
            #endif
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Reset", style: .Default, handler: {_ in
            if PVSettingsModel.sharedInstance().autoSave {
                self.emulatorCore.autoSaveState()
            }
            
            self.emulatorCore.setPauseEmulation(false)
            self.emulatorCore.resetEmulation()
            self.isShowingMenu = false
            #if TARGET_OS_TV
                controllerUserInteractionEnabled = true
            #endif
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Return to Game Library", style: .Default, handler: {_ in
            
            self.quit()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Resume", style: .Default, handler: {_ in
            
            self.emulatorCore.setPauseEmulation(false)
            self.isShowingMenu = false
            #if TARGET_OS_TV
                controllerUserInteractionEnabled = true
            #endif
            
        }))
        
        self.presentViewController(actionSheet, animated: true, completion: {
            PVControllerManager.sharedManager().iCadeController?.refreshListener()
        })
    }
    
    func hideMenu() {
        #if TARGET_OS_TV
            controllerUserInteractionEnabled = true
        #endif
        
        guard let _ = self.menuActionSheet else {
            return
        }
        
        self.dismissViewControllerAnimated(true, completion: nil)
        emulatorCore.setPauseEmulation(false)
        self.isShowingMenu = false
    }
    
    func showSaveStateMenu() {
        let infoPath = saveStatePath.stringByAppendingPathComponent("info.plist")
        
        let info: NSMutableArray = NSMutableArray(contentsOfFile: infoPath) ?? {
            let arr = NSMutableArray(array: ["Slot 1 (empty)",
                "Slot 2 (empty)",
                "Slot 3 (empty)",
                "Slot 4 (empty)",
                "Slot 5 (empty)"])
            return arr
            }()
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        if traitCollection.userInterfaceIdiom == .Pad {
            actionSheet.popoverPresentationController?.sourceView = self.menuButton
            actionSheet.popoverPresentationController?.sourceRect = self.menuButton.bounds
        }
        
        self.menuActionSheet = actionSheet
        
        for i in 0..<5 {
            actionSheet.addAction(UIAlertAction(title: (info[i] as! String), style: .Default, handler: {_ in
                let now = NSDate()
                let formatter = NSDateFormatter()
                formatter.dateStyle = .ShortStyle
                formatter.timeStyle = .ShortStyle
                
                info[i] = "Slot \(i + 1) (\(formatter.stringFromDate(now)))"
                info.writeToFile(infoPath, atomically: true)
                
                let savePath = self.saveStatePath.stringByAppendingPathComponent("\(i).svs")
                
                self.emulatorCore.saveStateToFileAtPath(savePath)
                self.emulatorCore.setPauseEmulation(false)
                self.isShowingMenu = false
                #if TARGET_OS_TV
                    controllerUserInteractionEnabled = true
                #endif
            }))
        }
        
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: {_ in
            self.emulatorCore.setPauseEmulation(false)
            self.isShowingMenu = false
            #if TARGET_OS_TV
                controllerUserInteractionEnabled = true
            #endif
        }))
        
        
        self.presentViewController(actionSheet, animated: true, completion: {
            PVControllerManager.sharedManager().iCadeController?.refreshListener()
        })
    }
    
    
    
    
    func showLoadStateMenu() {
        let infoPath = saveStatePath.stringByAppendingPathComponent("info.plist")
        let autoSavePath = saveStatePath.stringByAppendingPathComponent("auto.svs")
        
        let info: NSMutableArray = NSMutableArray(contentsOfFile: infoPath) ?? {
            let arr = NSMutableArray(array: ["Slot 1 (empty)",
                "Slot 2 (empty)",
                "Slot 3 (empty)",
                "Slot 4 (empty)",
                "Slot 5 (empty)"])
            return arr
            }()
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        if traitCollection.userInterfaceIdiom == .Pad {
            actionSheet.popoverPresentationController?.sourceView = self.menuButton
            actionSheet.popoverPresentationController?.sourceRect = self.menuButton.bounds
        }
        
        self.menuActionSheet = actionSheet
        
        if NSFileManager.defaultManager().fileExistsAtPath(autoSavePath) {
            actionSheet.addAction(UIAlertAction(title: "Last AutoSave", style: .Default, handler: {_ in
                self.emulatorCore.setPauseEmulation(false)
                self.isShowingMenu = false
                #if TARGET_OS_TV
                    controllerUserInteractionEnabled = true
                #endif
                
                self.emulatorCore.loadStateFromFileAtPath(autoSavePath)
            }))
        }
        
        for i in 0..<5 {
            actionSheet.addAction(UIAlertAction(title: (info[i] as! String), style: .Default, handler: {_ in
                self.emulatorCore.setPauseEmulation(false)
                self.isShowingMenu = false
                #if TARGET_OS_TV
                    controllerUserInteractionEnabled = true
                #endif
                
                let savePath = self.saveStatePath.stringByAppendingPathComponent("\(i).svs")
                if NSFileManager.defaultManager().fileExistsAtPath(savePath) {
                    self.emulatorCore.loadStateFromFileAtPath(savePath)
                }
                
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: {_ in
            self.emulatorCore.setPauseEmulation(false)
            self.isShowingMenu = false
            #if TARGET_OS_TV
                controllerUserInteractionEnabled = true
            #endif
            
            self.emulatorCore.loadStateFromFileAtPath(autoSavePath)
        }))
        
        self.presentViewController(actionSheet, animated: true, completion: {
            PVControllerManager.sharedManager().iCadeController?.refreshListener()
        })
    }
    
    
    func quit() {
        self.quit() {}
    }
    
    func quit(completion: () -> ()) {
        if PVSettingsModel.sharedInstance().autoSave {
            emulatorCore.autoSaveState()
        }
        
        self.gameAudio.stopAudio()
        self.emulatorCore.stopEmulation()
        if Target.TargetDevice() == Device.iOS {
            UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: .Fade)
        }
        
        self.dismissViewControllerAnimated(true, completion: completion)
        
        #if TARGET_OS_TV
            controllerUserInteractionEnabled = true
        #endif
        
    }
    
    
    // MARK: Controllers
    
    func controllerPauseButtonPressed() {
        if isShowingMenu {
            hideMenu()
        } else {
            showMenu()
        }
    }
    
    func controllerDidConnect(note: NSNotification) {
        self.menuButton.hidden = true
    }
    
    func controllerDidDisconnect(note: NSNotification) {
        self.menuButton.hidden = false
    }
    
    
    
    // MARK: UIScreenNotifications
    
    func screenDidConnect(note: NSNotification) {
        print("Screen did connect: \(note.object)")
        
        if secondaryScreen == nil {
            secondaryScreen = UIScreen.screens().first
            secondaryWindow = UIWindow(frame: secondaryScreen!.bounds)
            secondaryWindow!.screen = secondaryScreen!
            
            glViewController.view.removeFromSuperview()
            glViewController.removeFromParentViewController()
            
            secondaryWindow!.rootViewController = glViewController
            glViewController.view.frame = secondaryWindow!.bounds
            secondaryWindow!.addSubview(glViewController.view)
            secondaryWindow!.hidden = false
            glViewController.view.setNeedsLayout()
            
        }
    }
    
    
    func screenDidDisconnect(note: NSNotification) {
        print("Screen did connect: \(note.object)")
        
        if let _ = secondaryScreen {
            let _ = note.object as! UIScreen
            
            glViewController.view.removeFromSuperview()
            glViewController.removeFromParentViewController()
            
            addChildViewController(glViewController)
            view.insertSubview(glViewController.view, belowSubview: controllerViewController.view)
            glViewController.view.setNeedsLayout()
            
        }
        secondaryWindow = nil
        secondaryScreen = nil
    }
    
    
    
}




























