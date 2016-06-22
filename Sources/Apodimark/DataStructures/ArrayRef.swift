//
//  ArrayRef.swift
//  Apodimark
//


/// An array slice with reference semantics
public final class ArrayRefSlice <T>: MutableCollection, RandomAccessCollection, RangeReplaceableCollection {

    public typealias SubSequence = ArrayRefSlice<T>

    private let _base: ArrayRef<T>
    private var _slice: MutableRangeReplaceableRandomAccessSlice<ArrayRef<T>>

    public init() {
        self._base = []
        self._slice = MutableRangeReplaceableRandomAccessSlice<ArrayRef<T>>()
    }
    public init(base: ArrayRef<T>, bounds: Range<Index>) {
        self._base = base
        self._slice = MutableRangeReplaceableRandomAccessSlice(base: base, bounds: bounds)
    }

    public typealias Index = MutableRangeReplaceableRandomAccessSlice<ArrayRef<T>>.Index
    public typealias IndexDistance = MutableRangeReplaceableRandomAccessSlice<ArrayRef<T>>.IndexDistance
    public typealias Indices = MutableRangeReplaceableRandomAccessSlice<ArrayRef<T>>.Indices

    public var startIndex: Index {
        return _slice.startIndex
    }
    public var endIndex: Index {
        return _slice.endIndex
    }
    public var indices: Indices {
        return _slice.indices
    }
    public var count: Index {
        return _slice.count
    }

    public func index(after idx: Index) -> Index {
        return _slice.index(after: idx)
    }
    public func index(before idx: Index) -> Index {
        return _slice.index(before: idx)
    }
    public func index(_ i: Index, offesetBy dist: IndexDistance) -> Index {
        return _slice.index(i, offsetBy: dist)
    }
    public func index(_ i: Index, offsetBy dist: IndexDistance, limitedBy limit: Index) -> Index? {
        return _slice.index(i, offsetBy: dist, limitedBy: limit)
    }

    public func append(_ newElement: T) {
        _slice.append(newElement)
    }
    public func append <S: Sequence where S.Iterator.Element == T> (contentsOf newElements: S) {
        _slice.append(contentsOf: newElements)
    }
    public func append <C: Collection where C.Iterator.Element == T> (contentsOf newElements: C) {
        _slice.append(contentsOf: newElements)
    }

    public func insert(_ newElement: T, at idx: Index) {
        _slice.insert(newElement, at: idx)
    }
    public func insert <C: Collection where C.Iterator.Element == T> (contentsOf newElements: C, at idx: Int) {
        _slice.insert(contentsOf: newElements, at: idx)
    }

    public func remove(at idx: Index) -> T {
        return _slice.remove(at: idx)
    }
    public func removeAll() {
        _slice.removeAll()
    }

    public func removeFirst(n: Index = 1) {
        _slice.removeFirst(n)
    }
    public func removeLast(n: Index = 1) {
        _slice.removeLast(n)
    }

    public func removeSubrange(_ bounds: Range<Index>) {
        _slice.removeSubrange(bounds)
    }
    public func removeSubrange(_ bounds: CountableRange<Index>) {
        _slice.removeSubrange(bounds)
    }
    public func removeSubrange(_ bounds: ClosedRange<Index>) {
        _slice.removeSubrange(bounds)
    }
    public func removeSubrange(_ bounds: CountableClosedRange<Index>) {
        _slice.removeSubrange(bounds)
    }

    public func replaceSubrange <C: Collection where C.Iterator.Element == T> (_ bounds: Range<Index>, with collection: C) {
        _slice.replaceSubrange(bounds, with: collection)
    }
    public func replaceSubrange <C: Collection where C.Iterator.Element == T> (_ bounds: CountableRange<Index>, with collection: C) {
        _slice.replaceSubrange(bounds, with: collection)
    }
    public func replaceSubrange <C: Collection where C.Iterator.Element == T> (_ bounds: ClosedRange<Index>, with collection: C) {
        _slice.replaceSubrange(bounds, with: collection)
    }
    public func replaceSubrange <C: Collection where C.Iterator.Element == T> (_ bounds: CountableClosedRange<Index>, with collection: C) {
        _slice.replaceSubrange(bounds, with: collection)
    }

    public subscript(idx: Index) -> T {
        get { return _slice[idx] }
        set { _slice[idx] = newValue }
    }
    public subscript(idcs: Range<Index>) -> SubSequence {
        get { return ArrayRefSlice<T>(base: _base, bounds: idcs) }
        set { self[idcs].replaceSubrange(idcs, with: newValue) } // this might be wrong
    }

