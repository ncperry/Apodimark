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

enum InlineNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    case text(TextInlineNode<View>)
    case nonText(NonTextInlineNode<View>)
}

enum NonTextInlineNodeKind <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    indirect case reference(ReferenceKind, title: Range<View.Index>, definition: ReferenceDefinition)
    case code(Int32)
    case emphasis(Int32)
}


enum TextInlineNodeKind {
    case text
    case softbreak
    case hardbreak
}

struct TextInlineNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let kind: TextInlineNodeKind
    var start: View.Index
    var end: View.Index
}

struct NonTextInlineNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{

    let kind: NonTextInlineNodeKind<View>
    var start: View.Index
    var end: View.Index

    func contentRange(inView view: View) -> Range<View.Index> {
        switch kind {
        case .reference(_, let title, _):
            return title
        case .code(let l):
            return view.index(start, offsetBy: numericCast(l)) ..< view.index(end, offsetBy: numericCast(-l))
        case .emphasis(let l):
            return view.index(start, offsetBy: numericCast(l)) ..< view.index(end, offsetBy: numericCast(-l))
        }
    }

    init(kind: NonTextInlineNodeKind<View>, start: View.Index, end: View.Index) {
        (self.kind, self.start, self.end) = (kind, start, end)
    }
}

/*
 This is only used to efficiently sort an array of InlineNode. For reasons I can’t understand, 
 sorting an array an InlineNode with a closure like `nodes.sort { $0.start < $1.start }` is less efficient
 than making InlineNode conform to Comparabe and use `nodes.sort()`.
 */
extension NonTextInlineNode: Comparable {
    static func <  (lhs: NonTextInlineNode, rhs: NonTextInlineNode) -> Bool { return lhs.start <  rhs.start }
    static func <= (lhs: NonTextInlineNode, rhs: NonTextInlineNode) -> Bool { return lhs.start <= rhs.start }
    static func == (lhs: NonTextInlineNode, rhs: NonTextInlineNode) -> Bool { return lhs.start == rhs.start }
    static func >  (lhs: NonTextInlineNode, rhs: NonTextInlineNode) -> Bool { return lhs.start >  rhs.start }
    static func >= (lhs: NonTextInlineNode, rhs: NonTextInlineNode) -> Bool { return lhs.start >= rhs.start }
}
