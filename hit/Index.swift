//
//  Index.swift
//  LazyReview
//
//  Created by Honza Dvorsky on 07/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
/**
*  The index is created in the following way

    [
        "token1": [
            "identifier1": [
                range11, range12, range13, ...
            ],
            "identifier2": [
                range21, range22, ...
            ], ...
        ],
        "token2": [
            ...
        ], ...
    ]

The "identifier" can be anything that helps us look up the container of that text. A review, a file, ...
So that when we find it, we can directly find that word at the specified range.

The indexing itself will run in a map-reduce manner - indexing will run in multiple jobs
and only when done we merge all results into the new index.
*/
open class Index {
    
    public typealias InputPair = (string: String, identifier: String)
    public typealias TokenRange = Range<String.Index>
    public typealias TokenRangeArray = [TokenRange] //MUST be sorted in ascending order
    public typealias TokenIndexData = [String: TokenRangeArray]
    public typealias TokenIndexPair = (token: String, data: TokenIndexData)
    public typealias IndexData = [String: TokenIndexData]
    
    fileprivate var indexStorage: IndexData = [:]
    fileprivate var trieStorage: Trie = Trie(strings: [String]())
    fileprivate let operationQueue: OperationQueue
    
    public init() {
        
        self.operationQueue = OperationQueue()
        
        //load from storage
        self.load()
    }
    
    fileprivate func load() -> Bool {
        //TODO: load from disk here
        return true
    }
    
    fileprivate func save() -> Bool {
        //TODO: save to disk here
        return true
    }
    
    //PUBLIC API
    
    open func occurencesOfToken(_ token: String, completion: @escaping (_ result: TokenIndexData?) -> ())  {
        
        let normalizedToken = self.normalizedToken(token)
        self.operationQueue.addOperation { () -> Void in
            let result = self.indexStorage[normalizedToken]
            completion(result)
        }
    }
    
    open func occurencesOfTokensWithPrefix(_ prefix: String, completion: @escaping (_ result: [TokenIndexPair]) -> ())  {
        
        self.operationQueue.addOperation { () -> Void in
            let result = self.prefixSearch(prefix)
            completion(result)
        }
    }
    
    open func updateIndexFromRawStringsAndIdentifiers(_ pairs: [InputPair], save: Bool,
        completion: @escaping (() -> ())) {
        
        self.operationQueue.addOperation { () -> Void in
            self.updateIndexFromRawStringsAndIdentifiers(pairs, save: save)
            completion()
        }
    }
    
    //returns when done, synchronous version
    open func updateIndexFromRawStringsAndIdentifiers(_ pairs: [InputPair], save: Bool) {
        let newIndex = self.createIndexFromRawStringsAndIdentifiers(pairs)
        self.mergeNewDataIn(newIndex, save: save)
    }
    
    //try to hide the stuff below for testing eyes only
    
    //TODO: add an enum with a sort type - by Total Occurences, Length, Unique Review Occurences, ...
    open func prefixSearch(_ prefix: String) -> [TokenIndexPair] {
        
        let normalizedPrefix = self.normalizedToken(prefix)
        if normalizedPrefix.characters.count < 2 {
            return [TokenIndexPair]() //don't return results under three chars (0, 1, 2).
        }
                
        //create a list of tokens from prefix
        let (indexData, trieData) = self.threadSafeGetStorage()
        
        //filter the keys that match the prefix
        //we're using a fast trie here
        let filtered = trieData.stringsMatchingPrefix(normalizedPrefix)
        
        //now sort them by length (I think that makes sense for prefix search - shortest match is the best)
        //if two are of the same length, sort those two alphabetically
        let sortedByLength = filtered.sorted() {
            (s1: String, s2: String) -> Bool in
            
            let count1 = s1.characters.count
            let count2 = s2.characters.count
            
            if count1 == count2 {
                //now decide by alphabet
                return s1.localizedCaseInsensitiveCompare(s2) == ComparisonResult.orderedAscending
            }
            
            return count1 < count2
        }
        
        //now fetch index metadata for all the matches and return 
        //TODO: count limiting?
        
        let result = sortedByLength.map { (token: $0, data: indexData[$0]!) }
        return result
    }
    
    open func createIndexFromRawStringsAndIdentifiers(_ pairs: [InputPair]) -> IndexData {
        let flattened = self.createIndicesFromRawStringsAndIdentifiers(pairs)
        let merged = self.binaryMerge(flattened)
        return merged
    }
    
