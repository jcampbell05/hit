//
//  Trie.swift
//  LazyReview
//
//  Created by Honza Dvorsky on 08/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation

struct TrieNode {
    
    let token: String
    let endsWord: Bool
    let subnodes: [String: TrieNode]
}

public struct Trie {
    
    typealias TokenRange = Range<String.Index>
    typealias SubTries = [String: TrieNode]
    let root: TrieNode
    
    public init(strings: [String]) {
        
        self.root = Trie.createTrieFromStrings(strings)
    }
    
    public func exportTrie() -> [String] {
        return Trie.pullStringsFromTrie(self.root)
    }
    
    public func stringsMatchingPrefix(_ prefix: String) -> [String] {
        let normalized = prefix.lowercased()
        if let trieRoot = Trie.findTrieEndingPrefix(normalized, trie: self.root) {
            let strings = Trie.pullStringsFromTrie(trieRoot)
            let stringsWithPrefix = strings.map {
                (s: String) -> String in
                
                //here we take the last char out of the prefix, because it's already contained
                //in the found trie.
                return String(normalized.dropLast()) + s
            }
            return stringsWithPrefix
        }
        return [String]()
    }
    
    static func findTrieEndingPrefix(_ prefix: String, trie: TrieNode) -> TrieNode? {
        
        let length = prefix.count
        assert(length > 0, "Invalid arg: cannot be empty string")
        
        let prefixHeadRange = (prefix.startIndex ..< prefix.index(prefix.startIndex, offsetBy: 1))
        let prefixHead = prefix[prefixHeadRange]
        let emptyTrie = trie.token.count == 0

        if length == 1 && !emptyTrie {
            
            //potentially might be found if trie matches
            let match = (trie.token == prefixHead)
            return match ? trie : nil
        }
        
        let tokenMatches = trie.token == prefixHead
        if emptyTrie || tokenMatches {
            
            //compute tail - the whole prefix if this was an empty trie
            let prefixTail = emptyTrie ? prefix : String(prefix[prefixHeadRange.upperBound...])
            
            //look into subnodes
            for subnode in trie.subnodes.values {
                if let foundSubnode = Trie.findTrieEndingPrefix(prefixTail, trie: subnode) {
                    return foundSubnode
                }
            }
        }
        return nil
    }
    
    static func pullStringsFromTrie(_ trie: TrieNode) -> [String] {
        
        let token = trie.token
        let subnodes = Array(trie.subnodes.values)
        let endsWord = trie.endsWord

        //get substrings of subnodes
        var substrings = subnodes.map {
            (subnode: TrieNode) -> [String] in
            let substrings = Trie.pullStringsFromTrie(subnode)
            
            //prepend our token to each
            let withToken = substrings.map {
                (string: String) -> String in
                return token + string
            }
            return withToken
        }.reduce([String]()) { (rolling, item) -> [String] in //flatten [[String]] to [String]
            return rolling + item
        }

        if endsWord {
            //also add a new string ending with this token
            substrings.append(token)
        }
        
        return substrings
    }
    
    static func createTrieFromStrings(_ strings: [String]) -> TrieNode {
        
        let tries = strings.map {
            (string: String) -> TrieNode in
            
            //normalize first
            let normalized = string.lowercased()
            let trie = Trie.createTrieFromString(normalized)
            return trie
        }
        
        //we need all the tries to have an empty root so that we can merge them easily
        let triesWithRoots = tries.map {
            (trie: TrieNode) -> TrieNode in
            return TrieNode(token: "", endsWord: false, subnodes: [trie.token: trie])
        }
        
        //now merge them
        let resultTrie = triesWithRoots.reduce(Trie.emptyTrie()) { (rollingTrie, thisTrie) -> TrieNode in
            return Trie.mergeTries(left: rollingTrie, right: thisTrie)
        }
        
        return resultTrie
    }
    
    static func createTrieFromString(_ string: String) -> TrieNode {
        
        let headRange = (string.startIndex ..< string.index(string.startIndex, offsetBy: 1))
        let head = String(string[headRange])
        
        let length = string.count
        if length > 1 {
            let tail = String(string[headRange.upperBound...])
            let subtrie = self.createTrieFromString(tail)
            let subnodes = [subtrie.token: subtrie]
            
            return TrieNode(token: head, endsWord: false, subnodes: subnodes)
        } else {
            return TrieNode(token: head, endsWord: true, subnodes: SubTries())
        }
    }

    static func leafTrie(_ token: String) -> TrieNode {
        return TrieNode(token: token, endsWord: true, subnodes: SubTries())
    }
    
    static func emptyTrie() -> TrieNode {
        return TrieNode(token: "", endsWord: false, subnodes: SubTries())
    }
    
    static func mergeTries(left: TrieNode, right: TrieNode) -> TrieNode {
        
        assert(left.token == right.token, "Mergable tries need to have the same token")
        
        let endsWord = left.endsWord || right.endsWord
        let token = left.token //or right, they're the same string.
        let subnodes = Dictionary.merge(left.subnodes, two: right.subnodes) { Trie.mergeTries(left: $0, right: $1) }
        
        let result = TrieNode(token: token, endsWord: endsWord, subnodes: subnodes)
        return result
    }
    
    //TODO: we learned in indexing that binary merge is much better than a rolling reduce
//    static func binaryMerge() {
//        
//    }
    
}

