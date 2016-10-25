//
//  MarkdownParser.swift
//  Apodimark
//

let TAB_INDENT = 4

/**
 A MarkdownParser holds the necessary data and type information to parse
 a collection representing some text.
*/
final class MarkdownParser <View: BidirectionalCollection, Codec: MarkdownParserCodec, RefManager: ReferenceDefinitionsManager> where
    View.Iterator.Element == Codec.CodeUnit,
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let view: View
    var referenceDefinitions: RefManager
    let blockTree: Tree<Block>
        
    init(view: View, referenceDefinitions: RefManager) {
        self.referenceDefinitions = referenceDefinitions
        self.view = view
        self.blockTree = .init()
    }
}

// type aliases

extension MarkdownParser {
    typealias TextDel = (idx: View.Index, kind: TextDelKind)
    typealias NonTextDel = (idx: View.Index, kind: NonTextDelKind)

    typealias RefDef = RefManager.Definition
    
    typealias Inline = InlineNode<View, RefDef>
    typealias NonTextInline = NonTextInlineNode<View, RefDef>
    typealias TextInline = TextInlineNode<View>
    
    typealias Block = BlockNode<View, RefDef>
    
    typealias LineKind = Apodimark.LineKind<View, RefDef>
    typealias Line = Apodimark.Line<View, RefDef>
}
