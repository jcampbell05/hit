//
//  TrieTests.swift
//  LazyReview
//
//  Created by Honza Dvorsky on 08/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

@testable import Hit
import XCTest

class TrieTests: HitTestCase {
    func commonWords() -> [String] {
        let strings = ["swiftkey", "swype", "hello", "london", "reality", "fantasy", "stuff"]
        return strings
    }

    func testTrieCreation_exactMatches() {
        let strings = commonWords()
        let trie = Trie(strings: strings)

        let foundStrings = trie.strings(matching: "sw")
        XCTAssert(foundStrings.firstIndex(of: "swiftkey") != nil, "Couldn't find 'swiftkey' in results")
        XCTAssert(foundStrings.firstIndex(of: "swype") != nil, "Couldn't find 'swiftkey' in results")
    }

    func testCorrectness_inputOutput() throws {
        let tokens = try prepTokensForTrieTesting()
        let trie = Trie(strings: tokens)
        let resultTokens = trie.exportTrie()

        for token in tokens {
            if resultTokens.firstIndex(of: token) == nil {
                XCTFail("Didn't return token \(token)")
            }
        }
        // all good
    }

    func testPerformance_trieCreation() throws {
        let tokens = try prepTokensForTrieTesting()

        measure { () in
            _ = Trie(strings: tokens)
        }
    }

    func testPerformance_trieSearch() throws {
        let tokens = try prepTokensForTrieTesting()
        let trie = Trie(strings: tokens)

        measure { () in
            _ = trie.strings(matching: "sw")
        }
    }

    func testCorrectness_singleCharSearch() {
        let strings = commonWords()
        let trie = Trie(strings: strings)

        let foundStrings = Set(trie.strings(matching: "s"))
        XCTAssertEqual(foundStrings.count, 3)
        XCTAssert(foundStrings.contains("swiftkey"))
        XCTAssert(foundStrings.contains("swype"))
        XCTAssert(foundStrings.contains("stuff"))
    }
}
