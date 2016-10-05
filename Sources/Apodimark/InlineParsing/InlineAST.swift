//
//  InlineAST.swift
//  Apodimark
//

// I’m so sorry for the code in this file...

/// A reference to a node of an inline abstract syntax tree.
final class InlineAST <View: BidirectionalCollection> where
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
    fileprivate func contains(node: InlineNode) -> Bool {
        return start < node.start && end > node.end
    }
}


extension MarkdownParser {
    
    fileprivate func insertNode(_ node: InlineNode<View>, in ast: InlineAST<View>) -> InlineAST<View> {

        // nodes are sorted before calling this function and ast is either basic or created with this function
        
        if let parentNode = ast.parentNode, !parentNode.contains(node: node) {
            return insertNode(node, in: ast.parent!)
        }

        let list = ast.list
        var prevI = ast.index
        let i = prevI == nil ? list.startIndex : list.index(after: prevI!)
        
        if i < list.endIndex {
            if list[i].contains(node: node) {
                return insertNode(node, in: InlineAST(list: list[i].children, index: nil, parent: ast.withIndex(prevI)))
            }
            prevI = i
        }
        
        _ = list.add(node, after: prevI)

        return InlineAST(list: list, index: prevI, parent: ast.parent)
    }

    func makeAST(with nodes: [InlineNode<View>]) -> LinkedList<InlineNode<View>> {

        var ast = InlineAST<View>(list: [], index: nil, parent: nil)
        let topList = ast.list

        for node in nodes {
            if case .text = node.kind {
                continue
            } else {
                ast = insertNode(node, in: ast)
            }
        }

        ast = InlineAST(list: topList, index: nil, parent: nil)

        for node in nodes {
            if case .text = node.kind {
                ast = insertText(node.contentRange(inView: view), view: view, in: ast)
            } else {
                continue
            }
        }

        return topList
    }


    fileprivate func insertText(_ text: Range<View.Index>, view: View, in ast: InlineAST<View>) -> InlineAST<View> {

        // text might span several nodes at different levels
        /* e.g.
         This *is _Bill_*.
         
         AST BEFORE:
         emph(5...16, 6...15)
           |
         emph(9...15, 10...14)
         
         AST AFTER ADDING TEXT 0...16:
         text(0...4) - emph - text(16...16)
                        |
                       text(6...8) - emph - text(15..<15)
                                      |
                                     text(10...13)
         
         
         EDGE CASE:
         *hello\! world* bye
         
         AST BEFORE;
         emph(0...14, 1...13)
         
         AST AFTER ADDING TEXT 0...5:
         emph
          |
         text(1...4)
         
         Return ast pointing to text(1...4)
         
         AST AFTER ADDING TEXT 6...18:
         emph - text(15...18)
          |
         text(1...4) - text(6...13)
         
         */
        
        var idx = text.lowerBound

        var i = ast.index
        var nexti = i == nil ? ast.list.startIndex : ast.list.index(after: i!)
        
        if let parentNode = ast.parentNode {

            let parentContentRange = parentNode.contentRange(inView: view)

            if text.contains(parentContentRange.upperBound) {
                let leftText = text.clamped(to: parentContentRange)
                _ = insertText(leftText, view: view, in: ast)
                
                if parentNode.end < text.upperBound {
                    let rightText = parentNode.end ..< text.upperBound
                    // ast.parent exists if ast.parentNode exists
                    return insertText(rightText, view: view, in: ast.parent!)
                } else {
                    // ast.parent exists if ast.parentNode exists
                    return ast.parent!
                }
            }
        }

        while nexti < ast.list.endIndex && idx < text.upperBound {

            defer {
                i = nexti
                ast.list.formIndex(after: &nexti)
            }

            let (start, end) = (ast.list[nexti].start, ast.list[nexti].end)
            
            let (startC, endC): (View.Index, View.Index) = {
                let curContentRange = ast.list[nexti].contentRange(inView: view)
                return (curContentRange.lowerBound, curContentRange.upperBound)
            }()
            
            if idx < start {
                // add text before node
                if start <= text.upperBound {
                    i = ast.list.add(InlineNode(kind: .text, start: idx, end: start), after: i)
                    // nexti invalidated -> recompute it
                    nexti = ast.list.index(after: i!)
                }
                // add text before node but text ends before start of node
                else {
                    let newIndex = ast.list.add(InlineNode(kind: .text, start: idx, end: text.upperBound), after: i)

                    return ast.withIndex(newIndex)
                }
            }
            idx = max(startC, idx)
            
            guard idx < endC else {
                idx = max(end, idx)
                continue
            }
            
            // add text inside the node content
            if endC <= text.upperBound {
                _ = insertText(idx ..< endC, view: view,
                               in: InlineAST(list: ast.list[nexti].children, index: nil, parent: ast.withIndex(i)))
                return insertText(end ..< text.upperBound, view: view, in: ast.withIndex(nexti))
            }
            // add text inside the node content but text ends before end of node content
            else {
                let rest = idx ..< text.upperBound
                if !rest.isEmpty {
                    return insertText(idx ..< text.upperBound, view: view,
                                      in: InlineAST(list: ast.list[nexti].children, index: nil, parent: ast.withIndex(i)))
                } else {
                    return ast.withIndex(i)
                }
            }
        }
        if idx < text.upperBound {
            i = ast.list.add(InlineNode(kind: .text, start: idx, end: text.upperBound), after: i)
        }
        return ast.withIndex(i)
    }
}
