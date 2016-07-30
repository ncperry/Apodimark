//
//  Apodimark.swift
//  Apodimark
//

public protocol ReferenceDefinition { }
extension String: ReferenceDefinition { }

// indirect to work around "cyclic metadata dependency" bug
public indirect enum MarkdownInline <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {
    case text(Range<View.Index>)
    case reference(kind: ReferenceKind, title: [MarkdownInline], definition: ReferenceDefinition, markers: [Range<View.Index>])
    case emphasis(level: Int, content: [MarkdownInline], markers: (Range<View.Index>, Range<View.Index>))
    case monospacedText([MarkdownInline], markers: (Range<View.Index>, Range<View.Index>))
    case softbreak(span: Range<View.Index>)
    case hardbreak(span: Range<View.Index>)
}

public struct MarkdownListItemBlock <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {
    public let markerSpan: Range<View.Index>
    public var content: [MarkdownBlock<View>]
}

public enum MarkdownBlock <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
>  {
    case paragraph(text: [MarkdownInline<View>])
    case header(level: Int, text: [MarkdownInline<View>], markers: (Range<View.Index>, Range<View.Index>?))
    case quote(content: [MarkdownBlock<View>], markers: [View.Index])
    case list(kind: MarkdownListKind, items: [MarkdownListItemBlock<View>])
    case fence(name: Range<View.Index>, text: [Range<View.Index>], markers: (Range<View.Index>, Range<View.Index>?))
    case code(text: [Range<View.Index>])
    case thematicBreak
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

@_specialize(String.UTF16View) 
public func parsedMarkdown <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> (source: View) -> [MarkdownBlock<View>] {

    return MarkdownParser(view: source).finalAST()
}

extension MarkdownParser {

    /// Parse the collection and return the Abstract Syntax Tree
    /// describing the resulting Markdown document.
    func finalAST() -> [MarkdownBlock<View>] {
        return parseBlocks().flatMap(makeFinalBlock)
    }

    /// Return a MarkdownInline node from an instance of the internal InlineNode type
    private func makeFinalInlineNode(from node: InlineNode<View>) -> MarkdownInline<View> {
        switch node.kind {

        case .hardbreak:
            return .hardbreak(span: node.start ..< node.end)

        case .softbreak:
            return .softbreak(span: node.start ..< node.end)

        case .text:
            return .text(node.contentRange(inView: view))

        case .code(let level):
            let startMarkers = node.start ..< view.index(node.start, offsetBy: View.IndexDistance(level.toIntMax()))
            let endMarkers = view.index(node.end, offsetBy: View.IndexDistance(-level.toIntMax())) ..< node.end
            let children = node.children.map(makeFinalInlineNode)
            return .monospacedText(children, markers: (startMarkers, endMarkers))

        case .emphasis(let level):
            let startMarkers = node.start ..< view.index(node.start, offsetBy: View.IndexDistance(level.toIntMax()))
            let endMarkers = view.index(node.end, offsetBy: View.IndexDistance(-level.toIntMax())) ..< node.end
            return .emphasis(level: level, content: node.children.map(makeFinalInlineNode), markers: (startMarkers, endMarkers))

        case .reference(let kind, title: let title, definition: let definition):
            let markers = [node.start ..< title.lowerBound, title.upperBound ..< node.end]
            return .reference(kind: kind, title: node.children.map(makeFinalInlineNode), definition: definition, markers: markers)
        }
    }

    /// Return a MarkdownBlock from an instance of the internal BlockNode type.
    private func makeFinalBlock(from node: BlockNode<View>) -> MarkdownBlock<View>? {
        switch node {

        case let node as ParagraphBlockNode<View>:
            return .paragraph(text: parseInlines(text: node.text).map(makeFinalInlineNode))


        case let node as HeaderBlockNode<View>:
            return .header(level: node.level, text: parseInlines(text: [node.text]).map(makeFinalInlineNode), markers: node.markers)


        case let node as QuoteBlockNode<View>:
            return .quote(content: node.content.flatMap(makeFinalBlock), markers: node.markers)


        case let node as ListBlockNode<View>:
            let items = node.items.map { MarkdownListItemBlock(markerSpan: $0.markerSpan, content: $0.content.flatMap(makeFinalBlock)) }
            return .list(kind: MarkdownListKind(kind: node.kind), items: items)


        case let node as CodeBlockNode<View>:
            return .code(text: node.text)


        case let node as FenceBlockNode<View>:
            return .fence(name: node.name, text: node.text, markers: node.markers)
            
            
        case is ThematicBreakBlockNode<View>:
            return .thematicBreak
            
            
        case is ReferenceDefinitionBlockNode<View>:
            return nil
        
        default:
            fatalError()
        }
    }
}
