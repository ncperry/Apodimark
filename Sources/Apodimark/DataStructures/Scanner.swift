//
//  Scanner.swift
//  Apodimark
//

/**
 A `Scanner` provides a convenient way to read data from a sub-collection.
 
 It stores the original collection, as well as an arbitrary `startIndex` and `endIndex`.

 For example, this is a scanner that can read the elements in the array from 2 to 8 (included):
 ```
 [9, 2, 4, 3, 0, 8, 9, 7, 2, 1]
    |_____________|
       SCANNER
 ```
 It contains the array, as well as a `startIndex` pointing to 2, and an `endIndex` pointing to 9.

 As elements are read from the scanner, its `startIndex` advances.
 ```
 scanner.popWhile { $0 != 3 }
 
 [1, 2, 4, 3, 0, 8, 9, 7, 2, 1]
          |_______|
 ```
 
 `Scanner`s are value types (if they are reading from a collection with value semantics), 
 and they don’t mutate the elements in the original collection.
 */
struct Scanner <Data: BidirectionalCollection> {

    /// The collection from which to read the elements
    let data: Data

    /// Index of the first element accessible to the scanner
    var startIndex: Data.Index
    /// Successor of the index of the last element accessible to the scanner
    var endIndex: Data.Index

    /// Initialize a scanner reading from `data`, from `startIndex` to `endIndex`.
    /// - parameter startIndex: index of first element accessible to the new scanner
    /// or `nil` to use `data.startIndex`
    /// - parameter endIndex: successor of the index of last element accessible to the new scanner
    /// or `nil` to use `data.endIndex`
    ///
    /// - precondition:
    ///   * `startIndex` and `endIndex` are between `data.startIndex` and `data.endIndex` (included)
    ///   * `startIndex <= endIndex`
    init(data: Data, startIndex: Data.Index? = nil, endIndex: Data.Index? = nil) {
        let startIndex = startIndex ?? data.startIndex
        let endIndex = endIndex ?? data.endIndex

        precondition(data.startIndex <= startIndex && startIndex <= data.endIndex)
        precondition(data.startIndex <= endIndex && endIndex <= data.endIndex)
        precondition(startIndex <= endIndex)

        self.data = data
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

enum PopOrStop {
    case stop
    case pop
}

extension Scanner {

    /// Convenience property for `startIndex ..< endIndex`
    var indices: Range<Data.Index> { return startIndex ..< endIndex }

    /**
     Read elements from the scanner while `predicate(element) == true`.
     Does not pop the element for which `predicate` is `false`.
     
     If `predicate` throws an error, then the scanner is not modified.
     
     If every element of the scanner is read, then `predicate(nil)` is
     called, giving the opportunity to throw an error to cancel the operation.
     */
    mutating func popWhile(_ predicate: (Data.Iterator.Element?) throws -> PopOrStop) rethrows {

        var curIndex = startIndex
        while curIndex != endIndex, case .pop = try predicate(data[curIndex]) {
            curIndex = data.index(after: curIndex)
        }

        if curIndex == endIndex {
            _ = try predicate(nil)
        }

        startIndex = curIndex
    }

    /// Look at the first element of the scanner, without advancing `startIndex`.
    func peek() -> Data.Iterator.Element? {
        guard startIndex != endIndex else {
            return nil
        }
        return data[startIndex]
    }

    /// Take the first element of the scanner and return it.
    mutating func pop() -> Data.Iterator.Element? {
        guard startIndex != endIndex else {
            return nil
        }
        defer {
            startIndex = data.index(after: startIndex)
        }
        return data[startIndex]
    }
}

extension Scanner where Data.Iterator.Element: Equatable {

    /// Pop elements from the scanner until reaching an element equal to `x`.
    /// The element equal to `x` won’t be popped.
    mutating func popUntil(_ x: Data.Iterator.Element) {
        var curIndex = startIndex
        while curIndex != endIndex && data[curIndex] != x {
            curIndex = data.index(after: curIndex)
        }
        startIndex = curIndex
    }

    /// Pop elements from the scanner while they are equal to `x`.
    /// The element not equal to `x` won’t be popped.
    mutating func popWhile(_ x: Data.Iterator.Element) {
        var curIndex = startIndex
        while curIndex != endIndex && data[curIndex] == x {
            curIndex = data.index(after: curIndex)
        }
        startIndex = curIndex
    }

    /// Pop an element from the scanner if it is equal to `x`.
    /// - returns: `true` if an element was popped, `false` otherwise
    mutating func pop(_ x: Data.Iterator.Element) -> Bool {
        guard startIndex != endIndex && data[startIndex] == x else {
            return false
        }
        defer {
            startIndex = data.index(after: startIndex)
        }
        return true
    }

    /// Pop an element from the scanner if it is not equal to `x`.
    /// - returns: the element that was popped, `nil` otherwise
    mutating func pop(ifNot x: Data.Iterator.Element) -> Data.Iterator.Element? {
        guard startIndex != endIndex && data[startIndex] != x else {
            return nil
        }

        defer {
            startIndex = data.index(after: startIndex)
        }
        return data[startIndex]
    }
}


