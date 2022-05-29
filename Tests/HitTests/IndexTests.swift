//
//  IndexTests.swift
//  LazyReview
//
//  Created by Honza Dvorsky on 08/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
@testable import Hit
import XCTest

class IndexTests: HitTestCase {
    func rangeFromString(_ string: String, start: Int, count: Int) -> Index.TokenRange {
        let startIndex = string.startIndex
        let start = string.index(startIndex, offsetBy: start)
        let end = string.index(start, offsetBy: count)
        let range = (start..<end)
        return range
    }

    func testCreatingIndex() {
        let string1 =
            """
            Hello world how is your app SwiftKey doing?I hope well! Because it's surprisingly great!
            Yoyo how is this? SwiftKey rules the world!
            """
        let identifier1 = "review1"

        let string2 = "How amazing app this SwiftKey thing!"
        let identifier2 = "review2"
        let index = Index()

        let pairs = [
            (string: string1, identifier: identifier1),
            (string: string2, identifier: identifier2),
        ]

        let exp = expectation(description: "index search")

        index.updateIndexFromRawStringsAndIdentifiers(pairs, save: false) {
            // now, examine the index
            index.occurrencesOfToken("SwiftKey", completion: { tokenIndexData in

                guard let tokenIndexData = tokenIndexData else {
                    XCTFail("No token index data was found")
                    return
                }

                XCTAssertEqual(tokenIndexData.values.count, 2, "Should have occured in 2 identifiers")

                if let ranges = tokenIndexData["review1"] {
                    // should be sorted
                    let targetRange1 = self.rangeFromString(string1, start: 28, count: 8)
                    let targetRange2 = self.rangeFromString(string1, start: 107, count: 8)
                    XCTAssertEqual(ranges[0], targetRange1, "Ranges must equal")
                    XCTAssertEqual(ranges[1], targetRange2, "Ranges must equal")

                } else {
                    XCTFail("No ranges data for identifier review1")
                }

                if let ranges = tokenIndexData["review2"] {
                    // should be sorted
                    let targetRange = self.rangeFromString(string2, start: 21, count: 8)
                    XCTAssertEqual(ranges[0], targetRange, "Ranges must equal")

                } else {
                    XCTFail("No ranges data for identifier review2")
                }

                exp.fulfill()
            })
        }

        waitForExpectations(timeout: 10, handler: nil)
    }

    // watch out - this might take minutes, runs the whole thing 10 times and the data is pretty large
    // takes seconds per run
    func testPerformance_fullIndexCreation() throws {
        let data = try parseTestingData()

        measure { () in
            let index = Index()
            let pairs = self.pairify(data)
            let exp = self.expectation(description: "updated")
            index.updateIndexFromRawStringsAndIdentifiers(pairs, save: false, completion: { () in
                exp.fulfill()
            })
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }

    func testCorrectness_indexMerging_reduce_binary() throws {
        let data = try parseTestingData()
        let pairs = pairify(data)
        let index = Index()

        let indices = index.createIndicesFromRawStringsAndIdentifiers(pairs)

        var merged_reduce: Index.IndexData?
        autoreleasepool { () in
            // reduce
            merged_reduce = index.reduceMerge(indices)
        }

        var merged_binary: Index.IndexData?
        autoreleasepool { () in
            // binary
            merged_binary = index.binaryMerge(indices)
        }

        // must equal
        let equal = isIndexDataEqualToIndexData(merged_binary!, rhs: merged_reduce!)

        XCTAssert(equal, "Both must give the same results! Binary: \(merged_binary!), Reduce: \(merged_reduce!)")
    }

    func testPerformance_indexMerging_reduce() throws {
        let data = try parseTestingData()
        let pairs = pairify(data)
        let index = Index()

        let indices = index.createIndicesFromRawStringsAndIdentifiers(pairs)

        measure { () in

            _ = index.reduceMerge(indices)
        }
    }

    func testPerformance_indexMerging_binary() throws {
        let data = try parseTestingData()
        let pairs = pairify(data)
        let index = Index()

        let indices = index.createIndicesFromRawStringsAndIdentifiers(pairs)

        measure { () in

            _ = index.binaryMerge(indices)
        }
    }

    func testPrefixSearch() throws {
        let pairs = pairify(try parseTestingData())
        let index = Index()

        let exp = expectation(description: "updated")
        index.updateIndexFromRawStringsAndIdentifiers(pairs, save: false, completion: {
            // try to search for swiftkey by typing "sw"

            let results = index.prefixSearch("sw")
            let resultsMap = self.mapify(results)

            let expected = ["swipe", "swype", "swiping", "swiftkey", "switched", "switch"]

            if results.count != expected.count {
                XCTFail("Mismatch of count. Expected: \(expected), Received: \(Array(resultsMap.keys))")
            } else {
                for expectedToken in expected {
                    if resultsMap[expectedToken] == nil {
                        // fail
                        XCTFail(
                            "Mismatch of expected and received results, didn't find expected token: \(expectedToken)"
                        )
                    }
                }
            }

            // if it went through, we're all good
            exp.fulfill()
        })
        waitForExpectations(timeout: 10, handler: nil)
    }

    // utils
}
