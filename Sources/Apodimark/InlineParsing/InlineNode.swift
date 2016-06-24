//
//  InlineNode.swift
//  Apodimark
//

public enum ReferenceKind {
    case normal, unwrapped
}

enum InlineNodeKind <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {
    indirect case reference(ReferenceKind, title: Range<View.Index>, definition: ReferenceDefinition)
    case code(Int)
    case emphasis(Int)
    case text
    case softbreak
    case hardbreak
}

struct InlineNode <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {

    let kind: InlineNodeKind<View>
    let span: Range<View.Index>

    func contentRange(inView view: View) -> Range<View.Index> {
        switch kind {

        case .reference(_, let title, _):
            return title

        case .code(let l), .emphasis(let l):
            return view.index(span.lowerBound, offsetBy: View.IndexDistance(IntMax(l))) ..< view.index(span.upperBound, offsetBy: View.IndexDistance(IntMax(-l)))

        default:
            return span
        }
    }

    var children: LinkedList<InlineNode> = []

    init(kind: InlineNodeKind<View>, span: Range<View.Index>) {
        (self.kind, self.span) = (kind, span)
    }
}

