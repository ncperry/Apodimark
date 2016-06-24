//
//  Apodimark.swift
//  Apodimark
//

public protocol ReferenceDefinition { }
extension String: ReferenceDefinition { }

/*
 TODO: make MarkdownInline and MarkdownBlock structs that
        hold (1) range of indices (2) "Kind" enum similar to these
*/

public enum MarkdownInline <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {
    case text(Range<View.Index>)
    case reference(kind: ReferenceKind, title: [MarkdownInline], definition: ReferenceDefinition)
    case emphasis(level: Int, content: [MarkdownInline])
    case monospacedText([MarkdownInline])
    case softbreak
    case hardbreak
}

public enum MarkdownBlock <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
>  {
    case paragraph(text: [MarkdownInline<View>])
    case header(level: Int, text: [MarkdownInline<View>])
    case quote(content: [MarkdownBlock<View>])
    case list(kind: MarkdownListKind, items: [[MarkdownBlock<View>]])
    case fence(name: String, text: [Range<View.Index>])
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

public func parsedMarkdown <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> (source: View) -> [MarkdownBlock<View>] {

    return MarkdownParser(view: source).finalAST()
}

public func parsedMarkdown(source: String.UTF16View) -> [MarkdownBlock<String.UTF16View>] {
    return MarkdownParser(view: source).finalAST()
}

/*
public func parsedMarkdown(source: UnsafeBufferPointer<UTF16.CodeUnit>) -> [MarkdownBlock<UnsafeBufferPointer<UTF16.CodeUnit>>] {
    return MarkdownParser(view: source).finalAST()
}

public func parsedMarkdown(source: [UTF16.CodeUnit]) -> [MarkdownBlock<[UTF16.CodeUnit]>] {
    return MarkdownParser(view: source).finalAST()
}

public func parsedMarkdown(source: Data) -> [MarkdownBlock<Data>] {
    return MarkdownParser(view: source).finalAST()
}
*/

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
            return .hardbreak

        case .softbreak:
            return .softbreak

        case .text:
            return .text(node.contentRange(inView: view))

        case .code(_):
            let children = node.children.map(makeFinalInlineNode)
            return .monospacedText(children)

        case .emphasis(let level):
            return .emphasis(level: level, content: node.children.map(makeFinalInlineNode))

        case .reference(let kind, title: _, definition: let definition):
            return .reference(kind: kind, title: node.children.map(makeFinalInlineNode), definition: definition)
        }
    }

    /// Return a MarkdownBlock from an instance of the internal BlockNode type.
    private func makeFinalBlock(from node: BlockNode<View>) -> MarkdownBlock<View>? {
        switch node {

        case .paragraph(text: let text, _):
            return .paragraph(text: parseInlines(text: text.data).map(makeFinalInlineNode))


        case .header(text: let text, level: let level):
            return .header(level: level, text: parseInlines(text: [text]).map(makeFinalInlineNode))


        case .quote(content: let content, _):
            return .quote(content: content.data.flatMap(makeFinalBlock))


        case .list(kind: let kind, _, _, items: let items):
            return .list(kind: MarkdownListKind(kind: kind), items: items.data.map { $0.flatMap(makeFinalBlock) })


        case .code(text: let text, _):
            return .code(text: text.data)


        case .fence(_, name: let name, text: let text, _, _, _):
            let finalName: String
            if let nameIndices = name {
                finalName = Token.string(fromTokens: view[nameIndices])
            } else {
                finalName = ""
            }
            return .fence(name: finalName, text: text.data)
            
            
        case .thematicBreak:
            return .thematicBreak
            
            
        case .referenceDefinition:
            return nil
        }
    }
}
