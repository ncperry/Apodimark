//
//  LinkedList.swift
//  Apodimark
//

/// A node in a LinkedList
fileprivate final class LinkedListNode<T> {
    var data: T
    var next: LinkedListNode?

    init(data: T, next: LinkedListNode?) { (self.data, self.next) = (data, next) }
}

/// The index of a node in a LinkedList
struct LinkedListIndex<T>: Comparable, CustomStringConvertible {

    /// Position of the index relative to the head of the list
    fileprivate let position: Int

    /// The node at `list[self]`
    fileprivate weak var node: LinkedListNode<T>! // should be unowned but can’t because of compiler bug

    fileprivate init(position: Int, node: LinkedListNode<T>?) {
        (self.position, self.node) = (position, node)
    }

    var description: String {
        return "ListIndex(\(position))"
    }
}

func <  <T> (lhs: LinkedListIndex<T>, rhs: LinkedListIndex<T>) -> Bool { return lhs.position <  rhs.position }
func <= <T> (lhs: LinkedListIndex<T>, rhs: LinkedListIndex<T>) -> Bool { return lhs.position <= rhs.position }
func >  <T> (lhs: LinkedListIndex<T>, rhs: LinkedListIndex<T>) -> Bool { return lhs.position >  rhs.position }
func >= <T> (lhs: LinkedListIndex<T>, rhs: LinkedListIndex<T>) -> Bool { return lhs.position >= rhs.position }
func == <T> (lhs: LinkedListIndex<T>, rhs: LinkedListIndex<T>) -> Bool { return lhs.position == rhs.position }

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
final class LinkedList<T> {

    typealias Index = LinkedListIndex<T>

    /// The head of the list.
    fileprivate var head: LinkedListNode<T>!

    fileprivate(set) var count: Int

    /// Creates an empty list
    init() {
        (self.head, self.count) = (nil, 0)
    }

    /// Removes the first element of the list.
    ///
    /// - Important: Invalidates every index of the list
    /// - Complexity: `Θ(1)`
    func removeFirst() {
        head = head.next
        count -= 1
    }

    /// Removes all the elements in the list
    /// - Complexity: `Θ(count)`
    func removeAll() {
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
    func removeAll(before idx: Index) {
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
    func removeElement(after idx: Index) {
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
    func removeAll(fromAfter start: Index, toBefore end: Index) {
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
    func prepend(_ x: T) {
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
    func add(_ x: T, after idx: Index) {
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
    func add(_ x: T, after idx: Index?) -> Index { // bad name
        guard let idx = idx else {
            prepend(x)
            return startIndex
        }
        add(x, after: idx)
        return index(after: idx)
    }
}

extension LinkedList: Sequence {
    func makeIterator() -> LinkedListIterator<T> {
        return LinkedListIterator(self)
    }
}

extension LinkedList: MutableCollection {
    typealias Element = T
    typealias Indices = LinkedListIndices<T>

    subscript (idx: Index) -> Element {
        get { return idx.node.data }
        set { idx.node.data = newValue }
    }

    var startIndex: Index {
        return LinkedListIndex(position: 0, node: head)
    }

    var endIndex: Index {
        return LinkedListIndex(position: count, node: nil)
    }

    var indices: Indices {
        return LinkedListIndices(startIndex: startIndex, endIndex: endIndex)
    }

    func index(after idx: Index) -> Index {
        return LinkedListIndex(position: idx.position + 1, node: idx.node.next)
    }
}

extension LinkedList: ExpressibleByArrayLiteral {
    convenience init(arrayLiteral array: T...) {
        self.init()
        array.reversed().forEach(self.prepend)
    }
}

extension LinkedList: CustomStringConvertible {
    var description: String {
        var s = "List["
        for e in self { s += "\(e), " }
        s += "]"
        return s
    }
}

struct LinkedListIterator<T>: IteratorProtocol {

    fileprivate var cur: LinkedListIndex<T>
    fileprivate let list: LinkedList<T>

    fileprivate init(_ list: LinkedList<T>) {
        self.cur = list.startIndex
        self.list = list
    }

    mutating func next() -> T? {
        guard cur.position < list.endIndex.position else { return nil }
        defer { cur = LinkedListIndex(position: cur.position + 1, node: cur.node.next) }
        return cur.node.data
    }
}

struct LinkedListIndicesIterator<T>: IteratorProtocol {

    typealias Element = LinkedListIndex<T>

    fileprivate var cur: Element
    fileprivate let indices: LinkedListIndices<T>

    init(_ indices: LinkedListIndices<T>) {
        self.indices = indices
        self.cur = indices.startIndex
    }

    mutating func next() -> Element? {
        guard cur.position < indices.endIndex.position else { return nil }
        defer { cur = LinkedListIndex(position: cur.position + 1, node: cur.node.next) }
        return cur
    }
}

struct LinkedListIndices<T>: Collection {
    typealias Element = LinkedListIndex<T>
    typealias Index = LinkedListIndex<T>
    typealias Indices = LinkedListIndices<T>
    typealias Iterator = LinkedListIndicesIterator<T>

    let startIndex: Index
    let endIndex: Index

    var indices: Indices { return self }

    subscript (idx: Index) -> Element {
        get { return idx }
    }

    func index(after idx: Index) -> Index {
        return LinkedListIndex(position: idx.position + 1, node: idx.node.next)
    }
    func makeIterator() -> Iterator {
        return LinkedListIndicesIterator(indices)
    }
}


