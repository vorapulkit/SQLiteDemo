//
//  DBManager.swift
//  FormDemo
//
//  Created by Pulkit's Mac on 24/07/17.
//  Copyright © 2017 Pulkit's Mac. All rights reserved.
//

import UIKit

class DBManager: NSObject {

    var db: OpaquePointer? = nil

    class var Shared: DBManager {
        struct Static {
            static var onceToken: Int = 0
            static var instance = DBManager()
        }
        return Static.instance
    }
    
    //MARK:
    //MARK: DB NAME
    fileprivate func getDataBaseName()->String
    {
        return "test.sqlite"
    }
    
    //MARK:
    //MARK: Persistant Connection
    func connectDB(){
        
        
        let fileManager = FileManager.default
        
        let documentsUrl = fileManager.urls(for: .documentDirectory,
                                            in: .userDomainMask)
        
        guard documentsUrl.count != 0 else {
            return // Could not find documents URL
        }
        
        let finalDatabaseURL = documentsUrl.first!.appendingPathComponent(getDataBaseName())
        
        if !( (try? finalDatabaseURL.checkResourceIsReachable()) ?? false) {
            
            let documentsURL = Bundle.main.resourceURL?.appendingPathComponent(getDataBaseName())
            
            do {
                try fileManager.copyItem(atPath: (documentsURL?.path)!, toPath: finalDatabaseURL.path)
                
                if sqlite3_open(finalDatabaseURL.path, &db) != SQLITE_OK {
                    print("error opening database")
                }
            } catch let error as NSError {
                print("Couldn't copy file to final location! Error:\(error.description)")
            }
            
        } else {
            if sqlite3_open(finalDatabaseURL.path, &db) != SQLITE_OK {
                print("error opening database")
            }
        }
    }
    func closeDB(){
        
        if sqlite3_close(db) != SQLITE_OK {
            print("error closing database")
            return
        }
        db = nil
    }
    
    //MARK:
    //MARK: Transaction
    fileprivate func begin(){
        sqlite3_exec(db, "BEGIN", nil, nil, nil)
    }
    fileprivate func rollback(){
        sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
    }
    fileprivate func commit(){
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }
    
    //MARK:
    //MARK: Operation
    

    func executeQuery(_ str1: String, withError error1: Error?) -> Int {
        var error = error1
        let str = str1.replacingOccurrences(of: "(null)", with: "")
        let exeuteSql: String = str
        var lastId = Int64()
        defer {
        }
        do {
            let sqlStatment = exeuteSql.cString(using: String.Encoding.utf8)
            var sqlComplile: OpaquePointer?
            sqlite3_prepare_v2(db, sqlStatment, -1, &sqlComplile, nil)
            let execute = sqlite3_step(sqlComplile)
            if execute == SQLITE_DONE {
                ////NSLog(@"sql exuted");
                lastId = sqlite3_last_insert_rowid(db)
            }
            else {
                print("Error in run statement :- \(sqlite3_errmsg(db))")
                error = sqlite3_errmsg(db) as? Error

            }
            sqlite3_finalize(sqlComplile)
        } catch let e {
            print("exception error in run query is :- \(e.localizedDescription)")
            error = sqlite3_errmsg(db) as? Error

        }
        let myNumber = Double((lastId))
        let idLast = CInt(myNumber)
        return Int(idLast)
    }
    
    //MARK:
    //MARK: Supportive Functions
    
   func getRecords(_ strQuery: String) -> [Any] {
        return lookupAll(forSQL: strQuery)
    }

    fileprivate func prepare(_ sql: String) -> OpaquePointer? {
        //        let utfsql = sql.utf8
        var statement: OpaquePointer? = nil
        if sqlite3_prepare(db, sql, -1, &statement, nil) == SQLITE_OK {
            
            if statement == nil {
                return nil
            }
            
            return statement!
        }
        else {
            return nil
        }
    }
    
    fileprivate func lookupAll(forSQL sql: String) -> [Any] {
        var statement: OpaquePointer? = nil
        var result: Any?
        var thisArray = [Any]() /* capacity: 4 */
        statement = prepare(sql)
        if statement != nil {
            while sqlite3_step(statement) == SQLITE_ROW {
                var thisDict = [AnyHashable: Any](minimumCapacity: 4)
                for i in 0..<sqlite3_column_count(statement) {
                    if sqlite3_column_type(statement, i) == SQLITE_NULL {
                        continue
                    }
                    if sqlite3_column_decltype(statement, i) != nil && strcasecmp(sqlite3_column_decltype(statement, i), "Boolean") == 0 {
                        result = sqlite3_column_int(statement, i)
                    }
                    else if sqlite3_column_type(statement, i) == SQLITE_INTEGER {
                        result = sqlite3_column_int(statement, i)
                    }
                    else if sqlite3_column_type(statement, i) == SQLITE_FLOAT {
                        result = Double(Float(sqlite3_column_double(statement, i)))
                    }
                    else {
                        if let textAvailabel = sqlite3_column_text(statement, i) {
                         
                            result = String(cString: textAvailabel)
                            thisDict[String(utf8String: sqlite3_column_name(statement, i))!] = result
                            result = nil
                        }
                    }
                    if result != nil {
                        thisDict[String(utf8String: sqlite3_column_name(statement, i))!] = result
                    }
                }
                thisArray.append(thisDict)
            }
        }
        sqlite3_finalize(statement)
        return thisArray
    }
    

}
