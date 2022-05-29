//
//  Trie.swift
//  LazyReview
//
//  Created by Honza Dvorsky on 08/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation

private typealias SubTries = [String: TrieNode]

struct TrieNode {
    let token: String
    let endsWord: Bool
    let subNodes: [String: TrieNode]
}

extension TrieNode {
    init(_ string: String) {
        let headRange = (string.startIndex..<string.index(string.startIndex, offsetBy: 1))
        let head = String(string[headRange])

        let length = string.count
        if length > 1 {
            let tail = String(string[headRange.upperBound...])
            let subTrie = TrieNode(tail)
            let subNodes = [subTrie.token: subTrie]

            self.init(token: head, endsWord: false, subNodes: subNodes)
        } else {
            self.init(token: head, endsWord: true, subNodes: SubTries())
        }
    }

    init(_ strings: [String]) {
        let tries = strings.map { (string: String) -> TrieNode in
            // normalize first
            let normalized = string.lowercased()
            let trie = TrieNode(normalized)
            return trie
        }

        // we need all the tries to have an empty root so that we can merge them easily
        let triesWithRoots = tries.map { (trie: TrieNode) -> TrieNode in
            TrieNode(token: "", endsWord: false, subNodes: [trie.token: trie])
        }

        // now merge them
        self = triesWithRoots.reduce(into: Trie.emptyTrie()) { (rollingTrie: inout TrieNode, thisTrie) in
            rollingTrie = TrieNode.mergeTries(left: rollingTrie, right: thisTrie)
        }
    }

    static func mergeTries(left: TrieNode, right: TrieNode) -> TrieNode {
        assert(left.token == right.token, "Mergable tries need to have the same token")

        let endsWord = left.endsWord || right.endsWord
        let token = left.token // or right, they're the same string.
        let subnodes = Dictionary.merge(left.subNodes, two: right.subNodes) { TrieNode.mergeTries(left: $0, right: $1) }

        let result = TrieNode(token: token, endsWord: endsWord, subNodes: subnodes)
        return result
    }
}

public struct Trie {
    typealias TokenRange = Range<String.Index>
    let root: TrieNode

    public init(strings: [String]) {
        root = TrieNode(strings)
    }

    public func exportTrie() -> [String] {
        return Trie.pullStringsFromTrie(root)
    }

    public func strings(matching prefix: String) -> [String] {
        let normalized = prefix.lowercased()
        if let trieRoot = Trie.findTrieEndingPrefix(normalized, trie: root) {
            let strings = Trie.pullStringsFromTrie(trieRoot)
            let stringsWithPrefix = strings.map { (s: String) -> String in
                // here we take the last char out of the prefix, because it's already contained
                // in the found trie.
                String(normalized.dropLast()) + s
            }
            return stringsWithPrefix
        }
        return [String]()
    }

    static func findTrieEndingPrefix(_ prefix: String, trie: TrieNode) -> TrieNode? {
        let length = prefix.count
        assert(length > 0, "Invalid arg: cannot be empty string")

        let prefixHeadRange = (prefix.startIndex..<prefix.index(prefix.startIndex, offsetBy: 1))
        let prefixHead = prefix[prefixHeadRange]
        let emptyTrie = trie.token.count == 0

        if length == 1 && !emptyTrie {
            // potentially might be found if trie matches
            let match = (trie.token == prefixHead)
            return match ? trie : nil
        }

        let tokenMatches = trie.token == prefixHead
        if emptyTrie || tokenMatches {
            // compute tail - the whole prefix if this was an empty trie
            let prefixTail = emptyTrie ? prefix : String(prefix[prefixHeadRange.upperBound...])

            // look into subnodes
            for subnode in trie.subNodes.values {
                if let foundSubnode = Trie.findTrieEndingPrefix(prefixTail, trie: subnode) {
                    return foundSubnode
                }
            }
        }
        return nil
    }

    static func pullStringsFromTrie(_ trie: TrieNode) -> [String] {
        let token = trie.token
        let subnodes = Array(trie.subNodes.values)
        let endsWord = trie.endsWord

        // get substrings of subnodes
        var substrings = subnodes.map { (subnode: TrieNode) -> [String] in
            let substrings = Trie.pullStringsFromTrie(subnode)
            // prepend our token to each
            let withToken = substrings.map { token + $0 }
            return withToken
        }.reduce([String]()) { rolling, item -> [String] in // flatten [[String]] to [String]
            rolling + item
        }

        if endsWord {
            // also add a new string ending with this token
            substrings.append(token)
        }

        return substrings
    }

    static func leafTrie(_ token: String) -> TrieNode {
        return TrieNode(token: token, endsWord: true, subNodes: SubTries())
    }

    static func emptyTrie() -> TrieNode {
        return TrieNode(token: "", endsWord: false, subNodes: SubTries())
    }

    // TODO: we learned in indexing that binary merge is much better than a rolling reduce
//    static func binaryMerge() {
//
//    }
}
