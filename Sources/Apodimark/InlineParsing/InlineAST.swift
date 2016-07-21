//
//  InlineAST.swift
//  Apodimark
//


final class SubInlineAST <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {
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

    func copyWithNewIndex(_ idx: NodeList.Index?) -> SubInlineAST {
        return SubInlineAST.init(list: list, index: idx, parent: parent)
    }
}

extension InlineNode {

    private func contains(range: Range<View.Index>) -> Bool {
        return start < range.lowerBound && end > range.upperBound
    }

    private func contains(node: InlineNode) -> Bool {
        return start < node.start && end > node.end
    }
}

extension MarkdownParser {

    func insertNode(_ node: InlineNode<View>, in subAST: SubInlineAST<View>) -> SubInlineAST<View> {

        if let parentNode = subAST.parentNode, !parentNode.contains(node: node) {
            return insertNode(node, in: subAST.parent!)
        }

        let list = subAST.list
        var prevI = subAST.index
        var i = prevI == nil ? list.startIndex : list.index(after: prevI!)

        while i < list.endIndex {

            defer {
                list.formIndex(after: &i)
            }

            if list[i].contains(node: node) {
                return insertNode(node, in: SubInlineAST(list: list[i].children, index: nil, parent: subAST.copyWithNewIndex(prevI)))
            }
            prevI = i
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
            }
            subAST = insertNode(node, in: subAST)
        }

        subAST = SubInlineAST(list: topList, index: nil, parent: nil)

        for node in nodes {
            guard case .text = node.kind else {
                continue
            }
            subAST = insertText(node.contentRange(inView: view), view: view, in: subAST)
        }

        return topList
    }


    func insertText(_ text: Range<View.Index>, view: View, in subAST: SubInlineAST<View>) -> SubInlineAST<View> {

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

            if idx < start && start <= text.upperBound {
                prevI = list.add(InlineNode(kind: .text, start: idx, end: start), after: prevI)

                i = list.index(after: prevI!)
            }

            else if idx < start && start > text.upperBound {
                prevI = list.add(InlineNode(kind: .text, start: idx, end: text.upperBound), after: prevI)

                return SubInlineAST(list: list, index: prevI, parent: subAST.parent)
            }

            idx = max(startC, idx)

            if idx < endC && endC <= text.upperBound {
                let nextAST = insertText(idx ..< endC, view: view,
                                         in: SubInlineAST(list: list[i].children, index: nil, parent: subAST.copyWithNewIndex(prevI)))

                return insertText(end ..< text.upperBound, view: view, in: nextAST)
            }
            else if idx < endC && text.upperBound < endC {
                return insertText(idx ..< text.upperBound, view: view,
                                         in: SubInlineAST(list: list[i].children, index: nil, parent: subAST.copyWithNewIndex(prevI)))
            }

            idx = max(end, idx)
        }
        if idx < text.upperBound {
            _ = list.add(InlineNode(kind: .text, start: idx, end: text.upperBound), after: prevI)
        }

        return SubInlineAST(list: list, index: prevI, parent: subAST.parent)
    }
}
