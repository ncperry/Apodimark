
// An append-depth-first-only tree

struct DepthLevel {
    fileprivate var _level: Int
    
    static var root: DepthLevel {
        return .init(0)
    }
    
    private init(_ level: Int) {
        self._level = level
    }
    
    func incremented() -> DepthLevel {
        return .init(_level+1)
    }
    
    func decremented() -> DepthLevel {
        return .init(_level-1)
    }
}

struct TreeNode <T> {
    let data: T
    var end: Int
    
    init(data: T, end: Array<T>.Index) {
        (self.data, self.end) = (data, end)
    }
}

final class Tree <T> {
    
    var buffer: Array<TreeNode<T>>
    var lastStrand: [Array<T>.Index]
    
    var lastLeaf: T {
        return buffer[buffer.endIndex-1].data
    }
    
    init() {
        (self.buffer, self.lastStrand) = ([], [])
    }
    
    func last(depthLevel: DepthLevel) -> T? {
        guard depthLevel._level >= 0 && depthLevel._level < lastStrand.count else { return nil }
        return buffer[lastStrand[depthLevel._level]].data
    }
    
    func append(_ data: T, depthLevel level: DepthLevel = .root) {
        buffer.append(TreeNode(data: data, end: buffer.endIndex-1))
        repairStructure(addedStrandLength: 1, level: level)
    }

    func repairStructure(addedStrandLength: Int, level: DepthLevel) {
        lastStrand.removeSubrange(level._level ..< lastStrand.endIndex)
        lastStrand.append(contentsOf: (buffer.endIndex - addedStrandLength) ..< buffer.endIndex)
        
        for i in lastStrand {
            buffer[i].end += addedStrandLength
        }
    }
    
    func append <S: Sequence> (strand: S, depthLevel level: DepthLevel = .root) where
        S.Iterator.Element == T
    {
        let initialCount = buffer.count
        let c = strand.lazy.map { TreeNode(data: $0, end: initialCount-1) }
        buffer.append(contentsOf: c)
        let endCount = buffer.count
        let strandLength = initialCount.distance(to: endCount)
        repairStructure(addedStrandLength: strandLength, level: level)
    }
    
    func makeIterator() -> TreeIterator<T> {
        return TreeIterator(self)
    }
}

enum Result {
    case success
    case failure
}

struct TreeIterator <T>: IteratorProtocol, Sequence {
    
    let tree: Tree<T>
    let endIndex: Array<T>.Index
    var index: Array<T>.Index
    
    fileprivate init(_ tree: Tree<T>) {
        (self.tree, self.endIndex) = (tree, tree.buffer.endIndex)
        self.index = 0
    }
    
    fileprivate init(_ tree: Tree<T>, startIndex: Array<T>.Index, endIndex: Array<T>.Index) {
        (self.tree, self.endIndex) = (tree, endIndex)
        self.index = startIndex
    }
    
    mutating func next() -> (T, TreeIterator?)? {
        
        guard index < endIndex else {
            return nil
        }
        
        let end = tree.buffer[index].end
        
        defer {
            index = end+1
        }
        
        return (tree.buffer[index].data, diving())
    }
    
    private func diving() -> TreeIterator<T>? {
        
        guard index < tree.buffer.endIndex else {
            return nil
        }
        
        let end = tree.buffer[index].end
        
        guard index.distance(to: end) > 0 else {
            return nil
        }
        
        return TreeIterator(tree, startIndex: index+1, endIndex: end+1)
    }
    
    func makeIterator() -> TreeIterator<T> {
        return self
    }
}
