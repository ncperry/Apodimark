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

public enum MarkdownListKind: CustomStringConvertible {

    case unordered
    case ordered(startingAt: Int)

    init(kind: ListKind) {
        switch kind {
        case .bullet(_): self = .unordered
        case .number(_, let n): self = .ordered(startingAt: n)
        }
    }

    public var description: String {
        switch self {
        case .unordered:
            return "Bullet"
        case .ordered(startingAt: let n):
            return "Number(\(n))"
        }
    }
}

@_specialize(String.UTF16View, UTF16MarkdownCodec)
public func parsedMarkdown <View, Codec> (source: View, codec: Codec.Type) -> [MarkdownBlock<View>] where
    View: BidirectionalCollection,
    Codec: MarkdownParserCodec,
    View.Iterator.Element == Codec.CodeUnit,
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    var parser = MarkdownParser<View, Codec>(view: source)
    return parser.finalAST()
}

extension MarkdownParser {

    /// Parse the collection and return the Abstract Syntax Tree
    /// describing the resulting Markdown document.
    mutating func finalAST() -> [MarkdownBlock<View>] {
        return parseBlocks().flatMap(makeFinalBlock)
    }

    /// Return a MarkdownInline node from an instance of the internal InlineNode type
    fileprivate func makeFinalInlineNode(from node: InlineNode<View>) -> MarkdownInline<View> {
        switch node.kind {

        case .hardbreak:
            return .hardbreak(BreakInline(span: node.start ..< node.end))

        case .softbreak:
            return .softbreak(BreakInline(span: node.start ..< node.end))

        case .text:
            return .text(TextInline(span: node.contentRange(inView: view)))

        case .code(let level):
            let startMarkers = node.start ..< view.index(node.start, offsetBy: View.IndexDistance(level.toIntMax()))
            let endMarkers = view.index(node.end, offsetBy: View.IndexDistance(-level.toIntMax())) ..< node.end
            
            let inline = MonospacedTextInline(
                content: node.children.map(makeFinalInlineNode),
                markers: (startMarkers, endMarkers)
            )
            return .monospacedText(inline)

        case .emphasis(let level):
            let startMarkers = node.start ..< view.index(node.start, offsetBy: View.IndexDistance(level.toIntMax()))
            let endMarkers = view.index(node.end, offsetBy: View.IndexDistance(-level.toIntMax())) ..< node.end
            
            let inline = EmphasisInline(
                level: level,
                content: node.children.map(makeFinalInlineNode),
                markers: (startMarkers, endMarkers)
            )

            return .emphasis(inline)

        case .reference(let kind, title: let title, definition: let definition):
            let markers = [node.start ..< title.lowerBound, title.upperBound ..< node.end]
            
            let inline = ReferenceInline(
                kind: kind,
                title: node.children.map(makeFinalInlineNode),
                definition: definition,
                markers: markers
            )
            
            return .reference(inline)
        }
    }

    /// Return a MarkdownBlock from an instance of the internal BlockNode type.
    fileprivate func makeFinalBlock(from node: BlockNode<View>) -> MarkdownBlock<View>? {
        switch node {

        case let node as ParagraphBlockNode<View>:
            let block = ParagraphBlock(text: parseInlines(text: node.text).map(makeFinalInlineNode))
            return .paragraph(block)


        case let node as HeaderBlockNode<View>:
            let block = HeaderBlock(
                level: node.level,
                text: parseInlines(text: [node.text]).map(makeFinalInlineNode),
                markers: node.markers
            )
            return .header(block)


        case let node as QuoteBlockNode<View>:
            
            let block = QuoteBlock(
                content: node.content.flatMap(makeFinalBlock),
                markers: node.markers
            )
            
            return .quote(block)


        case let node as ListBlockNode<View>:
            let items = node.items.map {
                return MarkdownListItemBlock(
                    marker: $0.markerSpan,
                    content: $0.content.flatMap(makeFinalBlock)
                )
            }
            
            let block = ListBlock(kind: MarkdownListKind(kind: node.kind), items: items)
            
            return .list(block)


        case let node as CodeBlockNode<View>:
            return .code(CodeBlock(text: node.text))


        case let node as FenceBlockNode<View>:
            let block = FenceBlock<View>(
                name: node.name,
                text: node.text,
                markers: node.markers
            )
            return .fence(block)
            
            
        case let node as ThematicBreakBlockNode<View>:
            return .thematicBreak(ThematicBreakBlock(marker: node.span))
            
            
        case is ReferenceDefinitionBlockNode<View>:
            return nil
        
        default:
            fatalError()
        }
    }
}
