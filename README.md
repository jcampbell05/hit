# hit

[![Build Status](https://www.bitrise.io/app/df9203eed45bff4a.svg?token=_pWCzt8CMI8GZM5Lofq-Pw&branch=master)](https://www.bitrise.io/app/df9203eed45bff4a) [![CocoaPods Spec](https://img.shields.io/cocoapods/v/hit.svg)](https://cocoapods.org/pods/hit) ![Swift Version](https://img.shields.io/badge/Swift-Xcode7b5-orange.svg)

###### Lightweight full-text search written in Swift.

**Work In Progress.**

# features
- prefix search
- exact word-match search

# usage

Let's say you have a list of funny quotes from all yours friends and you suddenly remember that there's a gem mentioning a 'scar'. Instead of having to go through all your friends' quotes one by one until you find it, use `hit` instead! Just run your data to get an `Index` and then ask it to give you back *who*'s responsible for that quote and in *what context* it was said.

Let's look at our data

```swift
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
```

and we remember that someone said something ridiculously cheezy about `scars`, let's go for it and search for `scar`, hoping we'll get a hit.

```swift
//search for stuff!
let results = index.prefixSearch("scar")

//look at results
/*
*   -> 2 results : [
*                       "scary" -> [ "Sarah" : Range(34..<39) ],
*                       "scarred" -> [ "John" : Range(16..<23) ]
*                  ]
*/
```

Turns out we got two. One from Sarah about **Scar**y Movie:

```swift
Icecream always makes me think of Scary Movie. Get it? I scream?
                                  |---|
                                  34 39
```

and another one from John about, right that's the ridiculous one, well, read it yourself:

```swift
Who is not been scarred by love has not lived.
                |-----|
                16   23
```

Cool (?), our results actually tell us that he used the exact word **scar**red in the range of `16..<23`. That would be useful to know if we wanted to highlight the word itself.

# author
Honza Dvorsky
[honzadvorsky.com](honzadvorsky.com)
[@czechboy0](https://twitter.com/czechboy0)

