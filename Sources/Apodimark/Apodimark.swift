//
//  Apodimark.swift
//  Apodimark
//

public protocol ReferenceDefinition { }
extension String: ReferenceDefinition { }

public struct ParagraphBlock <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let text: [MarkdownInline<View>]
}
public struct HeaderBlock <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let level: Int
    public let text: [MarkdownInline<View>]
    public let markers: (Range<View.Index>, Range<View.Index>?)
}
public struct QuoteBlock <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let content: [MarkdownBlock<View>]
    public let markers: [View.Index]
}
public struct MarkdownListItemBlock <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let marker: Range<View.Index>
    public let content: [MarkdownBlock<View>]
}

public struct ListBlock <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let kind: MarkdownListKind
    public let items: [MarkdownListItemBlock<View>]
}

public struct FenceBlock <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let name: Range<View.Index>
    public let text: [Range<View.Index>]
    public let markers: (Range<View.Index>, Range<View.Index>?)
}

public struct CodeBlock <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let text: [Range<View.Index>]
}

public struct ThematicBreakBlock <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let marker: Range<View.Index>
}

public struct TextInline <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let span: Range<View.Index>
}

public struct BreakInline <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let span: Range<View.Index>
}

public struct ReferenceInline <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let kind: ReferenceKind
    public let title: [MarkdownInline<View>]
    public let definition: ReferenceDefinition
    public let markers: [Range<View.Index>]
}

public struct EmphasisInline <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let level: Int
    public let content: [MarkdownInline<View>]
    public let markers: (Range<View.Index>, Range<View.Index>)
}

public struct MonospacedTextInline <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    public let content: [MarkdownInline<View>]
    public let markers: (Range<View.Index>, Range<View.Index>)
}

public indirect enum MarkdownInline <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    case text(TextInline<View>)
    case reference(ReferenceInline<View>)
    case emphasis(EmphasisInline<View>)
    case monospacedText(MonospacedTextInline<View>)
    case softbreak(BreakInline<View>)
    case hardbreak(BreakInline<View>)
}

public indirect enum MarkdownBlock <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    case paragraph(ParagraphBlock<View>)
    case header(HeaderBlock<View>)
    case quote(QuoteBlock<View>)
    case list(ListBlock<View>)
    case fence(FenceBlock<View>)
    case code(CodeBlock<View>)
    case thematicBreak(ThematicBreakBlock<View>)
}

public enum MarkdownListKind {

    case unordered
    case ordered(startingAt: Int)

    init(kind: ListKind) {
        switch kind {
        case .bullet(_): self = .unordered
        case .number(_, let n): self = .ordered(startingAt: n)
        }
    }
}

@_specialize(String.UTF16View, UTF16MarkdownCodec)
@_specialize(Array<UInt8>, UTF8MarkdownCodec)
public func parsedMarkdown <View, Codec> (source: View, referenceDefinitions: [String: ReferenceDefinition] = [:], codec: Codec.Type) -> [MarkdownBlock<View>] where
    View: BidirectionalCollection,
    Codec: MarkdownParserCodec,
    View.Iterator.Element == Codec.CodeUnit,
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let parser = MarkdownParser<View, Codec>(view: source, referenceDefinitions: referenceDefinitions)
    return parser.finalAST()
}

extension MarkdownParser {

    /// Parse the collection and return the Abstract Syntax Tree
    /// describing the resulting Markdown document.
    fileprivate func finalAST() -> [MarkdownBlock<View>] {
        parseBlocks()
        return blockTree.makeIterator().flatMap(makeFinalBlock(from:children:))
    }
    
    /// Return a MarkdownBlock from an instance of the internal BlockNode type.
    fileprivate func makeFinalBlock(from node: BlockNode<View>, children: TreeIterator<BlockNode<View>>?) -> MarkdownBlock<View>? {
        switch node {
            
        case let .paragraph(p):
            let inlines = makeFinalInlineNodeTree(from: parseInlines(p.text).makeIterator())
            let block = ParagraphBlock(text: inlines)
            return .paragraph(block)
            
            
        case let .header(h):
            let block = HeaderBlock(
                level: numericCast(h.level),
                text: makeFinalInlineNodeTree(from: parseInlines([h.text]).makeIterator()),
                markers: h.markers
            )
            return .header(block)
            
            
        case let .quote(q):
            
            let block = QuoteBlock(
                content: children?.flatMap(makeFinalBlock) ?? [],
                markers: q.markers
            )
            
            return .quote(block)
        
        case .listItem:
            fatalError()
        
        case let .list(l):
            let items = children?.map { (n, c) -> MarkdownListItemBlock<View> in
                guard case .listItem(let i) = n else { return .init(marker: view.startIndex ..< view.startIndex, content: []) }
                return MarkdownListItemBlock<View>(
                    marker: i.markerSpan,
                    content: c?.flatMap(makeFinalBlock) ?? []
                )
            } ?? []
            
            let block = ListBlock(kind: MarkdownListKind(kind: l.kind), items: items)
            
            return .list(block)
            
            
        case let .code(c):
            return .code(CodeBlock(text: c.text))
            
            
        case let .fence(f):
            let block = FenceBlock<View>(
                name: f.name,
                text: f.text,
                markers: f.markers
            )
            return .fence(block)
            
            
        case let .thematicBreak(t):
            return .thematicBreak(ThematicBreakBlock(marker: t.span))
            
            
        case .referenceDefinition:
            return nil
        }
    }

}

extension MarkdownParser {
    fileprivate func makeFinalInlineNodeTree(from tree: TreeIterator<InlineNode<View>>) -> [MarkdownInline<View>] {
        
        var nodes: [MarkdownInline<View>] = []
        
        for (node, children) in tree {
            switch node {
            case .text(let t):
                switch t.kind {
                    
                case .hardbreak:
                    nodes.append(.hardbreak(BreakInline(span: t.start ..< t.end)))
                    
                case .softbreak:
                    nodes.append(.softbreak(BreakInline(span: t.start ..< t.end)))
                    
                case .text:
                    nodes.append(.text(TextInline(span: t.start ..< t.end)))
                }
    
            case .nonText(let n):
                switch n.kind {
                case .code(let level):
                    let startMarkers = n.start ..< view.index(n.start, offsetBy: numericCast(level))
                    let endMarkers = view.index(n.end, offsetBy: numericCast(-level)) ..< n.end
                    
                    let inline = MonospacedTextInline(
                        content: children.map(makeFinalInlineNodeTree) ?? [],
                        markers: (startMarkers, endMarkers)
                    )
                    nodes.append(.monospacedText(inline))
                    
                case .emphasis(let level):
                    let startMarkers = n.start ..< view.index(n.start, offsetBy: numericCast(level))
                    let endMarkers = view.index(n.end, offsetBy: numericCast(-level)) ..< n.end
                    
                    let inline = EmphasisInline(
                        level: numericCast(level),
                        content: children.map(makeFinalInlineNodeTree) ?? [],
                        markers: (startMarkers, endMarkers)
                    )
                    
                    nodes.append(.emphasis(inline))
                    
                case .reference(let kind, title: let title, definition: let definition):
                    let markers = [n.start ..< title.lowerBound, title.upperBound ..< n.end]
                    
                    let inline = ReferenceInline(
                        kind: kind,
                        title: children.map(makeFinalInlineNodeTree) ?? [],
                        definition: definition,
                        markers: markers
                    )
                    
                    nodes.append(.reference(inline))
                }
            }
        }
        return nodes
    }
}


