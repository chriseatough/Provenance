//
//  PVGameImporter.swift
//  Provenance
//
//  Created by Christopher Eatough on 23/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation
import Realm

typealias PVGameImporterImportStartedHandler = (NSString) -> ()
typealias PVGameImporterCompletionHandler = (Bool) -> ()
typealias PVGameImporterFinishedImportingGameHandler = (NSString) -> ()
typealias PVGameImporterFinishedGettingArtworkHandler = (NSString) -> ()

class PVGameImporter: NSObject {
    
    var serialImportQueue: dispatch_queue_t
    
    var completionHandler: PVGameImporterCompletionHandler?
    var importStartedHandler: PVGameImporterImportStartedHandler?
    var finishedImportHandler: PVGameImporterFinishedImportingGameHandler?
    var finishedArtworkHandler: PVGameImporterFinishedGettingArtworkHandler?
    
    var romToSystemMap: [String: [String]]
    var systemToPathMap: [String: String]
    
    var encounteredConflicts: Bool
    
    init(completionHandler: PVGameImporterCompletionHandler) {
        self.serialImportQueue = dispatch_queue_create("com.jamsoftonline.provenance.serialImportQueue", DISPATCH_QUEUE_SERIAL)
        self.completionHandler = completionHandler
        self.encounteredConflicts = false
        self.romToSystemMap = [String: [String]]()
        self.systemToPathMap = [String: String]()
        
        super.init()
    }
    
    //    deinit {
    //        self.openVGDB = nil;
    //        self.serialImportQueue = nil;
    //        self.importStartedHandler = nil;
    //        self.completionHandler = nil;
    //        self.finishedImportHandler = nil;
    //        self.finishedArtworkHandler = nil;
    //    }
    
    func startImportForPaths(paths: [String]) {
        dispatch_async(self.serialImportQueue, {
            print("starting import for paths \(paths)")
            
            guard paths != ["0"] else {
                return
            }
            
            let newPaths = self.importFilesAtPaths(paths)
            
            print(newPaths)
            
            self.getRomInfoForFilesAtPaths(newPaths, userChosenSystem: nil)
            
            if let completionHandler = self.completionHandler {
                dispatch_sync(dispatch_get_main_queue(), {
                    completionHandler(self.encounteredConflicts)
                })
            }
        })
    }
    
    func importFilesAtPaths(paths: [String]) -> [String] {
        var newPaths = [String]()
        
        let fm = NSFileManager.defaultManager()
        
        let filePaths: [(path: String, filePath: String)] = paths.map { ($0, (self.romsPath() as NSString).stringByAppendingPathComponent($0)) }
            .filter { fm.fileExistsAtPath($0.1) }
        
        for i in filePaths where isCDROM(i.path) {
            let paths: [String] = self.moveCDROMToAppropriateSubfolder(i.path)
            newPaths.appendContentsOf(paths)
        }

        for i in filePaths where !isCDROM(i.path) {
            if let newPath = self.moveROMToAppropriateSubfolder(i.path) {
                newPaths.append(newPath)
            }
        }
        
        return newPaths
    }
    
