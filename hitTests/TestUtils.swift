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
    
    func testingBundle() -> Bundle {
        return Bundle(for: type(of: self))
    }
    
    func pairify(_ data: [String: String]) -> [Index.InputPair] {
        var pairs = Array<Index.InputPair>()
        for (identifier, content) in data {
            pairs.append((string: content, identifier: identifier))
        }
        return pairs
    }
    
    func mapify(_ pairs: [Index.TokenIndexPair]) -> Index.IndexData {
        
        var result = Index.IndexData()
        for item in pairs {
            result[item.token] = item.data
        }
        return result
    }
    
    func parseTestingData() throws -> [String: String] {
        
        let jsonUrl = self.testingBundle().url(forResource: "reviewTestingData", withExtension: "json")
        
        let data = try Data(contentsOf: jsonUrl!, options: NSData.ReadingOptions())
        let testingData = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as! [String: String]
        
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

