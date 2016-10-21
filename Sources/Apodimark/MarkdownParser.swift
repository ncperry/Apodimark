//
//  MarkdownParser.swift
//  Apodimark
//

/**
 A MarkdownParser holds the necessary data and type information to parse
 a collection representing some text.
*/
final class MarkdownParser <View: BidirectionalCollection, Codec: MarkdownParserCodec> where
    View.Iterator.Element == Codec.CodeUnit,
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Delimiter = (idx: View.Index, kind: DelimiterKind<View>)
    
    let view: View
    var referenceDefinitions: [String: ReferenceDefinition]
    let blockTree: Tree<BlockNode<View>>
        
    init(view: View, referenceDefinitions: [String: ReferenceDefinition]) {
        self.referenceDefinitions = referenceDefinitions
        self.view = view
        self.blockTree = .init()
    }
}

