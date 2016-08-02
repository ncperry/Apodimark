//
//  MarkdownParser.swift
//  Apodimark
//

/**
 A MarkdownParser holds the necessary data and type information to parse
 a collection of MarkdownParserToken.
*/
final class MarkdownParser <View: BidirectionalCollection> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Token = View.Iterator.Element

    let view: View
    var referenceDefinitions: [String: ReferenceDefinition]

    init(view: View) {
        self.referenceDefinitions = [:]
        self.view = view
    }

    let linefeed  : Token = .fromASCII(.linefeed)
    let carriage  : Token = .fromASCII(.carriage)
    let tab       : Token = .fromASCII(.tab)
    let space     : Token = .fromASCII(.space)
    let exclammark: Token = .fromASCII(.exclammark)
    let hash      : Token = .fromASCII(.hash)
    let leftparen : Token = .fromASCII(.leftparen)
    let rightparen: Token = .fromASCII(.rightparen)
    let asterisk  : Token = .fromASCII(.asterisk)
    let plus      : Token = .fromASCII(.plus)
    let hyphen    : Token = .fromASCII(.hyphen)
    let fullstop  : Token = .fromASCII(.fullstop)
    let zero      : Token = .fromASCII(.zero)
    let nine      : Token = .fromASCII(.nine)
    let colon     : Token = .fromASCII(.colon)
    let quote     : Token = .fromASCII(.quote)
    let leftsqbck : Token = .fromASCII(.leftsqbck)
    let backslash : Token = .fromASCII(.backslash)
    let rightsqbck: Token = .fromASCII(.rightsqbck)
    let underscore: Token = .fromASCII(.underscore)
    let backtick  : Token = .fromASCII(.backtick)
    let tilde     : Token = .fromASCII(.tilde)



    /// A Set containing every ascii punctuation character.
    private let asciiPunctuationTokens: Set<Token> = Set(
        [0x21, 0x22, 0x23, 0x24,
         0x25, 0x26, 0x27, 0x28,
         0x29, 0x2A, 0x2B, 0x2C,
         0x2D, 0x2E, 0x2F, 0x3A,
         0x3B, 0x3C, 0x3D, 0x3E,
         0x3F, 0x40, 0x5B, 0x5C,
         0x5D, 0x5E, 0x5F, 0x60,
         0x7B, 0x7C, 0x7D, 0x7E,].map(Token.fromASCII)
    )


    /// Returns true iff `char` is an ascii punctuation character
    func isPunctuation(_ char: Token) -> Bool {
        return asciiPunctuationTokens.contains(char)
    }
}

