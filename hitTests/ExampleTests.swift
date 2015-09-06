//
//  ExampleTests.swift
//  hit
//
//  Created by Honza Dvorsky on 19/08/2015.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Foundation

import XCTest
@testable import hit

class ExampleTests: HitTestCase {
    
    func testReadmeExample() {
        
        let quotes = [
            (string: "Hasta la Pizza, baby", identifier: "Dino"),
            (string: "Sorry I'm late, my car aborted half way to work", identifier: "Rob"),
            (string: "Icecream always makes me think of Scary Movie. Get it? I scream?", identifier: "Sarah"),
            (string: "Who is not been scarred by love has not lived.", identifier: "John")
        ]
        
        //create an empty index
        let index = Index()
        
        //feed it your data
        index.updateIndexFromRawStringsAndIdentifiers(quotes, save: false)
        
        //search for stuff!
        _ = index.prefixSearch("scar")
        /*
        *   -> 2 results : [
        *                       "scary" -> [ "Sarah" : Range(34..<39) ],
        *                       "scarred" -> [ "John" : Range(16..<23) ]
        *                  ]
        */
    }
    
}
