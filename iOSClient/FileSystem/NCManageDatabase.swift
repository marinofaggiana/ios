//
//  NCManageDatabase.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import RealmSwift

class NCManageDatabase: NSObject {
        
    static let sharedInstance: NCManageDatabase = {
        let instance = NCManageDatabase()
        return instance
    }()
    
    override init() {
        
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: k_capabilitiesGroups)
        var config = Realm.Configuration()
        
        config.fileURL = dirGroup?.appendingPathComponent("\(appDatabaseNextcloud)/\(k_databaseDefault)")
        
        Realm.Configuration.defaultConfiguration = config
    }
    
    
    func addActivityServer(_ listOfActivity: [OCActivity], account: String) {
    
        let realm = try! Realm()
        
        try! realm.write {
            
            for activity in listOfActivity {
                
                let dbActivity = DBActivity()
                
                dbActivity.account = account
                dbActivity.action = "Activity"
                dbActivity.date = activity.date
                dbActivity.idActivity = Double(activity.idActivity)
                dbActivity.link = activity.link
                dbActivity.note = activity.subject
                dbActivity.type = k_activityTypeInfo
                
                if (k_activityVerboseDefault == 1) {
                    dbActivity.verbose = true
                }
                
                realm.add(dbActivity)
            }
        }
    }
    /*
    - (void)addActivityServer:(NSArray *)listOfActivity account:(NSString *)account
    {
    RLMRealm *realm = [RLMRealm defaultRealm];
    
    [realm beginWriteTransaction];
    
    for (OCActivity *activity in listOfActivity) {
    
    DBActivity *dbActivity = [DBActivity new];
    
    dbActivity.account = account;
    dbActivity.action = @"Activity";
    dbActivity.date = activity.date;
    dbActivity.file = activity.file;
    dbActivity.idActivity = activity.idActivity;
    dbActivity.link = activity.link;
    dbActivity.note = activity.subject;
    dbActivity.type = k_activityTypeInfo;
    dbActivity.verbose = k_activityVerboseDefault;
    
    [realm addObject:dbActivity];
    }
    
    [realm commitWriteTransaction];
    }
    */

}
