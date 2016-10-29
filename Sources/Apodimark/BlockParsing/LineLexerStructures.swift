//
//  LineLexerStructures.swift
//  Apodimark
//

/// The kind of a fence
enum FenceKind { case backtick, tilde }

/// The kind of a list
enum ListKind {

    enum BulletKind { case star, hyphen, plus }
    enum NumberKind { case dot, parenthesis }

    /// ListKind for an unordered list
    case bullet(BulletKind)
    /// ListKind for an ordered list
    case number(NumberKind, Int)

    /// Gives the textual width of `self`.
    /// Examples:
    /// - A Bullet list has a width of 1 (the bullet + space after it)
    /// - A Number list with the number 23 has a width of 3 (two digits of 23 + dot or parenthesis + space)
    var width: Int {
        switch self {

        case .bullet:
            return 1

        case .number(_, var value):
            var width = 2
            while value > 9 {
                (value, width) = (value / 10, width + 1)
            }
            return width
        }
    }
}


/// Returns true iff `lhs` is equal to `rhs`, ignoring the number of a Number kind.
func ~= (lhs: ListKind, rhs: ListKind) -> Bool {
    switch (lhs, rhs) {

    case let (.bullet(l), .bullet(r)):
        return l == r

    case let (.number(kl, _), .number(kr, _)):
        return kl == kr

    case _:
        return false
    }
}

/// The kind of a line
indirect enum LineKind <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    case list(ListKind, Line<View, RefDef>)
    case quote(Line<View, RefDef>)
    case text
    case header(Range<View.Index>, Int32)
    case fence(FenceKind, Range<View.Index>, Int32)
    case thematicBreak
    case empty
    case reference(Range<View.Index>, Range<View.Index>)

    /// Return true iff `self` is equal to .empty
    func isEmpty() -> Bool {
        if case .empty = self { return true }
        else { return false }
    }
}

/// Enum describing the kind of an indent.
///
/// The `rawValue` of the enum is the value of an indent of that kind.
/// e.g. a space adds a value of 1 while a tab adds a value of 4
enum IndentKind {

    case space
    case tab

    var width: Int {
        switch self {
        case .space: return 1
        case .tab: return TAB_INDENT
        }
    }
    
    init? <Codec: MarkdownParserCodec> (_ token: Codec.CodeUnit, codec: Codec.Type) {
        switch token {

        case Codec.space:
            self = .space

        case Codec.tab:
            self = .tab

        default:
            return nil
        }
    }
}

struct Indent {
    /// The length of the indent (e.g. one space and one tab has a length of 1 + 4 = 5)
    var level: Int = 0

    /// Adds a character to the indent
    mutating func add(_ kind: IndentKind) {
        level += kind.width
    }
}

/// Structure representing a single line of the original document.
/// It contains the kind of the line (empty, potential list, simply text, etc.)
/// as well as its indent and its indices in the original collection.
struct Line <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    /// The kind of the line (quote, list, header, etc.)
    let kind: LineKind<View, RefDef>

    /// The indent of the line
    var indent: Indent

    // The indices of the line in the original collection. May or may not contain the indent.
    var indices: Range<View.Index>

    init(_ kind: LineKind<View, RefDef>, _ indent: Indent, _ indices: Range<View.Index>) {
        (self.kind, self.indent, self.indices) = (kind, indent, indices)
    }
}

extension MarkdownParser {
    func restoreIndentInLine(_ line: inout Line) {
        var indent = line.indent.level
        var i = line.indices.lowerBound
        while indent > 0 {
            view.formIndex(before: &i)
            let kind = IndentKind(view[i], codec: Codec.self)!
            indent -= kind.width
        }
        line.indices = i ..< line.indices.upperBound
    }
}

