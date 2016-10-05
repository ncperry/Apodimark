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
    typealias Delimiter = (kind: DelimiterKind, idx: View.Index)
    
    let view: View
    var referenceDefinitions: [String: ReferenceDefinition]
    
    init(view: View) {
        self.referenceDefinitions = [:]
        self.view = view
    }
}