    public func makeIterator() -> IndexingIterator<MutableRangeReplaceableRandomAccessSlice<ArrayRef<T>>> {
        return _slice.makeIterator()
    }
}
extension ArrayRefSlice: CustomStringConvertible {
    public var description: String {
        return "ArrayRefSlice(\(_slice))"
    }
}

/// An array with reference semantics
public final class ArrayRef <T>: MutableCollection, RandomAccessCollection, RangeReplaceableCollection, ArrayLiteralConvertible {

    public typealias Index = Int
    public typealias IndexDistance = Int
    public typealias Indices = CountableRange<Index>
    public typealias SubSequence = ArrayRefSlice<T>

    private var _array: [T]

    public init() {
        self._array = []
    }
    public init(arrayLiteral array: T...) {
        self._array = array
    }

    public var startIndex: Index {
        return _array.startIndex
    }
    public var endIndex: Index {
        return _array.endIndex
    }
    public var indices: Indices {
        return _array.indices
    }
    public var count: Index {
        return _array.count
    }

    public func index(after idx: Index) -> Index {
        return _array.index(after: idx)
    }
    public func index(before idx: Index) -> Index {
        return _array.index(before: idx)
    }
    public func index(_ i: Index, offsetBy dist: IndexDistance) -> Index {
        return _array.index(i, offsetBy: dist)
    }
    public func index(_ i: Index, offsetBy dist: IndexDistance, limitedBy limit: Index) -> Index? {
        return _array.index(i, offsetBy: dist, limitedBy: limit)
    }

    public func append(_ newElement: T) {
        _array.append(newElement)
    }
    public func append <S: Sequence where S.Iterator.Element == T> (contentsOf newElements: S) {
        _array.append(contentsOf: newElements)
    }
    public func append <C: Collection where C.Iterator.Element == T> (contentsOf newElements: C) {
        _array.append(contentsOf: newElements)
    }

    public func insert(_ newElement: T, at idx: Index) {
        _array.insert(newElement, at: idx)
    }
    public func insert <C: Collection where C.Iterator.Element == T> (contentsOf newElements: C, at idx: Int) {
        _array.insert(contentsOf: newElements, at: idx)
    }

    public func remove(at idx: Index) -> T {
        return _array.remove(at: idx)
    }
    public func removeAll() {
        _array.removeAll()
    }

    public func removeFirst(n: Index = 1) {
        _array.removeFirst(n)
    }
    public func removeLast(n: Index = 1) {
        _array.removeLast(n)
    }

    public func removeSubrange(_ bounds: Range<Index>) {
        _array.removeSubrange(bounds)
    }
    public func removeSubrange(_ bounds: CountableRange<Index>) {
        _array.removeSubrange(bounds)
    }
    public func removeSubrange(_ bounds: ClosedRange<Index>) {
        _array.removeSubrange(bounds)
    }
    public func removeSubrange(_ bounds: CountableClosedRange<Index>) {
        _array.removeSubrange(bounds)
    }

    public func replaceSubrange <C: Collection where C.Iterator.Element == T> (_ bounds: Range<Index>, with collection: C) {
        _array.replaceSubrange(bounds, with: collection)
    }
    public func replaceSubrange <C: Collection where C.Iterator.Element == T> (_ bounds: CountableRange<Index>, with collection: C) {
        _array.replaceSubrange(bounds, with: collection)
    }
    public func replaceSubrange <C: Collection where C.Iterator.Element == T> (_ bounds: ClosedRange<Index>, with collection: C) {
        _array.replaceSubrange(bounds, with: collection)
    }
    public func replaceSubrange <C: Collection where C.Iterator.Element == T> (_ bounds: CountableClosedRange<Index>, with collection: C) {
        _array.replaceSubrange(bounds, with: collection)
    }

    public subscript(idx: Index) -> T {
        get { return _array[idx] }
        set { _array[idx] = newValue }
    }
    public subscript(idcs: Range<Index>) -> SubSequence {
        get { return SubSequence(base: self, bounds: idcs) }
        set { _array.replaceSubrange(idcs, with: newValue) } // this might be wrong
    }


    public func makeIterator() -> IndexingIterator<[T]> {
        return _array.makeIterator()
    }
}

extension ArrayRef: CustomStringConvertible {
    public var description: String {
        return _array.description
    }
}
