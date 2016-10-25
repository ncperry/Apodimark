//
//  Apodimark.swift
//  Apodimark
//

public protocol ReferenceDefinitionsManager {
    associatedtype Definition: ReferenceDefinitionProtocol
    mutating func add(key: String, value: Definition)
    func definition(for key: String) -> Definition?
}

public struct DefaultReferenceDefinitionsManager: ReferenceDefinitionsManager {
    public typealias Definition = String
    
    var _dic: [String: String] = [:]
    
    public init() {}
    
    public mutating func add(key: String, value: Definition) {
        if _dic[key] == nil {
            _dic[key] = value
        }
    }
    public func definition(for key: String) -> String? {
        return _dic[key]
    }
}

public protocol ReferenceDefinitionProtocol {
    init(string: String)
}
extension String: ReferenceDefinitionProtocol {
    public init(string: String) { self = string }
}

public struct ParagraphBlock <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    public let text: [MarkdownInline<View, RefDef>]
}

public struct HeaderBlock <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    public let level: Int
    public let text: [MarkdownInline<View, RefDef>]
    public let markers: (Range<View.Index>, Range<View.Index>?)
}

public struct QuoteBlock <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    public let content: [MarkdownBlock<View, RefDef>]
    public let markers: [View.Index]
}

public struct MarkdownListItemBlock <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    public let marker: Range<View.Index>
    public let content: [MarkdownBlock<View, RefDef>]
}

public struct ListBlock <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    public let kind: MarkdownListKind
    public let items: [MarkdownListItemBlock<View, RefDef>]
}

public struct FenceBlock <View: BidirectionalCollection> {
    public let name: Range<View.Index>
    public let text: [Range<View.Index>]
    public let markers: (Range<View.Index>, Range<View.Index>?)
}

public struct CodeBlock <View: BidirectionalCollection> {
    public let text: [Range<View.Index>]
}

public struct ThematicBreakBlock <View: BidirectionalCollection> {
    public let marker: Range<View.Index>
}

public struct TextInline <View: BidirectionalCollection> {
    public let span: Range<View.Index>
}

public struct BreakInline <View: BidirectionalCollection> {
    public let span: Range<View.Index>
}

public struct ReferenceInline <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    public let kind: ReferenceKind
    public let title: [MarkdownInline<View, RefDef>]
    public let definition: RefDef
    public let markers: [Range<View.Index>]
}

public struct EmphasisInline <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    public let level: Int
    public let content: [MarkdownInline<View, RefDef>]
    public let markers: (Range<View.Index>, Range<View.Index>)
}

public struct MonospacedTextInline <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    public let content: [MarkdownInline<View, RefDef>]
    public let markers: (Range<View.Index>, Range<View.Index>)
}

public struct EscapingBackslashInline <View: BidirectionalCollection> {
    let index: View.Index
}

public indirect enum MarkdownInline <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    case text(TextInline<View>)
    case reference(ReferenceInline<View, RefDef>)
    case emphasis(EmphasisInline<View, RefDef>)
    case monospacedText(MonospacedTextInline<View, RefDef>)
    case escapingBackslash(EscapingBackslashInline<View>)
    case softbreak(BreakInline<View>)
    case hardbreak(BreakInline<View>)
}

public indirect enum MarkdownBlock <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    case paragraph(ParagraphBlock<View, RefDef>)
    case header(HeaderBlock<View, RefDef>)
    case quote(QuoteBlock<View, RefDef>)
    case list(ListBlock<View, RefDef>)
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

@_specialize(String.UTF16View, DefaultReferenceDefinitionsManager, UTF16MarkdownCodec)
@_specialize(Array<UInt8>, DefaultReferenceDefinitionsManager, UTF8MarkdownCodec)
public func parsedMarkdown <View, RefDefs, Codec> (source: View, referenceDefinitions: RefDefs, codec: Codec.Type) -> [MarkdownBlock<View, RefDefs.Definition>] where
    View: BidirectionalCollection,
    RefDefs: ReferenceDefinitionsManager,
    Codec: MarkdownParserCodec,
    View.Iterator.Element == Codec.CodeUnit,
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let parser = MarkdownParser<View, Codec, RefDefs>(view: source, referenceDefinitions: referenceDefinitions)
    return parser.finalAST()
}

extension MarkdownParser {

    /// Parse the collection and return the Abstract Syntax Tree
    /// describing the resulting Markdown document.
    fileprivate func finalAST() -> [MarkdownBlock<View, RefDef>] {
        parseBlocks()
        return blockTree.makeIterator().flatMap(makeFinalBlock(from:children:))
    }
    
    /// Return a MarkdownBlock from an instance of the internal BlockNode type.
    fileprivate func makeFinalBlock(from node: Block, children: TreeIterator<Block>?) -> MarkdownBlock<View, RefDef>? {
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
            let items = children?.map { (n, c) -> MarkdownListItemBlock<View, RefDef> in
                guard case .listItem(let i) = n else { return .init(marker: view.startIndex ..< view.startIndex, content: []) }
                return MarkdownListItemBlock<View, RefDef>(
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
    fileprivate func makeFinalInlineNodeTree(from tree: TreeIterator<Inline>) -> [MarkdownInline<View, RefDef>] {
        
        var nodes: [MarkdownInline<View, RefDef>] = []
        
        for (node, children) in tree {
            switch node {
            case .text(let t):
                switch t.kind {
                    
                case .hardbreak:
                    nodes.append(.hardbreak(BreakInline(span: t.start ..< t.end)))
                    
                case .softbreak:
                    nodes.append(.softbreak(BreakInline(span: t.start ..< t.end)))
                    
                case .text:
                    nodes.append(.text(Apodimark.TextInline(span: t.start ..< t.end)))
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
                
                case .escapingBackslash:
                    nodes.append(.escapingBackslash(.init(index: n.start)))
                }
            }
        }
        return nodes
    }
}