    func moveCDROMToAppropriateSubfolder(filePath: String) -> [String] {
        print("\(__FUNCTION__) filePath:\(filePath)")
        
        var newPaths = [String]()
        
        let systemsForExtension = self.systemIDsForRomAtPath(filePath)
        
        guard let systemID = systemsForExtension.first else {
            print("\(__FUNCTION__) cannot get the systemID")
            return []
        }
        
        encounteredConflicts = (systemsForExtension.count > 1)
        
        if systemToPathMap.count == 0 {
            systemToPathMap = updateSystemToPathMap()
        }
        
        let isSubfolderPath = (systemsForExtension.count > 1) ? conflictPath() : systemToPathMap[systemID]
        guard let subfolderPath = isSubfolderPath else {
            print("\(__FUNCTION__) cannot get subfolderPath")
            return []
        }
        
        do {
            let def = NSFileManager.defaultManager()
            try def.createDirectoryAtPath(subfolderPath as String, withIntermediateDirectories: true, attributes: nil)
            
            try def.moveItemAtPath(self.romsPath().stringByAppendingPathComponent(filePath), toPath: subfolderPath.stringByAppendingPathComponent(filePath))
        } catch let error as NSError {
            print("\(__FUNCTION__) error: \(error.localizedDescription)")
            return []
        }
        
        let cueSheetPath: String = subfolderPath.stringByAppendingFormat(filePath)
        if !encounteredConflicts {
            newPaths.append(cueSheetPath)
        }
        
        // moved the .cue, now move .bins .imgs etc
        
        let filePathExtension = (filePath as NSString).pathExtension
        
        let relatedFileName: NSString = filePath.stringByReplacingOccurrencesOfString(filePathExtension, withString: "")
        let contents: [String]
        
        do {
            contents = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(self.romsPath())
        } catch let error as NSError {
            print("Error scanning \(romsPath): \(error.localizedDescription)")
            return newPaths
        }
        
        for fileExtension in contents {
            let fileWithoutExtension: NSString = filePath.stringByReplacingOccurrencesOfString(filePathExtension, withString: "")
            
            guard fileWithoutExtension == relatedFileName else {
                break
            }
            
            do {
                // Before moving the file, make sure the cue sheet's reference uses the same case.
                let cueSheet: NSMutableString = try NSMutableString(contentsOfFile: cueSheetPath as String, encoding: NSUTF8StringEncoding)
                
                let range = cueSheet.rangeOfString(fileExtension, options: .CaseInsensitiveSearch)
                cueSheet.replaceCharactersInRange(range, withString: fileExtension as String)
                
                try cueSheet.writeToFile(cueSheetPath as String, atomically: false, encoding: NSUTF8StringEncoding)
            } catch let error as NSError {
                print("Unable to read cue sheet \(cueSheetPath) because \(error.localizedDescription)")
            }
            
            let fromPath = romsPath().stringByAppendingPathExtension(fileExtension)
            let toPath = subfolderPath + fileExtension
            do {
                
                try NSFileManager.defaultManager().moveItemAtPath(fromPath, toPath: toPath)
            } catch let error as NSError {
                print("\(__FUNCTION__) moveItemAtPath \(fromPath) toPath:\(toPath) because \(error.localizedDescription)")
            }
        }
        
        return newPaths
    }
    
    func moveROMToAppropriateSubfolder(filePath: String) -> String? {
        print("\(__FUNCTION__) filePath:\(filePath)")
        
        var newPath: String?
        
        let systemsForExtension = systemIDsForRomAtPath(filePath)
        
        guard let systemID = systemsForExtension.first else {
            print("\(__FUNCTION__) cannot get systemID from systemsFromExtensions")
            return nil
        }
        
        encounteredConflicts = (systemsForExtension.count > 1)
        
        if systemToPathMap.count == 0 {
            systemToPathMap = updateSystemToPathMap()
        }
        
        let isSubfolderPath = (systemsForExtension.count > 1) ? conflictPath() : systemToPathMap[systemID]
        guard let subfolderPath = isSubfolderPath else {
            print("\(__FUNCTION__) cannot get subfolderPath (systemsForExtensions count is \(systemsForExtension.count))")
            return nil
        }
        
        print("\(__FUNCTION__) subfolderPath is \(subfolderPath)")
        
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(subfolderPath, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            print("Unable to create \(subfolderPath) - \(error.localizedDescription)")
            return nil
        }
        
        do {
            let fromPath = (self.romsPath() as NSString).stringByAppendingPathComponent(filePath)
            let toPath = (subfolderPath as NSString).stringByAppendingPathComponent(filePath)
            
            try NSFileManager.defaultManager().moveItemAtPath(fromPath, toPath: toPath)
        } catch let error as NSError {
            
            do {
                try NSFileManager.defaultManager().removeItemAtPath((self.romsPath() as NSString).stringByAppendingPathComponent(filePath))
            } catch let error as NSError {
                print("Unable to delete \(filePath) (after trying to move and getting 'file exists error' because \(error.localizedDescription)")
            }
            
            
            print("Unable to move file from \(filePath) to \(subfolderPath) - \(error.localizedDescription)")
            return nil
        }
        
        if !self.encounteredConflicts {
            newPath = (subfolderPath as NSString).stringByAppendingPathComponent(filePath)
        }
        
        return newPath
    }
    
