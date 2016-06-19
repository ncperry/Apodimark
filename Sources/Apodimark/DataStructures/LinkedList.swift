//
//  LinkedList.swift
//  Apodimark
//

private final class LinkedListNode<T> {
    var data: T
    var next: LinkedListNode?

    init(data: T, next: LinkedListNode?) { (self.data, self.next) = (data, next) }
}

public struct LinkedListIndex<T>: Comparable, CustomStringConvertible {

    private let position: Int
    private let _node: Unmanaged<LinkedListNode<T>>!

    private var node: LinkedListNode<T>! { return _node.takeUnretainedValue() }

    private init(position: Int, node: LinkedListNode<T>?) {
        self.position = position
        guard let node = node else { self._node = nil; return }
        self._node = .passUnretained(node)
    }

    public var description: String {
        return "ListIndex(\(position))"
    }
}

public func <  <T> (lhs: LinkedListIndex<T>, rhs: LinkedListIndex<T>) -> Bool { return lhs.position <  rhs.position }
public func <= <T> (lhs: LinkedListIndex<T>, rhs: LinkedListIndex<T>) -> Bool { return lhs.position <= rhs.position }
public func >  <T> (lhs: LinkedListIndex<T>, rhs: LinkedListIndex<T>) -> Bool { return lhs.position >  rhs.position }
public func >= <T> (lhs: LinkedListIndex<T>, rhs: LinkedListIndex<T>) -> Bool { return lhs.position >= rhs.position }
public func == <T> (lhs: LinkedListIndex<T>, rhs: LinkedListIndex<T>) -> Bool { return lhs.position == rhs.position }

public final class LinkedList<T> {

    public typealias Index = LinkedListIndex<T>

    private var head: LinkedListNode<T>!
    public private(set) var count: Int

    public init() { (self.head, self.count) = (nil, 0) }

    public func removeFirst() {
        head = head.next
        count -= 1
    }

    public func removeAll() {
        head = nil
        count = 0
    }

    public func removeAll(before idx: Index) {
        head = idx.node
        count -= idx.position
    }

    public func remove(nodeAfter idx: Index) {
        idx.node.next = idx.node.next?.next
        count -= 1
    }

    public func removeAll(fromAfter start: Index, toBefore end: Index) {
        start.node.next = end.node
        count -= (end.position - start.position) - 1
    }

    public func prepend(_ x: T) {
        head = LinkedListNode(data: x, next: head)
        count += 1
    }

    public func add(_ x: T, after idx: Index) {
        idx.node.next = LinkedListNode(data: x, next: idx.node.next)
        count += 1
    }

    public func add(_ x: T, after idx: Index?) -> Index { // bad name
        guard let idx = idx else {
            prepend(x)
            return startIndex
        }
        add(x, after: idx)
        return index(after: idx)
    }
}

public struct ListIterator<T>: IteratorProtocol {

    private var cur: LinkedListIndex<T>
    private let list: LinkedList<T>

    private init(_ list: LinkedList<T>) {
        self.cur = list.startIndex
        self.list = list
    }

    public mutating func next() -> T? {
        guard cur.position < list.endIndex.position else { return nil }
        defer { cur = LinkedListIndex(position: cur.position + 1, node: cur.node.next) }
        return cur.node.data
    }
}

extension LinkedList: Sequence {

    public func makeIterator() -> ListIterator<T> {
        return ListIterator(self)
    }
}

public struct ListIndicesIterator<T>: IteratorProtocol {

    public typealias Element = LinkedListIndex<T>

    private var cur: Element
    private let indices: ListIndices<T>

    init(_ indices: ListIndices<T>) {
        self.indices = indices
        self.cur = indices.startIndex
    }

    public mutating func next() -> Element? {
        guard cur.position < indices.endIndex.position else { return nil }
        defer { cur = LinkedListIndex(position: cur.position + 1, node: cur.node.next) }
        return cur
    }
}

public struct ListIndices<T>: Collection {
    public typealias Element = LinkedListIndex<T>
    public typealias Index = LinkedListIndex<T>
    public typealias Indices = ListIndices<T>
    public typealias Iterator = ListIndicesIterator<T>

    public let startIndex: LinkedListIndex<T>
    public let endIndex: LinkedListIndex<T>

    public var indices: Indices { return self }

    public subscript (idx: Index) -> Element {
        get { return idx }
    }

    public func index(after idx: Index) -> Index {
        return LinkedListIndex(position: idx.position + 1, node: idx.node.next)
    }
    public func makeIterator() -> Iterator {
        return ListIndicesIterator(indices)
    }
}

extension LinkedList: MutableCollection {
    public typealias Element = T
    public typealias Indices = ListIndices<T>

    public subscript (idx: Index) -> Element {
        get { return idx.node.data }
        set { idx.node.data = newValue }
    }

    public var startIndex: Index {
        return LinkedListIndex(position: 0, node: head)
    }

    public var endIndex: Index {
        return LinkedListIndex(position: count, node: nil)
    }

    public var indices: Indices {
        return ListIndices(startIndex: startIndex, endIndex: endIndex)
    }

    public func index(after idx: Index) -> Index {
        return LinkedListIndex(position: idx.position + 1, node: idx.node.next)
    }
}

extension LinkedList: ArrayLiteralConvertible {
    public convenience init(arrayLiteral array: T...) {
        self.init()
        array.reversed().forEach(self.prepend)
    }
}

extension LinkedList: CustomStringConvertible {
    public var description: String {
        var s = "List["
        for e in self { s += "\(e), " }
        s += "]"
        return s
    }
}

