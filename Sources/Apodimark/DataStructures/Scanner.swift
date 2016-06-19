//
//  Scanner.swift
//  Apodimark
//

public struct Scanner <Data: BidirectionalCollection> {

    public let view: Data

    public private(set) var startIndex: Data.Index
    public private(set) var endIndex: Data.Index

    public init(view: Data, startIndex: Data.Index? = nil, endIndex: Data.Index? = nil) {
        let startIndex = startIndex ?? view.startIndex
        let endIndex = endIndex ?? view.endIndex

        precondition(view.startIndex <= startIndex && startIndex <= view.endIndex)
        precondition(view.startIndex <= endIndex && endIndex <= view.endIndex)

        self.view = view
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

extension Scanner {

    public var indices: Range<Data.Index> { return startIndex ..< endIndex }

    public mutating func pushBackStartIndexBy(n: Data.IndexDistance) throws {
        precondition(n >= 0)
        startIndex = view.index(self.startIndex, offsetBy: -n)
    }

    public mutating func readWhile(predicate: @noescape (Data.Iterator.Element?) throws -> Bool) rethrows {

        var curIndex = startIndex
        while try curIndex != endIndex && predicate(view[curIndex]) {
            curIndex = view.index(after: curIndex)
        }

        if curIndex == endIndex {
            _ = try predicate(nil)
        }

        startIndex = curIndex
    }

    public func peek() -> Data.Iterator.Element? {
        guard startIndex != endIndex else {
            return nil
        }
        return view[startIndex]
    }

    public mutating func pop() -> Data.Iterator.Element? {
        guard startIndex != endIndex else {
            return nil
        }
        defer {
            startIndex = view.index(after: startIndex)
        }
        return view[startIndex]
    }
}

extension Scanner {

    public func prefixUpTo(end: Data.Index) -> Scanner {
        precondition(startIndex <= end && end <= endIndex)
        return Scanner(view: view, startIndex: startIndex, endIndex: end)
    }

    public func suffixFrom(start: Data.Index) -> Scanner {
        precondition(startIndex <= start && start <= endIndex)
        return Scanner(view: view, startIndex: start, endIndex: endIndex)
    }
}
extension Scanner where Data.Iterator.Element: Equatable {

    public mutating func readUntil(_ x: Data.Iterator.Element) {
        var curIndex = startIndex
        while curIndex != endIndex && view[curIndex] != x {
            curIndex = view.index(after: curIndex)
        }
        startIndex = curIndex
    }

    public mutating func readWhile(_ element: Data.Iterator.Element) {
        var curIndex = startIndex
        while curIndex != endIndex && view[curIndex] == element {
            curIndex = view.index(after: curIndex)
        }
        startIndex = curIndex
    }

    public mutating func pop(_ element: Data.Iterator.Element) -> Bool {
        guard startIndex != endIndex && view[startIndex] == element else {
            return false
        }
        defer {
            startIndex = view.index(after: startIndex)
        }
        return true
    }

    public mutating func pop(ifNot element: Data.Iterator.Element) -> Data.Iterator.Element? {
        guard startIndex != endIndex && view[startIndex] != element else {
            return nil
        }

        defer {
            startIndex = view.index(after: startIndex)
        }
        return view[startIndex]
    }
}

extension Scanner: CustomStringConvertible {
    public var description: String {
        return "\(view[startIndex ..< endIndex])"
    }
}


