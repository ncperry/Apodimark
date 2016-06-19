//
//  LineLexerStructures.swift
//  Apodimark
//

/// The kind of a fence
enum FenceKind { case Backtick, Tilde }

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
    /// - A Bullet list has a width of 2 (the bullet + space after it)
    /// - A Number list with the number 23 has a width of 4 (two digits of 23 + dot or parenthesis + space)
    var width: Int {
        switch self {

        case .bullet(_):
            return 2

        case .number(_, var value):
            var width = 3
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
enum LineKind <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {
    indirect case list(ListKind, Line<View>)
    indirect case quote(Line<View>)
    case text
    case header(Range<View.Index>, Int)
    case fence(FenceKind, Range<View.Index>, Int)
    case thematicBreak
    case empty
    case reference(String, ReferenceDefinition)

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
enum IndentKind: Int {

    case space = 1
    case tab = 4

    init? <Token: MarkdownParserToken> (_ token: Token) {
        switch token {

        case Token.fromUTF8CodePoint(.space):
            self = .space

        case Token.fromUTF8CodePoint(.tab):
            self = .tab

        default:
            return nil
        }
    }
}

/// An Indent is a serie of spaces or tabs.
/// This structure keeps both the total value of the indents (called the
/// “level” of the indent), as well as its composition.
/// For example, an indent made up of 2 spaces and 1 tab will have a
/// level of (2 * 1) + (1 * 4) = 6 and will contain [.space, .space, .tab].
internal struct Indent {

    /// The length of the indent (e.g. one space and one tab has a length of 1 + 4 = 5)
    var level: Int = 0

    /// An array of the characters making up the indent
    var composition: [IndentKind] = []

    /// Adds a character to the indent, changing its level and its composition
    mutating func add(_ kind: IndentKind) {
        composition.append(kind)
        level += kind.rawValue
    }

    /// - returns: a new indent created by removing `n` level from `self`
    ///
    /// - note: if `n` is bigger than the level of `self`, then the returned
    /// Indent will have a negative level.
    func removingFirst(_ n: Int) -> Indent {
        var levelsRemoved = 0
        var idx = 0

        while idx < composition.endIndex && levelsRemoved < n {
            levelsRemoved += composition[idx].rawValue
            idx += 1
        }
        let newkinds = Array(composition[idx ..< composition.endIndex])

        return Indent(level: level - n, composition: newkinds)
    }
}

/// Structure representing a single line of the original document.
/// It contains the kind of the line (empty, potential list, simply text, etc.)
/// as well as its indent and a scanner on the text of the line.
struct Line <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {
    typealias Token = View.Iterator.Element

    /// The kind of the line (quote, list, header, etc.)
    let kind: LineKind<View>

    /// The indent of the line
    let indent: Indent

    // The scanner containing the text of the line. May or may not contain the indent
    let scanner: Scanner<View>

    init(_ kind: LineKind<View>, _ indent: Indent, _ subview: Scanner<View>) {
        (self.kind, self.indent, self.scanner) = (kind, indent, subview)
    }

    /// - returns: a new line equal to `self` with `n` fewer indents
    func removingFirstIndents(n: Int) -> Line {
        let newindent = indent.removingFirst(n)
        return Line(kind, newindent, scanner)
    }

    // - returns: a new line equal to `self`, except that its scanner contains the indent
    // - precondition: `self.scanner` doesn't contain the indent (precondition not checked at runtime)
    func restoringIndentInSubview() -> Line {
        var newSubview = scanner
        try! newSubview.pushBackStartIndexBy(n: View.IndexDistance(IntMax(indent.composition.count)))

        return Line(kind, indent, newSubview)
    }
}

