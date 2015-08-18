//
//  TrieTests.swift
//  LazyReview
//
//  Created by Honza Dvorsky on 08/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import UIKit
import XCTest
import hit

class TrieTests: ModelTestCase {

    func testTrieCreation_exactMatches() {
        
        let strings = ["swiftkey", "swype", "hello", "london", "reality", "fantasy"]
        let trie = Trie(strings: strings)
        
        let foundStrings = trie.stringsMatchingPrefix("sw")
        XCTAssert(foundStrings.indexOf("swiftkey") != nil, "Couldn't find 'swiftkey' in results")
        XCTAssert(foundStrings.indexOf("swype") != nil, "Couldn't find 'swiftkey' in results")
    }
    
    
    func testCorrectness_inputOutput() {
        let tokens = try! self.prepTokensForTrieTesting()
        let trie = Trie(strings: tokens)
        let resultTokens = trie.exportTrie()
        
        for token in tokens {
            if resultTokens.indexOf(token) == nil {
                XCTFail("Didn't return token \(token)")
            }
        }
        //all good
    }
    
    func testPerformance_trieCreation() {
        
        let tokens = try! self.prepTokensForTrieTesting()
        
        self.measureBlock { () -> Void in
            _ = Trie(strings: tokens)
        }
    }
    
    func testPerformance_trieSearch() {
        
        let tokens = try! self.prepTokensForTrieTesting()
        let trie = Trie(strings: tokens)

        self.measureBlock { () -> Void in
            _ = trie.stringsMatchingPrefix("sw")
        }
    }

    
}
