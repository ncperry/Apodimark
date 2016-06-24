//
//  MarkdownParser.swift
//  Apodimark
//

/**
 A MarkdownParser holds the necessary data and type information to parse
 a collection of MarkdownParserToken.
*/
final class MarkdownParser <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {
    typealias Token = View.Iterator.Element

    let view: View
    var referenceDefinitions: [String: ReferenceDefinition]

    init(view: View) {
        self.referenceDefinitions = [:]
        self.view = view
    }

    let linefeed  : Token = .fromUTF8CodePoint(.linefeed)
    let carriage  : Token = .fromUTF8CodePoint(.carriage)
    let tab       : Token = .fromUTF8CodePoint(.tab)
    let space     : Token = .fromUTF8CodePoint(.space)
    let exclammark: Token = .fromUTF8CodePoint(.exclammark)
    let hash      : Token = .fromUTF8CodePoint(.hash)
    let leftparen : Token = .fromUTF8CodePoint(.leftparen)
    let rightparen: Token = .fromUTF8CodePoint(.rightparen)
    let asterisk  : Token = .fromUTF8CodePoint(.asterisk)
    let plus      : Token = .fromUTF8CodePoint(.plus)
    let hyphen    : Token = .fromUTF8CodePoint(.hyphen)
    let fullstop  : Token = .fromUTF8CodePoint(.fullstop)
    let one       : Token = .fromUTF8CodePoint(.one)
    let nine      : Token = .fromUTF8CodePoint(.nine)
    let colon     : Token = .fromUTF8CodePoint(.colon)
    let quote     : Token = .fromUTF8CodePoint(.quote)
    let leftsqbck : Token = .fromUTF8CodePoint(.leftsqbck)
    let backslash : Token = .fromUTF8CodePoint(.backslash)
    let rightsqbck: Token = .fromUTF8CodePoint(.rightsqbck)
    let underscore: Token = .fromUTF8CodePoint(.underscore)
    let backtick  : Token = .fromUTF8CodePoint(.backtick)
    let tilde     : Token = .fromUTF8CodePoint(.tilde)



    /// A Set containing every ascii punctuation character.
    private let asciiPunctuationTokens: Set<Token> = Set(
        [0x21, 0x22, 0x23, 0x24,
         0x25, 0x26, 0x27, 0x28,
         0x29, 0x2A, 0x2B, 0x2C,
         0x2D, 0x2E, 0x2F, 0x3A,
         0x3B, 0x3C, 0x3D, 0x3E,
         0x3F, 0x40, 0x5B, 0x5C,
         0x5D, 0x5E, 0x5F, 0x60,
         0x7B, 0x7C, 0x7D, 0x7E,].map(Token.fromUTF8CodePoint)
    )


    /// Returns true iff `char` is an ascii punctuation character
    func isPunctuation(_ char: Token) -> Bool {
        return asciiPunctuationTokens.contains(char)
    }
}

