//
//  InlineAST.swift
//  Apodimark
//


/// A reference to a node of an inline abstract syntax tree.
final class InlineAST <View: BidirectionalCollection> where
fileprivate final class InlineAST <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias NodeList = LinkedList<InlineNode<View>>

    let list: NodeList
    let index: NodeList.Index?
    let parent: InlineAST?

    init(list: NodeList, index: NodeList.Index?, parent: InlineAST?) {
        (self.list, self.index, self.parent) = (list, index, parent)
    }

    var parentNode: InlineNode<View>? {
        guard let parent = parent else { return nil }
        
        let idxAfterParentIdx: LinkedListIndex<InlineNode<View>>
        if let parentIndex = parent.index {
            idxAfterParentIdx = parent.list.index(after: parentIndex)
        } else {
            idxAfterParentIdx = parent.list.startIndex
        }
        return parent.list[idxAfterParentIdx]
    }

    func withIndex(_ idx: NodeList.Index?) -> InlineAST {
        return InlineAST(list: list, index: idx, parent: parent)
    }
}

extension InlineNode {
    fileprivate func contains(node: NonTextInlineNode<View>) -> Bool {
        switch self {
        case .text: return false
        case .nonText(let n): return n.contains(node: node)
        }
    }
}

extension NonTextInlineNode {
    fileprivate func contains(node: NonTextInlineNode) -> Bool {
        return start < node.start && end > node.end
    }
}


extension MarkdownParser {

    func makeAST(nonText: [NonTextInlineNode<View>], text: [TextInlineNode<View>]) -> LinkedList<InlineNode<View>> {
        
        let topList = LinkedList<InlineNode<View>>()
        
        var ast = InlineAST<View>(list: topList, index: nil, parent: nil)
        for node in nonText {
            ast = insertNode(node, in: ast)
        }
        
        ast = InlineAST(list: topList, index: nil, parent: nil)
        
        for node in text {
            switch node.kind {
            case .softbreak, .hardbreak:
                if case let nexti = ast.list.index(after: ast.index),
                   nexti < ast.list.endIndex,
                   case .nonText(let nextNode) = ast.list[nexti],
                   nextNode.start < node.start
                {
                    let i = nextNode.children.add(.text(node), after: nil)
                    ast = InlineAST(list: nextNode.children, index: i, parent: ast)
                } else {
                    let i = ast.list.add(.text(node), after: ast.index)
                    ast = ast.withIndex(i)
                }
                
            case .text:
                ast = insertText(node.start ..< node.end, view: view, in: ast)
            }
        }
        
        return topList
    }
    
    fileprivate func insertNode(_ node: NonTextInlineNode<View>, in ast: InlineAST<View>) -> InlineAST<View> {
        
        if let parentNode = ast.parentNode, !parentNode.contains(node: node) {
            return insertNode(node, in: ast.parent!)
        }
        
        var i = ast.index
        let nexti = ast.list.index(after: i)
        
        if nexti < ast.list.endIndex {
            if case let .nonText(n) = ast.list[nexti], n.contains(node: node) {
                return insertNode(node, in: InlineAST(list: n.children, index: nil, parent: ast.withIndex(i)))
            }
            i = nexti
        }
        
        _ = ast.list.add(.nonText(node), after: i)
        
        return InlineAST(list: ast.list, index: i, parent: ast.parent)
    }

    fileprivate func insertText(_ text: Range<View.Index>, view: View, in ast: InlineAST<View>) -> InlineAST<View> {

        if case let .nonText(parentNode)? = ast.parentNode {
            
            let parentContentRange = parentNode.contentRange(inView: view)
            
            if text.contains(parentContentRange.upperBound) {
            
                let leftText = text.clamped(to: parentContentRange)
                _ = insertText(leftText, view: view, in: ast)
                
                if parentNode.end < text.upperBound {
                    let rightText = parentNode.end ..< text.upperBound
                    return insertText(rightText, view: view, in: ast.parent!)
                } else {
                    return ast.parent!
                }
            }
        }
        
        var idx = text.lowerBound
        var i = ast.index
        var nexti = ast.list.index(after: i)
        
        while nexti < ast.list.endIndex && idx < text.upperBound {
            
            defer {
                i = nexti
                ast.list.formIndex(after: &nexti)
            }
            guard case let .nonText(nextNode) = ast.list[nexti] else { fatalError() }
            
            let (start, end) = (nextNode.start, nextNode.end)
            let (startC, endC): (View.Index, View.Index) = {
               let curContentRange = nextNode.contentRange(inView: view)
                return (curContentRange.lowerBound, curContentRange.upperBound)
            }()

            if idx < start {
                if start <= text.upperBound {
                    i = ast.list.add(.text(TextInlineNode(kind: .text, start: idx, end: start)), after: i)
                    // nexti invalidated -> recompute it
                    nexti = ast.list.index(after: i!)
                }
                // add text before node but text ends before start of node
                else {
                    let newIndex = ast.list.add(.text(TextInlineNode(kind: .text, start: idx, end: text.upperBound)), after: i)
                    return ast.withIndex(newIndex)
                }
            }
            idx = max(startC, idx)
            
            guard idx < endC else {
                idx = max(end, idx)
                continue
            }
            
            guard case let .nonText(newNextNode) = ast.list[nexti] else { fatalError() }
            
            // add text inside the node content
            if endC <= text.upperBound {
                _ = insertText(idx ..< endC, view: view,
                               in: InlineAST(list: newNextNode.children, index: nil, parent: ast.withIndex(i)))
                return insertText(end ..< text.upperBound, view: view, in: ast.withIndex(nexti))
            }
            // add text inside the node content but text ends before end of node content
            else {
                let rest = idx ..< text.upperBound
                if !rest.isEmpty {
                    return insertText(idx ..< text.upperBound, view: view,
                                      in: InlineAST(list: newNextNode.children, index: nil, parent: ast.withIndex(i)))
                } else {
                    return ast.withIndex(i)
                }
            }
        }
        if idx < text.upperBound {
            i = ast.list.add(.text(TextInlineNode(kind: .text, start: idx, end: text.upperBound)), after: i)
        }
        return ast.withIndex(i)
    }
}
