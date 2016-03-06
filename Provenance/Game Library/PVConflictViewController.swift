//
//  PVConflictViewController.swift
//  Provenance
//
//  Created by Christopher Eatough on 23/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation

class PVConflictViewController : UITableViewController {
    #if TARGET_OS_TV
    let searchPathDirectory = NSSearchPathDirectory.CachesDirectory
    #else
    let searchPathDirectory = NSSearchPathDirectory.DocumentDirectory
    #endif
    
    let gameImporter: PVGameImporter
    var conflictedFiles: [NSString]
    
    class func initWithGameImporter(gameImporter: PVGameImporter) -> PVConflictViewController {
        return PVConflictViewController(gameImporter: gameImporter)
    }
    
    init(gameImporter: PVGameImporter) {
        self.gameImporter = gameImporter
        self.conflictedFiles = []
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        #if TARGET_OS_TV
            self.splitViewController?.title = "Solve Conflicts"
            updateConflictedFiles()
        #else
            self.title = "Solve Title"
            
            let doneButton = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "done")
            navigationItem.setRightBarButtonItem(doneButton, animated: false)
            
            if self.conflictedFiles.count > 0 {
                tableView.separatorColor = UIColor.clearColor()
            }
            
        #endif
        
        super.viewDidLoad()
    }
    
    func updateConflictedFiles() {
        var tempConflictedFiles: [NSString] = []
        for file in gameImporter.conflictedFiles() {
            let fileExtension = (file as NSString).pathExtension
            if PVEmulatorConfiguration.sharedInstance().systemIdentifiersForFileExtension(fileExtension.lowercaseString).count > 1 {
                
                tempConflictedFiles.append(file)
            }
        }
        
        conflictedFiles = tempConflictedFiles
    }
    
    
    func done() {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func documentsPath() -> NSString? {
        let paths = NSSearchPathForDirectoriesInDomains(searchPathDirectory, .UserDomainMask, true)
        
        return paths.first ?? nil
    }
    
    
    func conflictsPath() -> NSString? {
        let paths = NSSearchPathForDirectoriesInDomains(searchPathDirectory, .UserDomainMask, true)
        
        guard let path: NSString = paths.first else {
            return nil
        }
        
        return path.stringByAppendingPathComponent("conflicts")
    }
    
    #if TARGET_OS_TV
    func tableView(tableView: UITableView, canFocusRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    
    guard self.conflictedFiles.count > 0 else {
    return false
    }
    
    return true
    
    }
    #endif
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conflictedFiles.count > 0 ? conflictedFiles.count : 3
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        if self.conflictedFiles.count == 0 {
            
            let cell: UITableViewCell = tableView.dequeueReusableCellWithIdentifier("EmptyCell") ?? {
                let c = UITableViewCell(style: .Default, reuseIdentifier: "Cell")
                c.selectionStyle = .None
                return c
                }()
            cell.textLabel?.textAlignment = .Center
            cell.textLabel?.text = (indexPath.row < 2) ? "" : "No Conflicts..."
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell") ?? {
            let c = UITableViewCell(style: .Default, reuseIdentifier: "Cell")
            c.selectionStyle = .Default
            return c
            }()
        
        let file = conflictedFiles[indexPath.row]
        let name = file.lastPathComponent.stringByReplacingOccurrencesOfString(".", withString: "")
        
        cell.textLabel?.text = name
        cell.accessoryType = .DisclosureIndicator
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        guard conflictedFiles.count > 0 else {
            return
        }
        
        let path = conflictedFiles[indexPath.row]
        
        let alertController = UIAlertController(title: "Choose a system", message: nil, preferredStyle: .ActionSheet)
        alertController.popoverPresentationController?.sourceView = self.view
        alertController.popoverPresentationController?.sourceRect = self.tableView.rectForRowAtIndexPath(indexPath)
        
        for systemID in PVEmulatorConfiguration.sharedInstance().availableSystemIdentifiers() {
            let supportedExtensions = PVEmulatorConfiguration.sharedInstance().fileExtensionsForSystemIdentifier(systemID)
            
            guard supportedExtensions.contains(path.pathExtension) else {
                return
            }
            
            let name = PVEmulatorConfiguration.sharedInstance().shortNameForSystemIdentifier(systemID)
            alertController.addAction(UIAlertAction(title: name, style: .Default, handler: {_ in
                self.gameImporter.resolveConflictsWithSolutions(["path": systemID])
                self.tableView.beginUpdates()
                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Top)
                self.updateConflictedFiles()
                self.tableView.endUpdates()
            }))
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
}






