    func conflictedFiles() -> [String] {
        let conflictPath = self.conflictPath()
        
        do {
            return try NSFileManager.defaultManager().contentsOfDirectoryAtPath(conflictPath)
        } catch let error as NSError {
            print("Unable to get contents of \(conflictPath) because \(error.localizedDescription)")
            return []
        }
    }
    
    func resolveConflictsWithSolutions(solutions: [String: String]) {
        for (filePath, systemID) in solutions {
            let filePathExtension = (filePath as NSString).pathExtension
            let subfolder = self.systemToPathMap[systemID] ?? ""
            
            if !NSFileManager.defaultManager().fileExistsAtPath(subfolder) {
                do {
                    try NSFileManager.defaultManager().createDirectoryAtPath(subfolder, withIntermediateDirectories: true, attributes: nil)
                } catch let error as NSError {
                    print("\(__FUNCTION__) createDirectoryAtPath failed: \(error.localizedDescription)")
                }
            }
            
            do {
                let fromPath = conflictPath() + filePath
                let toPath = subfolder + filePath
                try NSFileManager.defaultManager().moveItemAtPath(fromPath, toPath:toPath)
            } catch let error as NSError {
                print("Unable to move \(filePath) to \(subfolder) because \(error.localizedDescription)")
            }
            
            
            // moved the .cue, now move .bins .imgs etc
            let cueSheetPath = subfolder.stringByAppendingPathComponent(filePath as String)
            let relatedFileName = filePath.stringByReplacingOccurrencesOfString(filePathExtension, withString: "")
            
            do {
                let contents: [String] = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(self.conflictPath())
                
                for file in contents
                    where file.stringByReplacingOccurrencesOfString(filePathExtension, withString: "") == relatedFileName {
                        // Before moving the file, make sure the cue sheet's reference uses the same case.
                        
                        do {
                            var cueSheet = try String(contentsOfFile: cueSheetPath as String, encoding: NSUTF8StringEncoding)
                            
                            let range = cueSheet.rangeOfString(file, options: .CaseInsensitiveSearch)
                            
                            cueSheet.replaceRange(range!, with: file)
                            
                            try cueSheet.writeToFile(cueSheetPath, atomically: false, encoding: NSUTF8StringEncoding)
                            
                        } catch let error as NSError {
                            print("Unable to read or rewrite cue sheet \(cueSheetPath) because \(error.localizedDescription)")
                        }
                        
                        do {
                            try NSFileManager.defaultManager().moveItemAtPath(self.conflictPath(), toPath: subfolder.stringByAppendingPathComponent(file))
                        } catch let error as NSError {
                            print("Unable to move file from \(filePath) to \(subfolder) - \(error.localizedDescription)")
                        }
                }
                
                
                dispatch_async(self.serialImportQueue, {
                    self.getRomInfoForFilesAtPaths([filePath], userChosenSystem: systemID)
                    
                    if let completion = self.completionHandler {
                        dispatch_async(dispatch_get_main_queue(), {
                            completion(false)
                        })
                    }
                })
                
                
            } catch let error as NSError {
                print("Error resolving conflicts - \(error.localizedDescription)")
            }
            
        }
    }
    
    // MARK: ROM lookup
    
