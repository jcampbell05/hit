//
//  TestUtils.swift
//  LazyReview
//
//  Created by Honza Dvorsky on 08/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import Hit
import XCTest

class HitTestCase: XCTestCase {
    func testingBundle() -> Bundle {
        return Bundle(for: type(of: self))
    }

    func pairify(_ data: [String: String]) -> [Index.InputPair] {
        var pairs = [Index.InputPair]()
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
        let jsonUrl = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .appendingPathComponent("reviewTestingData.json")

        let data = try Data(contentsOf: jsonUrl)
        let testingData = try JSONSerialization
            // swiftlint:disable:next force_cast
            .jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as! [String: String]

        return testingData
    }

    func prepTokensForTrieTesting() throws -> [String] {
        let pairs = pairify(try parseTestingData())
        let index = Index()
        let indexData = index.createIndexFromRawStringsAndIdentifiers(pairs)
        let tokens = Array(indexData.keys)
        return tokens
    }
}
