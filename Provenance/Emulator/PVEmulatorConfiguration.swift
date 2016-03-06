//
//  PVEmulatorConfiguration.swift
//  Provenance
//
//  Created by Christopher Eatough on 16/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import Foundation

class PVEmulatorConfiguration : NSObject {
    
    typealias System = [String:AnyObject]
    typealias ControllerLayout = [String: AnyObject]
    
    class var swiftSharedInstance: PVEmulatorConfiguration {
        struct Static {
            static let instance: PVEmulatorConfiguration = PVEmulatorConfiguration()
        }
        return Static.instance
    }
    
    class func sharedInstance() -> PVEmulatorConfiguration {
        print("Accessing the shared instance in SWIFT!!!")
        return PVEmulatorConfiguration.swiftSharedInstance
    }
    
    var systems = [System]()
    
    override init() {
        super.init()
        
        if let path = NSBundle.mainBundle().pathForResource("systems", ofType: "plist"),
            plist = NSArray(contentsOfFile: path)
            where plist.count > 0 {
                systems = plist.flatMap({ $0 as? System })
        }
        
    }
    
    func emulatorCoreForSystemIdentifier(systemID: String) -> PVEmulatorCore? {
        let core: PVEmulatorCore?
        
        if [PVGenesisSystemIdentifier, PVGameGearSystemIdentifier, PVMasterSystemSystemIdentifier, PVSegaCDSystemIdentifier, PVSG1000SystemIdentifier].contains(systemID) {
                core = PVGenesisEmulatorCore()
        } else if [PVSNESSystemIdentifier].contains(systemID) {
            core = PVSNESEmulatorCore()
        } else if [PVGBASystemIdentifier].contains(systemID) {
            core = PVGBAEmulatorCore()
        } else if [PVGBSystemIdentifier, PVGBCSystemIdentifier].contains(systemID) {
            core = PVGBEmulatorCore()
        } else if [PVNESSystemIdentifier, PVFDSSystemIdentifier].contains(systemID) {
            core = PVNESEmulatorCore()
        } else {
            core = nil
        }
        
        return core
    }
    
    func controllerViewControllerForSystemIdentifier(systemID: String) -> PVControllerViewController? {
        let controller: PVControllerViewController?
        
        let controlLayout = controllerLayoutForSystem(systemID)
        
        if [PVGenesisSystemIdentifier, PVGameGearSystemIdentifier, PVMasterSystemSystemIdentifier, PVSegaCDSystemIdentifier, PVSG1000SystemIdentifier].contains(systemID) {
            controller = PVGenesisControllerViewController(controlLayout: controlLayout, systemIdentifier: systemID)
            
        } else if [PVSNESSystemIdentifier].contains(systemID) {
            controller = PVSNESControllerViewController(controlLayout: controlLayout, systemIdentifier: systemID)
        } else if [PVGBASystemIdentifier].contains(systemID) {
            controller = PVGBAControllerViewController(controlLayout: controlLayout, systemIdentifier: systemID)
        } else if [PVGBSystemIdentifier, PVGBCSystemIdentifier].contains(systemID) {
            controller = PVGBControllerViewController(controlLayout: controlLayout, systemIdentifier: systemID)
        } else if [PVNESSystemIdentifier, PVFDSSystemIdentifier].contains(systemID) {
            controller = PVNESControllerViewController(controlLayout: controlLayout, systemIdentifier: systemID)
        } else {
            controller = nil
        }
        
        return controller
    }
    
    func systemForIdentifier(systemID: String) -> System {
        return systems.filter({
            if let i = $0["PVSystemIdentifier"] as? String
                where i == systemID {
                    return true
            }
            return false
        }).first!
    }
    
    func availableSystemIdentifiers() -> [String] {
        return systems
            .filter({$0["PVSystemIdentifier"] is String})
            .flatMap({ ($0["PVSystemIdentifier"] as! String) })
    }
    
    func nameForSystemIdentifier(systemID: String) -> String {
        return systems
            .filter({
                if let i = $0["PVSystemIdentifier"] as? String
                    where i == systemID {
                        return true
                }
                return false
            })
            .first!["PVSystemName"] as! String
    }
    
    func shortNameForSystemIdentifier(systemID: String) -> String {
        return systems
            .filter({
                if let i = $0["PVSystemIdentifier"] as? String
                    where i == systemID {
                        return true
                }
                return false
            })
            .first!["PVShortSystemName"] as! String
    }
    
    func supportedFileExtensions() -> [String] {
        return systems
            .flatMap({ ($0["PVSupportedExtensions"] as! [String]) })
    }
    
    func supportedCDFileExtensions() -> [String] {
        return systems
            .filter({
                if let i = $0["PVUsesCDs"] as? Bool
                    where i {
                        return true
                }
                return false
            })
            .flatMap({ ($0["PVSupportedExtensions"] as! [String]) })
    }
    
    func cdBasedSystemIDs() -> [String] {
        return systems
            .filter({
                if let i = $0["PVUsesCDs"] as? Bool
                    where i {
                        return true
                }
                return false
            })
            .flatMap({ ($0["PVSystemIdentifier"] as? String) })
    }
    
    func fileExtensionsForSystemIdentifier(systemID: String) -> [String] {
        return systems
            .filter({
                if let i = $0["PVSystemIdentifier"] as? String
                    where i == systemID {
                        return true
                }
                return false
            })
            .flatMap({ ($0["PVSupportedExtensions"] as! [String]) })
    }
    
    func systemIdentifierForFileExtension(fileExtension: String) -> String {
        return systems
            .filter({
                if let i = $0["PVSupportedExtensions"] as? [String]
                    where i.contains(fileExtension) {
                        return true
                }
                return false
            })
            .first!["PVSystemIdentifier"] as! String
    }
    
    func systemIdentifiersForFileExtension(fileExtension: String) -> [String] {
        return systems
            .filter({
                if let i = $0["PVSupportedExtensions"] as? [String]
                    where i.contains(fileExtension) {
                        return true
                }
                return false
            })
            .flatMap({ ($0["PVSystemIdentifier"] as? String) })
    }
    
    func controllerLayoutForSystem(systemID: String) -> [ControllerLayout] {
        return systems
            .filter({
                if let i = $0["PVSystemIdentifier"] as? String
                    where i == systemID {
                        return true
                }
                return false
            })
            .first!["PVControlLayout"] as! [ControllerLayout]
    }
    
    func databaseIDForSystemID(systemID: String) -> String {
        return systems
            .filter({
                if let i = $0["PVSystemIdentifier"] as? String
                    where i == systemID {
                        return true
                }
                return false
            })
            .first!["PVDatabaseID"] as! String
    }
}
