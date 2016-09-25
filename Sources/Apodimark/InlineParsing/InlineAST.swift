//
//  InlineAST.swift
//  Apodimark
//

// I’m so sorry for the code in this file...

final class SubInlineAST <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias NodeList = LinkedList<InlineNode<View>>

    let list: NodeList
    let index: NodeList.Index?
    let parent: SubInlineAST?

    init(list: NodeList, index: NodeList.Index?, parent: SubInlineAST?) {
        (self.list, self.index, self.parent) = (list, index, parent)
    }

    var parentNode: InlineNode<View>? {
        guard let parent = parent else { return nil }
        let indexAfterParentIndex = parent.index == nil ? parent.list.startIndex : parent.list.index(after: parent.index!)
        return parent.list[indexAfterParentIndex]
    }

    func withIndex(_ idx: NodeList.Index?) -> SubInlineAST {
        return SubInlineAST.init(list: list, index: idx, parent: parent)
    }
}

extension InlineNode {

    fileprivate func contains(range: Range<View.Index>) -> Bool {
        return start < range.lowerBound && end > range.upperBound
    }

    fileprivate func contains(node: InlineNode) -> Bool {
        return start < node.start && end > node.end
    }
}

extension MarkdownParser {
    
    func insertNode(_ node: InlineNode<View>, in subAST: SubInlineAST<View>) -> SubInlineAST<View> {

        // nodes are sorted before calling this function and subAST is either basic or created with this function
        
        if let parentNode = subAST.parentNode, !parentNode.contains(node: node) {
            return insertNode(node, in: subAST.parent!)
        }

        let list = subAST.list
        var prevI = subAST.index
        let i = prevI == nil ? list.startIndex : list.index(after: prevI!)
        
        if i < list.endIndex {
            if list[i].contains(node: node) {
                return insertNode(node, in: SubInlineAST(list: list[i].children, index: nil, parent: subAST.withIndex(prevI)))
            }
            prevI = i
            // list.formIndex(after: &i)
        }
        
        _ = list.add(node, after: prevI)

        return SubInlineAST(list: list, index: prevI, parent: subAST.parent)
    }

    func makeAST(with nodes: [InlineNode<View>]) -> LinkedList<InlineNode<View>> {

        var subAST = SubInlineAST<View>(list: [], index: nil, parent: nil)
        let topList = subAST.list

        for node in nodes {
            if case .text = node.kind {
                continue
            } else {
                subAST = insertNode(node, in: subAST)
            }
        }

        subAST = SubInlineAST(list: topList, index: nil, parent: nil)

        for node in nodes {
            if case .text = node.kind {
                subAST = insertText(node.contentRange(inView: view), view: view, in: subAST)
            } else {
                continue
            }
        }

        return topList
    }


    func insertText(_ text: Range<View.Index>, view: View, in subAST: SubInlineAST<View>) -> SubInlineAST<View> {

        // text might span several nodes at different levels
        /* e.g.
         This *is _Bill_*.
         
         NODES BEFORE:
         emph(5 ... 16, 6 ... 15)
           |
         emph(9 ... 15, 10 ... 14)
         
         NODES AFTER ADDING TEXT 0 ... 16:
         text(0 ... 4) - emph - text(16 ... 16)
                          |
              text(6 ... 8) - emph - text(15 ..< 15)
                                |
                            text(10 ... 13)
         
         
         EDGE CASE:
         *hello\! world* bye
         
         NODES BEFORE;
         emph(0 ... 14, 1 ... 13)
         
         NODES AFTER ADDING TEXT 0 ...5:
         emph
          |
         text(1...4)
         
         subAST returned is one pointing to text(1 ... 4)
         
         NODES AFTER ADDING TEXT 6 ... 18:
         emph - text(15 ... 18)
          |
         text(1 ... 4) - text(6 ... 13)
         
         */
        
        let list = subAST.list
        var idx = text.lowerBound

        var prevI = subAST.index
        var i = prevI == nil ? list.startIndex : list.index(after: prevI!)

        if let parentNode = subAST.parentNode, !parentNode.contains(range: text) {
            return insertText(text, view: view, in: subAST.parent!)
        }
        
        while i < list.endIndex && idx < text.upperBound {

            defer {
                prevI = i
                list.formIndex(after: &i)
            }

            let (start, end) = (list[i].start, list[i].end)
            let curContentRange = list[i].contentRange(inView: view)
            let (startC, endC) = (curContentRange.lowerBound, curContentRange.upperBound)

            // add text before node
            if idx < start && start <= text.upperBound {
                prevI = list.add(InlineNode(kind: .text, start: idx, end: start), after: prevI)

                i = list.index(after: prevI!)
            }
            // add text before node but text ends before start of node
            else if idx < start && start > text.upperBound {
                prevI = list.add(InlineNode(kind: .text, start: idx, end: text.upperBound), after: prevI)

                return SubInlineAST(list: list, index: prevI, parent: subAST.parent)
            }

            idx = max(startC, idx)
            // add text inside the node content
            if idx < endC && endC <= text.upperBound {
                let nextAST = insertText(idx ..< endC, view: view,
                                         in: SubInlineAST(list: list[i].children, index: nil, parent: subAST.withIndex(prevI)))

                return insertText(end ..< text.upperBound, view: view, in: nextAST)
            }
            // add text inside the node content but text ends before end of node content
            else if idx < endC && text.upperBound < endC {
                return insertText(idx ..< text.upperBound, view: view,
                                  in: SubInlineAST(list: list[i].children, index: nil, parent: subAST.withIndex(prevI)))
            }

            idx = max(end, idx)
        }
        if idx < text.upperBound {
            _ = list.add(InlineNode(kind: .text, start: idx, end: text.upperBound), after: prevI)
        }

        return SubInlineAST(list: list, index: prevI, parent: subAST.parent)
    }
}
