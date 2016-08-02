//
//  LinkedList.swift
//  Apodimark
//

/// A node in a LinkedList
private final class LinkedListNode<T> {
    var data: T
    var next: LinkedListNode?

    init(data: T, next: LinkedListNode?) { (self.data, self.next) = (data, next) }
}

/// The index of a node in a LinkedList
public struct LinkedListIndex<T>: Comparable, CustomStringConvertible {

    /// Position of the index relative to the head of the list
    private let position: Int

    /// The node at `list[self]`
    private weak var node: LinkedListNode<T>! // should be unowned but can’t because of compiler bug

    private init(position: Int, node: LinkedListNode<T>?) {
        (self.position, self.node) = (position, node)
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

/**
 A singly linked list conforming to `MutableCollection`.
 
 Instances of this type have reference semantics.

 - Note:
 Once the index of an element is known, accessing the element can be done in constant
 time by using a subscript operation.

 ```
 // Θ(n) time complexity
 let index = list.index(list.startIndex, offsetBy: n)

 // Θ(1)
 let element = list[index]
 ```
*/
public final class LinkedList<T> {

    public typealias Index = LinkedListIndex<T>

    /// The head of the list.
    private var head: LinkedListNode<T>!

    public private(set) var count: Int

    /// Creates an empty list
    public init() {
        (self.head, self.count) = (nil, 0)
    }

    /// Removes the first element of the list.
    ///
    /// - Important: Invalidates every index of the list
    /// - Complexity: `Θ(1)`
    public func removeFirst() {
        head = head.next
        count -= 1
    }

    /// Removes all the elements in the list
    /// - Complexity: `Θ(count)`
    public func removeAll() {
        head = nil
        count = 0
    }

    /**
     Removes every element of the list before `idx`.

     ```
     let list = [1, 2, 3]
     let index = list.index(after: list.startIndex)
     list.removeAll(before: index)
     // list is now [2, 3]
     ```
     
     - Important: Invalidates every index of the list
     - Complexity: `Θ(n)` where `n` is the number of deleted elements
     - parameter idx: successor of the last element to be deleted
    */
    public func removeAll(before idx: Index) {
        head = idx.node
        count -= idx.position
    }

    /**
     Removes the element whose index is the successor of `idx`.

         let list = [1, 2, 3]
         list.remove(nodeAfter: list.startIndex)
         // list is now [1, 3]
     
     - Important: Invalidates every index after `idx`
     - Complexity: `Θ(1)`
     - parameter idx: predecessor of the element that will be deleted
     */
    public func removeElement(after idx: Index) {
        idx.node.next = idx.node.next?.next
        count -= 1
    }

    /**
     Removes every element strictly between `start` and `end`
    
     ```
     let list = [1, 2, 3, 4]
     
     let start = list.startIndex
     let end = list.index(start, offsetBy: 3)
     // end is index of 4
     
     list.removeAll(fromAfter: start, toBefore: end)
     // list is now [1, 4]
     ```

     - Important: Invalidates every index after `start`
     - precondition: `start` < `end`
     - Complexity: `Θ(n)` where `n` is the number of deleted elements
     - parameter start: predecessor of the first element to be deleted
     - parameter end: successor of the last element to be deleted
     */
    public func removeAll(fromAfter start: Index, toBefore end: Index) {
        precondition(start.position < end.position)
        start.node.next = end.node
        count -= (end.position - start.position) - 1
    }

    /**
     Prepends an element to the list
     
     - Important: Invalidates every index of the list
     - Complexity: `Θ(1)`
     - parameter x: the element to add
     */
    public func prepend(_ x: T) {
        head = LinkedListNode(data: x, next: head)
        count += 1
    }

    /**
     Add an element after `idx`
     
     ```
     let list = [1, 3]
     list.add(2, after: list.startIndex)
     // list is now [1, 2, 3]
     ```

     - Complexity: `Θ(1)`
     - Parameter x: the element to add
     - Parameter idx: predecessor of the new element
     */
    public func add(_ x: T, after idx: Index) {
        idx.node.next = LinkedListNode(data: x, next: idx.node.next)
        count += 1
    }

    /**
     Add an element after `idx`, or prepend it to the list if `idx` is nil

     ```
     let list = [1, 3]
     list.add(2, after: list.startIndex)
     // list is now [1, 2, 3]

     list.add(0, after: nil)
     // list is now [0, 1, 2, 3]
     ```

     - Complexity: `Θ(1)`
     - Parameter x: the element to add
     - Parameter idx: predecessor of the index of the new element, or nil if the new element should be the head of the list
     */
    public func add(_ x: T, after idx: Index?) -> Index { // bad name
        guard let idx = idx else {
            prepend(x)
            return startIndex
        }
        add(x, after: idx)
        return index(after: idx)
    }
}

extension LinkedList: Sequence {
    public func makeIterator() -> LinkedListIterator<T> {
        return LinkedListIterator(self)
    }
}

extension LinkedList: MutableCollection {
    public typealias Element = T
    public typealias Indices = LinkedListIndices<T>

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
        return LinkedListIndices(startIndex: startIndex, endIndex: endIndex)
    }

    public func index(after idx: Index) -> Index {
        return LinkedListIndex(position: idx.position + 1, node: idx.node.next)
    }
}

extension LinkedList: ExpressibleByArrayLiteral {
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

public struct LinkedListIterator<T>: IteratorProtocol {

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

public struct LinkedListIndicesIterator<T>: IteratorProtocol {

    public typealias Element = LinkedListIndex<T>

    private var cur: Element
    private let indices: LinkedListIndices<T>

    init(_ indices: LinkedListIndices<T>) {
        self.indices = indices
        self.cur = indices.startIndex
    }

    public mutating func next() -> Element? {
        guard cur.position < indices.endIndex.position else { return nil }
        defer { cur = LinkedListIndex(position: cur.position + 1, node: cur.node.next) }
        return cur
    }
}

public struct LinkedListIndices<T>: Collection {
    public typealias Element = LinkedListIndex<T>
    public typealias Index = LinkedListIndex<T>
    public typealias Indices = LinkedListIndices<T>
    public typealias Iterator = LinkedListIndicesIterator<T>

    public let startIndex: Index
    public let endIndex: Index

    public var indices: Indices { return self }

    public subscript (idx: Index) -> Element {
        get { return idx }
    }

    public func index(after idx: Index) -> Index {
        return LinkedListIndex(position: idx.position + 1, node: idx.node.next)
    }
    public func makeIterator() -> Iterator {
        return LinkedListIndicesIterator(indices)
    }
}


