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
public class Index {
    
    public typealias InputPair = (string: String, identifier: String)
    public typealias TokenRange = Range<String.Index>
    public typealias TokenRangeArray = [TokenRange] //MUST be sorted in ascending order
    public typealias TokenIndexData = [String: TokenRangeArray]
    public typealias TokenIndexPair = (token: String, data: TokenIndexData)
    public typealias IndexData = [String: TokenIndexData]
    
    private var indexStorage: IndexData = [:]
    private var trieStorage: Trie = Trie(strings: [String]())
    private let operationQueue: NSOperationQueue
    
    public init() {
        
        self.operationQueue = NSOperationQueue()
        
        //load from storage
        self.load()
    }
    
    private func load() -> Bool {
        //TODO: load from disk here
        return true
    }
    
    private func save() -> Bool {
        //TODO: save to disk here
        return true
    }
    
    //PUBLIC API
    
    public func occurencesOfToken(token: String, completion: (result: TokenIndexData?) -> ())  {
        
        let normalizedToken = self.normalizedToken(token)
        self.operationQueue.addOperationWithBlock { () -> Void in
            let result = self.indexStorage[normalizedToken]
            completion(result: result)
        }
    }
    
    public func occurencesOfTokensWithPrefix(prefix: String, completion: (result: [TokenIndexPair]) -> ())  {
        
        self.operationQueue.addOperationWithBlock { () -> Void in
            let result = self.prefixSearch(prefix)
            completion(result: result)
        }
    }
    
    public func updateIndexFromRawStringsAndIdentifiers(pairs: [InputPair], save: Bool,
        completion: (() -> ())?) {
        
        self.operationQueue.addOperationWithBlock { () -> Void in
            self.updateIndexFromRawStringsAndIdentifiers(pairs, save: save)
            completion?()
        }
    }
    
    //returns when done, synchronous version
    public func updateIndexFromRawStringsAndIdentifiers(pairs: [InputPair], save: Bool) {
        let newIndex = self.createIndexFromRawStringsAndIdentifiers(pairs)
        self.mergeNewDataIn(newIndex, save: save)
    }
    
    //try to hide the stuff below for testing eyes only
    
    //TODO: add an enum with a sort type - by Total Occurences, Length, Unique Review Occurences, ...
    public func prefixSearch(prefix: String) -> [TokenIndexPair] {
        
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
        let sortedByLength = filtered.sort() {
            (s1: String, s2: String) -> Bool in
            
            let count1 = s1.characters.count
            let count2 = s2.characters.count
            
            if count1 == count2 {
                //now decide by alphabet
                return s1.localizedCaseInsensitiveCompare(s2) == NSComparisonResult.OrderedAscending
            }
            
            return count1 < count2
        }
        
        //now fetch index metadata for all the matches and return 
        //TODO: count limiting?
        
        let result = sortedByLength.map { (token: $0, data: indexData[$0]!) }
        return result
    }
    
    public func createIndexFromRawStringsAndIdentifiers(pairs: [InputPair]) -> IndexData {
        let flattened = self.createIndicesFromRawStringsAndIdentifiers(pairs)
        let merged = self.binaryMerge(flattened)
        return merged
    }
    
    public func createIndicesFromRawStringsAndIdentifiers(pairs: [InputPair]) -> [IndexData] {
        let flattened = pairs.reduce([IndexData]()) { (arr, item) -> [IndexData] in
            return arr + self.createIndicesFromRawString(item.string, identifier: item.identifier)
        }
        return flattened
    }
    
    private func threadSafeGetStorage() -> (index: IndexData, trie: Trie) {
        objc_sync_enter(self)
        let indexStorage = self.indexStorage
        let trieStorage = self.trieStorage
        objc_sync_exit(self)
        return (indexStorage, trieStorage)
    }
    
    public typealias ViewTokenCount = (token: String, count: Int)
    
    //aka number of occurences total
    public func viewOfTokensSortedByNumberOfOccurences() -> [ViewTokenCount] {
        
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
        view.sortInPlace() { $0.count >= $1.count }
        
        return view
    }

    //aka number of reviews mentioning this word (doesn't matter how many times in one review)
    public func viewOfTokensSortedByNumberOfUniqueIdentifierOccurences() -> [ViewTokenCount] {
        
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
        view.sortInPlace { $0.count >= $1.count }
        
        return view
    }
    