    open func createIndicesFromRawStringsAndIdentifiers(_ pairs: [InputPair]) -> [IndexData] {
        let flattened = pairs.reduce([IndexData]()) { (arr, item) -> [IndexData] in
            return arr + self.createIndicesFromRawString(item.string, identifier: item.identifier)
        }
        return flattened
    }
    
    fileprivate func threadSafeGetStorage() -> (index: IndexData, trie: Trie) {
        objc_sync_enter(self)
        let indexStorage = self.indexStorage
        let trieStorage = self.trieStorage
        objc_sync_exit(self)
        return (indexStorage, trieStorage)
    }
    
    public typealias ViewTokenCount = (token: String, count: Int)
    
    //aka number of occurences total
    open func viewOfTokensSortedByNumberOfOccurences() -> [ViewTokenCount] {
        
        let (indexStorage, _) = self.threadSafeGetStorage()
        
        var view = [ViewTokenCount]()
        
        for (token, tokenIndexData) in indexStorage {
            
            //get count of identifiers
            var rollingCount = 0
            for (_, identifierRangeArray) in tokenIndexData {
                rollingCount += identifierRangeArray.count
            }
            view.append((token: token, count: rollingCount))
        }
        
        //sort by number of occurences
        view.sort() { $0.count >= $1.count }
        
        return view
    }

    //aka number of reviews mentioning this word (doesn't matter how many times in one review)
    open func viewOfTokensSortedByNumberOfUniqueIdentifierOccurences() -> [ViewTokenCount] {
        
        objc_sync_enter(self)
        let indexStorage = self.indexStorage
        objc_sync_exit(self)

        var view = [ViewTokenCount]()
        
        for (token, tokenIndexData) in indexStorage {
            
            //get count of identifiers
            let tokenCharCount = tokenIndexData.keys.count
            view.append((token: token, count: tokenCharCount))
        }
        
        //sort by number of occurences
        view.sort { $0.count >= $1.count }
        
        return view
    }
    
    open func createIndicesFromRawString(_ string: String, identifier: String) -> [IndexData] {
        
        //iterate through the string
        var newIndices = [IndexData]()
        
        let range = string.characters.startIndex..<string.characters.endIndex
        let options = String.EnumerationOptions([.localized, .byWords])
        string.enumerateSubstrings(in: range, options: options) { (substring, substringRange, enclosingRange, stop) -> () in
            
            guard let substring = substring else { return }
            
            //enumerating over tokens (words) and update index from each
            let newIndexData = self.createIndexFromToken(substring, range: substringRange, identifier: identifier)
            newIndices.append(newIndexData)
        }
        return newIndices
    }
    
    open func createIndexFromRawString(_ string: String, identifier: String) -> IndexData {
        
        let newIndices = self.createIndicesFromRawString(string, identifier: identifier)

        //TODO: measure and multithread
        
        //merge all those indices for each occurence into one index
        let reduced = self.binaryMerge(newIndices)
        
        return reduced
    }
    
    open func reduceMerge(_ indexDataArray: [IndexData]) -> IndexData {
        
        //ok, now we have an array of new indices, merge them into one and return
        //This was pretty slow due to the first index getting large towards the end
        let reduced = indexDataArray.reduce(IndexData()) { (bigIndex, newIndex) -> IndexData in
            return self.mergeIndexData(bigIndex, two: newIndex)
        }
        return reduced
    }
    
    /**
    Merges index data in pairs instead of having one big rolling index that every new one is merged with.
    */
    open func binaryMerge(_ indexDataArray: [IndexData]) -> IndexData {
        
        //termination condition 1
        if indexDataArray.count == 1 {
            return indexDataArray.first!
        }
        
        //termination condition 2
        if indexDataArray.count == 2 {
            return self.mergeIndexData(indexDataArray.first!, two: indexDataArray.last!)
        }
        
        var newIndexDataArray = [IndexData]()
        
        //go through and merge in neightboring pairs
        var temp = [IndexData]()
        for i in 0 ..< indexDataArray.count {
            let second = temp.count == 1
            
            //if second, we're adding the second one, so let's merge
            temp.append(indexDataArray[i])
            if second {
                let merged = self.binaryMerge(temp)
                temp.removeAll(keepingCapacity: true)
                newIndexDataArray.append(merged)
            }
        }
        
        //if the cound was odd, we have the last item unmerged with anyone, just add at the end of the new array
        if indexDataArray.count % 2 == 1 {
            newIndexDataArray.append(indexDataArray.last!)
        }
        
        return self.binaryMerge(newIndexDataArray)
    }
    
