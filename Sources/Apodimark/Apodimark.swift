//
//  Apodimark.swift
//  Apodimark
//

import Foundation

public protocol ReferenceDefinition { }
extension String: ReferenceDefinition { }

public enum MarkdownListKind: CustomStringConvertible {

    case unordered
    case ordered(startingAt: Int)

    private init(kind: ListKind) {
        switch kind {

        case .bullet(_):
            self = .unordered

        case .number(_, let n):
            self = .ordered(startingAt: n)
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

public enum MarkdownInline <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {
    case text(View.SubSequence)
    case reference(kind: ReferenceKind, title: [MarkdownInline], definition: ReferenceDefinition)
    case emphasis(level: Int, content: [MarkdownInline])
    case monospacedText([MarkdownInline])
    case softbreak
    case hardbreak
}

extension MarkdownParser {

    func createFinalInlineNode(from node: InlineNode<View>) -> MarkdownInline<View> {
        switch node.kind {

        case .hardbreak:
            return .hardbreak

        case .softbreak:
            return .softbreak

        case .text:
            return .text(view[node.contentRange(inView: view)])

        case .code(_):
            let children = node.children.map(createFinalInlineNode)
            return .monospacedText(children)

        case .emphasis(let level):
            return .emphasis(level: level, content: node.children.map(createFinalInlineNode))

        case .reference(let kind, title: _, definition: let definition):
            return .reference(kind: kind, title: node.children.map(createFinalInlineNode), definition: definition)
        }
    }
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
    case fence(name: String, text: [View.SubSequence])
    case code(text: [View.SubSequence])
    case thematicBreak
}

extension MarkdownParser {

    func createFinalBlock(from node: BlockNode<View>) -> MarkdownBlock<View>? {
        switch node {

        case .paragraph(text: let text, _):
            let scanners = text.map { Scanner<View>(view: view, startIndex: $0.lowerBound, endIndex: $0.upperBound) }
            return .paragraph(text: processInlines(scanners: scanners).map(createFinalInlineNode))


        case .header(text: let text, level: let level):
            let scanner = Scanner<View>(view: view, startIndex: text.lowerBound, endIndex: text.upperBound)
            return .header(level: level, text: processInlines(scanners: [scanner]).map(createFinalInlineNode))


        case .quote(content: let content, _):
            return .quote(content: content.flatMap(createFinalBlock))


        case .list(kind: let kind, _, _, items: let items):
            return .list(kind: MarkdownListKind(kind: kind), items: items.map { $0.flatMap(createFinalBlock) })


        case .code(text: let text, _):
            return .code(text: text.map { view[$0] })


        case .fence(_, name: let name, text: let text, _, _, _):
            let finalName: String
            if let nameIndices = name {
                finalName = Token.string(fromTokens: view[nameIndices])
            } else {
                finalName = ""
            }
            return .fence(name: finalName, text: text.map { view[$0] })


        case .thematicBreak:
            return .thematicBreak


        case .referenceDefinition:
            return nil
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
