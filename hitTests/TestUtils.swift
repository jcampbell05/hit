//
//  TestUtils.swift
//  LazyReview
//
//  Created by Honza Dvorsky on 08/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import XCTest
import hit

class HitTestCase : XCTestCase {
    
    func testingBundle() -> NSBundle {
        return NSBundle(forClass: self.dynamicType)
    }
    
    func pairify(data: [String: String]) -> [Index.InputPair] {
        var pairs = Array<Index.InputPair>()
        for (identifier, content) in data {
            pairs.append((string: content, identifier: identifier))
        }
        return pairs
    }
    
    func mapify(pairs: [Index.TokenIndexPair]) -> Index.IndexData {
        
        var result = Index.IndexData()
        for item in pairs {
            result[item.token] = item.data
        }
        return result
    }
    
    func parseTestingData() throws -> [String: String] {
        
        let jsonUrl = self.testingBundle().URLForResource("reviewTestingData", withExtension: "json")
        
        let data = try NSData(contentsOfURL: jsonUrl!, options: NSDataReadingOptions())
        let testingData = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as! [String: String]
        
        return testingData
    }
    
    func prepTokensForTrieTesting() throws -> [String] {
        let pairs = self.pairify(try self.parseTestingData())
        let index = Index()
        let indexData = index.createIndexFromRawStringsAndIdentifiers(pairs)
        let tokens = Array(indexData.keys)
        return tokens
    }


}

