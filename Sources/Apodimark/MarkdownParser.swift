//
//  MarkdownParser.swift
//  Apodimark
//

/**
 A MarkdownParser holds the necessary data and type information to parse
 a collection representing some text.
*/
struct MarkdownParser <View: BidirectionalCollection, Codec: MarkdownParserCodec> where
    View.Iterator.Element == Codec.CodeUnit,
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let view: View
    var referenceDefinitions: [String: ReferenceDefinition]

    init(view: View) {
        self.referenceDefinitions = [:]
        self.view = view
    }

    /// A Set containing every ascii punctuation character.
    private let asciiPunctuationTokens: Set<Codec.CodeUnit> = Set(
        [0x21, 0x22, 0x23, 0x24,
         0x25, 0x26, 0x27, 0x28,
         0x29, 0x2A, 0x2B, 0x2C,
         0x2D, 0x2E, 0x2F, 0x3A,
         0x3B, 0x3C, 0x3D, 0x3E,
         0x3F, 0x40, 0x5B, 0x5C,
         0x5D, 0x5E, 0x5F, 0x60,
         0x7B, 0x7C, 0x7D, 0x7E,].map(Codec.fromASCII)
    )


    /// Returns true iff `char` is an ascii punctuation character
    func isPunctuation(_ char: Codec.CodeUnit) -> Bool {
        return asciiPunctuationTokens.contains(char)
    }
}