    fileprivate func createIndexFromToken(_ token: String, range: TokenRange, identifier: String) -> IndexData {
        
        let normalizedToken = self.normalizedToken(token)
        return [ normalizedToken: [ identifier: [range] ] ]
    }
    
    //this allows us to have multithreaded indexing and only at the end modify shared state :)
    fileprivate func mergeNewDataIn(_ newData: IndexData, save: Bool) {
        
        //merge these two structures together and keep the result
        objc_sync_enter(self)
        self.indexStorage = self.mergeIndexData(self.indexStorage, two: newData)
        
        //recreate the Trie (TODO: don't recreate the whole thing, make it easier to append to the existing Trie)
        self.trieStorage = Trie(strings: Array(self.indexStorage.keys))
        
        if save {
            self.save()
        }
        objc_sync_exit(self)
    }
    
    fileprivate func normalizedToken(_ found: String) -> String {
        
        //just lowercase
        return found.lowercased()
    }
    
}

public func isDictionaryEqualToDictionary<Key, Value>(_ lhs: [Key: Value], rhs: [Key: Value], compareValues: (_ lhs: Value, _ rhs: Value) -> Bool) -> (Bool, (key: Key, values: [Value?])?) {
    
    if lhs.count != rhs.count {
        return (false, nil)
    }
    
    //keys are the same, we have to go through them one by one
    for (key, value) in lhs {
        if let rightValue = rhs[key] {
            if compareValues(value, rightValue) {
                //keeping your hopes up, still might be equal
                continue
            }
        }
        
        //returns the first offender of equality
        return (false, (key: key, [value, rhs[key]]))
    }
    return (true, nil)
}

public func isIndexDataEqualToIndexData(_ lhs: Index.IndexData, rhs: Index.IndexData) -> Bool {
    
    let (equal, _) = isDictionaryEqualToDictionary(lhs, rhs: rhs) { (lhsIn, rhsIn) -> Bool in
        
        let (equalIn, _) = isDictionaryEqualToDictionary(lhsIn, rhs: rhsIn) { (lhsInIn, rhsInIn) -> Bool in
            return lhsInIn == rhsInIn
        }
        return equalIn
    }
    return equal
}

//merging
extension Index {
    
    fileprivate func mergeIndexData(_ one: IndexData, two: IndexData) -> IndexData {
        
        return Dictionary.merge(one, two: two, merge: { (one, two) -> TokenIndexData in
            return self.mergeTokenIndexData(one, two: two)
        })
    }

    fileprivate func mergeTokenIndexData(_ one: TokenIndexData, two: TokenIndexData) -> TokenIndexData {
        
        return Dictionary.merge(one, two: two, merge: { (one, two) -> TokenRangeArray in
            return self.mergeTokenRangeArrays(one, two: two)
        })
    }
    
    fileprivate func mergeTokenRangeArrays(_ one: TokenRangeArray, two: TokenRangeArray) -> TokenRangeArray {
        
        //merge arrays
        //1. concat
        let both = one + two
        
        //2. sort
        let sorted = both.sorted() { $0.lowerBound <= $1.lowerBound }
        
        //3. remove duplicates
        let result = sorted.reduce(TokenRangeArray()) { (arr, range) -> TokenRangeArray in
            if let last = arr.last {
                if last == range {
                    //we already have this range, don't add it again
                    return arr
                }
            }
            
            //haven't seen this range before, add it
            return arr + [range]
        }
        
        return result
    }
}

extension Dictionary {
    
    static func merge(_ one: [Key:Value], two: [Key:Value], merge: (_ one: Value, _ two: Value) -> Value) -> [Key:Value] {
        var one = one, two = two
        
        //iterate over one, take the unique ones immediately, merge the ones that are also in two
        for (key, oneValue) in one {
            if let twoValue = two.removeValue(forKey: key) {
                //two has a value for key
                //merge the values and add that
                one[key] = merge(oneValue, twoValue)
            }
            //else, was unique in one, keep it there
        }
        
        //now take the rest from two that haven't been removed (I wish there was a first party, faster implementation)
        for (key, twoValue) in two {
            one[key] = twoValue
        }
        
        //we're done
        return one
    }
}