    public func createIndicesFromRawString(string: String, identifier: String) -> [IndexData] {
        
        //iterate through the string
        var newIndices = [IndexData]()
        
        let range: Range<String.Index> = TokenRange(start: string.startIndex, end: string.endIndex)
        let options = NSStringEnumerationOptions([.Localized, .ByWords])
        string.enumerateSubstringsInRange(range, options: options) { (substring, substringRange, enclosingRange, stop) -> () in
            
            guard let substring = substring else { return }
            
            //enumerating over tokens (words) and update index from each
            let newIndexData = self.createIndexFromToken(substring, range: substringRange, identifier: identifier)
            newIndices.append(newIndexData)
        }
        return newIndices
    }
    
    public func createIndexFromRawString(string: String, identifier: String) -> IndexData {
        
        let newIndices = self.createIndicesFromRawString(string, identifier: identifier)

        //TODO: measure and multithread
        
        //merge all those indices for each occurence into one index
        let reduced = self.binaryMerge(newIndices)
        
        return reduced
    }
    
    public func reduceMerge(indexDataArray: [IndexData]) -> IndexData {
        
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
    public func binaryMerge(indexDataArray: [IndexData]) -> IndexData {
        
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
                temp.removeAll(keepCapacity: true)
                newIndexDataArray.append(merged)
            }
        }
        
        //if the cound was odd, we have the last item unmerged with anyone, just add at the end of the new array
        if indexDataArray.count % 2 == 1 {
            newIndexDataArray.append(indexDataArray.last!)
        }
        
        return self.binaryMerge(newIndexDataArray)
    }
    
    private func createIndexFromToken(token: String, range: TokenRange, identifier: String) -> IndexData {
        
        let normalizedToken = self.normalizedToken(token)
        return [ normalizedToken: [ identifier: [range] ] ]
    }
    
    //this allows us to have multithreaded indexing and only at the end modify shared state :)
    private func mergeNewDataIn(newData: IndexData, save: Bool) {
        
        //merge these two structures together and keep the result
        objc_sync_enter(self)
        self.indexStorage = self.mergeIndexData(self.indexStorage, two: newData)
        
        //recreate the Trie (TODO: don't recreate the whole thing, make it easier to append to the existing Trie)
        self.trieStorage = Trie(strings: self.indexStorage.keys.array)
        
        if save {
            self.save()
        }
        objc_sync_exit(self)
    }
    
    private func normalizedToken(found: String) -> String {
        
        //just lowercase
        return found.lowercaseString
    }
    
}

public func isDictionaryEqualToDictionary<Key, Value>(lhs: [Key: Value], rhs: [Key: Value], compareValues: (lhs: Value, rhs: Value) -> Bool) -> (Bool, (key: Key, values: [Value?])?) {
    
    if lhs.count != rhs.count {
        return (false, nil)
    }
    
    //keys are the same, we have to go through them one by one
    for (key, value) in lhs {
        if let rightValue = rhs[key] {
            if compareValues(lhs: value, rhs: rightValue) {
                //keeping your hopes up, still might be equal
                continue
            }
        }
        
        //returns the first offender of equality
        return (false, (key: key, [value, rhs[key]]))
    }
    return (true, nil)
}

public func isIndexDataEqualToIndexData(lhs: Index.IndexData, rhs: Index.IndexData) -> Bool {
    
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
    
    private func mergeIndexData(one: IndexData, two: IndexData) -> IndexData {
        
        return Dictionary.merge(one, two: two, merge: { (one, two) -> TokenIndexData in
            return self.mergeTokenIndexData(one, two: two)
        })
    }

    private func mergeTokenIndexData(one: TokenIndexData, two: TokenIndexData) -> TokenIndexData {
        
        return Dictionary.merge(one, two: two, merge: { (one, two) -> TokenRangeArray in
            return self.mergeTokenRangeArrays(one, two: two)
        })
    }
    
    private func mergeTokenRangeArrays(one: TokenRangeArray, two: TokenRangeArray) -> TokenRangeArray {
        
        //merge arrays
        //1. concat
        let both = one + two
        
        //2. sort
        let sorted = both.sort() { $0.startIndex <= $1.startIndex }
        
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
    
    static func merge(var one: [Key:Value], var two: [Key:Value], merge: (one: Value, two: Value) -> Value) -> [Key:Value] {
        
        //iterate over one, take the unique ones immediately, merge the ones that are also in two
        for (key, oneValue) in one {
            if let twoValue = two.removeValueForKey(key) {
                //two has a value for key
                //merge the values and add that
                one[key] = merge(one: oneValue, two: twoValue)
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






