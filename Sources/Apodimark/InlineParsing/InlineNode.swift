//
//  InlineNode.swift
//  Apodimark
//

public enum ReferenceKind {
    case normal, unwrapped

    var textWidth: Int {
        switch self {
        case .normal   : return 1
        case .unwrapped: return 2
        }
    }
}

enum InlineNodeKind <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    indirect case reference(ReferenceKind, title: Range<View.Index>, definition: ReferenceDefinition)
    case code(Int)
    case emphasis(Int)
    case text
    case softbreak
    case hardbreak
}

struct InlineNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{

    let kind: InlineNodeKind<View>
    let (start, end): (View.Index, View.Index)

    func contentRange(inView view: View) -> Range<View.Index> {
        switch kind {

        case .reference(_, let title, _):
            return title

        case .code(let l), .emphasis(let l):
            return view.index(start, offsetBy: View.IndexDistance(IntMax(l))) ..< view.index(end, offsetBy: View.IndexDistance(IntMax(-l)))

        default:
            return start ..< end
        }
    }

    var children: LinkedList<InlineNode> = []

    init(kind: InlineNodeKind<View>, start: View.Index, end: View.Index) {
        (self.kind, self.start, self.end) = (kind, start, end)
    }
}

