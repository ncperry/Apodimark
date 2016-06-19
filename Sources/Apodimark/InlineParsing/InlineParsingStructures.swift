//
//  InlineParsingStructures.swift
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

enum EmphasisKind {
    case asterisk, underscore
}

enum DelimiterKind {
    case start              // start of line (used to ignore leading whitespace)
    case end                // end of line (used to ignore trailing whitespace)

    case emph(EmphasisKind, DelimiterState, Int)  // *

    case code(Int)         // `

    case refOpener          // [
    case unwrappedRefOpener // ![
    case refCloser          // ]


    case refValueOpener     // ( after a ]
    case leftParen          // ( used to allow pair of brackets in direct reference value definition. e.g. [link]((here))
    case rightParen         // ) used to close a direct reference value definition

    case ignored            // (used for backslash escaping)

    case softbreak
    case hardbreak
}


/// Returns true iff a token between `prev` and `next` is considered "left-flanking"
private func isLeftFlanking(prev: TokenKind, next: TokenKind) -> Bool {
    return next != .whitespace && (next != .punctuation || prev != .neither)
}

/// Returns true iff a token between `prev` and `next` is considered "right-flanking"
private func isRightFlanking(prev: TokenKind, next: TokenKind) -> Bool {
    return isLeftFlanking(prev: next, next: prev)
}


/// An option set giving the state of a delimiter (opening, closinf, neither, or both)
struct DelimiterState: OptionSet {

    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    static let closing = DelimiterState(rawValue: 0b01)
    static let opening = DelimiterState(rawValue: 0b10)

    init <T: MarkdownParserToken> (token: T, prev: TokenKind, next: TokenKind) {
        var state: DelimiterState = []
        let leftFlanking = isLeftFlanking(prev: prev, next: next)
        let rightFlanking = isRightFlanking(prev: prev, next: next)

        switch token {

        case T.fromUTF8CodePoint(.asterisk):
            if rightFlanking { state.formUnion(.closing) }
            if leftFlanking  { state.formUnion(.opening) }

        case T.fromUTF8CodePoint(.underscore):
            if rightFlanking && (!leftFlanking  || prev == .punctuation) { state.formUnion(.closing) }
            if leftFlanking  && (!rightFlanking || next == .punctuation) { state.formUnion(.opening) }

        default:
            fatalError("trying to create emphasis delimiter with character other than asterisk or underscore")
        }

        self = state
    }
}

/// An enumeration describing the type of a token (character):
/// either Whitespace, Punctuation, or Neither.
enum TokenKind {
    case whitespace, punctuation, neither
}

extension MarkdownParser {

    func tokenKind(_ token: Token) -> TokenKind {
        switch token {

        case space, linefeed:
            return .whitespace

        case let t where isPunctuation(t):
            return .punctuation

        default:
            return .neither
        }

    }
}