    func getRomInfoForFilesAtPaths(paths: [String], userChosenSystem chosenSystemID: String?) {
        guard paths.count > 0 else {
            print("\(__FUNCTION__) paths does not have any entries")
            return
        }
        
        do {
            
            let realm = RLMRealm.defaultRealm()
            realm.refresh()
            
            for path in paths where !path.hasPrefix(".") {
                let pathExtension = (path as NSString).pathExtension
                let lastPathComponent = (path as NSString).lastPathComponent
                
                let systemID = chosenSystemID ?? PVEmulatorConfiguration.sharedInstance().systemIdentifierForFileExtension(pathExtension)
                
                print("pathExtension: \(pathExtension), lastPathComponent: \(lastPathComponent)")
                
                let cdBasedSystems = PVEmulatorConfiguration.sharedInstance().cdBasedSystemIDs()
                if cdBasedSystems.contains(systemID as String) && pathExtension != "cue" {
                    continue
                }
                
                let partialPath: NSString = systemID.stringByAppendingPathComponent(lastPathComponent)
                let title = lastPathComponent.stringByReplacingOccurrencesOfString(".".stringByAppendingString(pathExtension), withString: "")
                let game: PVGame
                
                let results: RLMResults = PVGame.objectsInRealm(realm, withPredicate: NSPredicate(format: "romPath == %@", (partialPath.length > 0) ? partialPath : ""))
                
                if results.count > 0 {
                    game = results.firstObject() as! PVGame
                    
                    print("firstResult is \(game.title), artwork is \(game.originalArtworkURL)")
                } else {
                    guard systemID != "" else {
                        continue
                    }
                    
                    game = PVGame()
                    game.romPath = partialPath as String
                    game.title = title
                    game.systemIdentifier = systemID as String
                    game.requiresSync = true
                    
                    realm.beginWriteTransaction()
                    realm.addObject(game)
                    try realm.commitWriteTransaction()
                }
                
                if game.requiresSync {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.importStartedHandler!(path)
                    })
                    self.lookupInfoForGame(game)
                }
                
                if (self.finishedImportHandler != nil) {
                    let md5 = game.md5Hash
                    dispatch_async(dispatch_get_main_queue(), {
                        self.finishedImportHandler!(md5)
                    })
                }
                
                self.getArtworkFromURL(game.originalArtworkURL)
                
            }
            
        } catch let error as NSError {
            print("\(__FUNCTION__) error: \(error.localizedDescription)")
        }
    }
    
    func lookupInfoForGame(game: PVGame) {
        do {
            let realm = RLMRealm.defaultRealm()
            realm.refresh()
            
            if game.md5Hash == "" {
                let offset: UInt = (game.systemIdentifier == PVNESSystemIdentifier) ? 16 : 0
                
                let md5Hash: String = NSFileManager.defaultManager().MD5ForFileAtPath(self.documentsPath().stringByAppendingPathComponent(game.romPath), fromOffset: offset)
                
                realm.beginWriteTransaction()
                game.md5Hash = md5Hash
                try realm.commitWriteTransaction()
            }
            
            var results = [[String: String]]()
            
            if game.md5Hash != "" {
                results = (try self.searchDatabaseUsingKey("romHashMD5", value: game.md5Hash.uppercaseString, systemID: game.systemIdentifier)) ?? []
            }
            
            if results.count == 0 {
                var fileName: NSString = (game.romPath as NSString).lastPathComponent
                
                // Remove any extraneous stuff in the rom name such as (U), (J), [T+Eng] etc
                let charSet = NSMutableCharacterSet.punctuationCharacterSet()
                charSet.removeCharactersInString("-+&.'")
                
                let nonCharRange: NSRange = (fileName as NSString).rangeOfCharacterFromSet(charSet)
                let gameTiteLen = (nonCharRange.length > 0) ? Int(nonCharRange.location - 1) : Int(fileName.length)
                
                fileName = fileName.substringToIndex(gameTiteLen)
                
                results = (try searchDatabaseUsingKey("romFileName", value: fileName as String, systemID: game.systemIdentifier)) ?? []
            }
            
            guard let firstResult = results.first else {
                print("Unable to find ROM (\(game.romPath)) in DB")
                realm.beginWriteTransaction()
                game.requiresSync = false
                try realm.commitWriteTransaction()
                
                return
            }
            
            // get the first result that is the USA region, or just the first result
            let chosenResult = results.filter({ $0["region"] == "USA" }).first ?? firstResult
            
            realm.beginWriteTransaction()
            game.requiresSync = false
            
            if let title = chosenResult["gameTitle"] {
                game.title = title
            }
            
            if let url = chosenResult["boxImageURL"] {
                game.originalArtworkURL = url
            }
            
            try realm.commitWriteTransaction()
            
        } catch let error as NSError {
            print("\(__FUNCTION__) error: \(error.localizedDescription)")
        }
    }
    
    func getArtworkFromURL(url: String) {
        print("\(__FUNCTION__) url:\(url)")
        
        guard url != "" else {
            return
        }
        
        guard PVMediaCache.filePathForKey(url) == nil else {
            return
        }
        
        guard let artworkURL = NSURL(string: url) else {
            return
        }
        
        print("Starting Artwork download for \(url)")
        
        let request = NSURLRequest(URL: artworkURL)
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
            guard let data = data, response = response else {
                print("Unable to download from \(url)")
                return
            }
            
            let httpResponse = response as! NSHTTPURLResponse
            print("Status code returned is \(httpResponse.statusCode)")
            
            if let artwork = UIImage(data: data) {
                PVMediaCache.writeImageToDisk(artwork, withKey: url)
            } else {
                print("Unable to convert to an image")
            }
            
            if (self.finishedArtworkHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), {
                    self.finishedArtworkHandler!(url)
                })
            }
        }
        
        task.resume()
    }
    
    func searchDatabaseUsingKey(key: String, value: String, systemID: String) throws -> [[String: String]]? {
        
        guard let url = NSBundle.mainBundle().URLForResource("openvgdb", withExtension: "sqlite") else {
            print("\(__FUNCTION__) - Unable to get a URL for the openvgdb.sqlite file")
            return nil
        }
        
        guard let openVGDB = try? OESQLiteDatabase(URL: url) else {
            print("\(__FUNCTION__) -  Unable to open game database: ")
            return nil
        }
        
        let dbSystemID = PVEmulatorConfiguration.sharedInstance().databaseIDForSystemID(systemID)
        
        let exactQuery = "SELECT DISTINCT releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL' FROM ROMs rom LEFT JOIN RELEASES release USING (romID) WHERE \(key) = '\(value)'"
        
        let likeQuery = "SELECT DISTINCT romFileName, releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL', regionName as 'region', systemShortName FROM ROMs rom LEFT JOIN RELEASES release USING (romID) LEFT JOIN SYSTEMS system USING (systemID) LEFT JOIN REGIONS region on (regionLocalizedID=region.regionID) WHERE \(key) LIKE \"%%\(value)%%\" AND systemID=\"\(dbSystemID)\""
        
        let queryString = (key == "romFileName") ? likeQuery : exactQuery
        
        do {
            var query = [[String: String]]()
            
            query = try openVGDB.executeQuery(queryString) as! [[String : String]]
            
            return query
        } catch let error as NSError {
            print("\(__FUNCTION__) error on executeQuery (\(queryString)): \(error.localizedDescription)")
            
            return []
        }
    }
    
    
    // MARK: Utils
    
    func documentsPath() -> String {
        #if TARGET_OS_TV
            let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
        #else
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        #endif
        
        return paths.first!
    }
    
    func romsPath() -> String {
        return self.documentsPath().stringByAppendingPathComponent("roms")
    }
    
    func conflictPath() -> String {
        return self.documentsPath().stringByAppendingPathComponent("conflict")
    }
    
    func updateSystemToPathMap() -> [String: String] {
        let emuConfig = PVEmulatorConfiguration.sharedInstance()
        
        var map: [String: String] = [:]
        for systemID in emuConfig.availableSystemIdentifiers() {
            let path = self.documentsPath().stringByAppendingPathComponent(systemID)
            map[systemID] = path
        }
        
        return map
    }
    
    func updateRomToSystemMap() -> [String: [String]] {
        let emuConfig = PVEmulatorConfiguration.sharedInstance()
        
        var map: [String: [String]] = [:]
        for systemID in emuConfig.availableSystemIdentifiers() {
            for fileExtension in emuConfig.fileExtensionsForSystemIdentifier(systemID) {
                if let _ = map[fileExtension] {
                } else {
                    map[fileExtension] = [String]()
                }
                
                map[fileExtension]!.append(systemID)
            }
        }
        
        return map
    }
    
    func pathForSystemID(systemID: String) -> String? {
        if systemToPathMap.count == 0 {
            self.systemToPathMap = updateSystemToPathMap()
        }
        
        return self.systemToPathMap[systemID]
    }
    
    func systemIDsForRomAtPath(path: NSString) -> [String] {
        if romToSystemMap.count == 0 {
            self.romToSystemMap = updateRomToSystemMap()
        }
        
        let fileExtension = path.pathExtension.lowercaseString
        
        guard let systemIDs = romToSystemMap[fileExtension] else {
            print("romToSystemMap(\(fileExtension)) is returning nil")
            return []
        }
        
        return systemIDs
    }
    
    func isCDROM(filePath: NSString) -> Bool {
        let emuConfig = PVEmulatorConfiguration.sharedInstance()
        let cdExtensions = emuConfig.supportedCDFileExtensions()
        let ext = filePath.pathExtension
        
        return cdExtensions.contains(ext)
    }
}
