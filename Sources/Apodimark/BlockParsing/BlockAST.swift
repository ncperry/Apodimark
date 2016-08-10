//
//  BlockAST.swift
//  Apodimark
//

enum ListState {
    case normal, followedByEmptyLine, closed
}

class BlockNode <View: BidirectionalCollection> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Indices = Range<View.Index>
    
    func add(line: Line<View>) -> Bool { fatalError() }
    func allowsLazyContinuation() -> Bool { fatalError() }
}

final class ParagraphBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    var text: [Indices]
    var closed: Bool
    init(text: [Indices]) {
        (self.text, self.closed) = (text, false)
    }
    
    override func add(line: Line<View>) -> Bool {
        guard !closed else { return false }
        switch line.kind {
        case .text, .reference:
            text.append(line.scanner.indices)
            
        case .empty:
            closed = true
            
        default:
            guard line.indent.level >= 4 else { return false }
            text.append(line.removingFirstIndents(n: 4).scanner.indices)
        }
        return true
    }
    override func allowsLazyContinuation() -> Bool {
        return !closed
    }
}

final class HeaderBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let markers: (Indices, Indices?)
    let text: Indices
    let level: Int
    init(markers: (Indices, Indices?), text: Indices, level: Int) {
        (self.markers, self.text, self.level) = (markers, text, level)
    }
    override func add(line: Line<View>) -> Bool {
        return false
    }
    override func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class QuoteBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    var markers: [View.Index]
    var content: [BlockNode<View>]
    var closed: Bool
    
    init(firstMarker: View.Index, firstNode: BlockNode<View>) {
        (self.markers, self.content, self.closed) = ([firstMarker], [firstNode], false)
    }
    
    fileprivate func directlyAddLine(line: Line<View>) {
        if let last = content.last, last.add(line: line) == false && !line.kind.isEmpty() {
            content.append(line.node())
        }
    }
    
    override func add(line: Line<View>) -> Bool {
        guard !closed else { return false }
        let lazyContinuationIsPossible = self.allowsLazyContinuation()
        guard !(line.indent.level >= 4 && lazyContinuationIsPossible) else {
            let line = Line(.text, line.indent, line.scanner)
            directlyAddLine(line: line)
            return true
        }
        
        switch line.kind {
            
        case .empty:
            closed = true
            
        case .quote(let rest):
            markers.append(line.scanner.startIndex)
            directlyAddLine(line: rest)
            
        case .text:
            guard lazyContinuationIsPossible else {
                return false
            }
            directlyAddLine(line: line)
            
        default:
            return false
        }
        return true
    }
    override func allowsLazyContinuation() -> Bool {
        return !closed && (content.last?.allowsLazyContinuation() ?? true)
    }
}

final class ListItemBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let markerSpan: Range<View.Index>
    var content: [BlockNode<View>]

    init(markerSpan: Range<View.Index>, content: [BlockNode<View>]) {
        (self.markerSpan, self.content) = (markerSpan, content)
    }
    
    
}

final class ListBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let kind: ListKind
    var items: [ListItemBlockNode<View>]
    fileprivate var state: ListState
    fileprivate var minimumIndent: Int
    
    init(kind: ListKind, items: [ListItemBlockNode<View>], state: ListState, minimumIndent: Int) {
        (self.kind, self.items, self.state, self.minimumIndent) = (kind, items, state, minimumIndent)
    }
    
    fileprivate func preparedLine(from initialLine: Line<View>) -> Line<View>? {
        guard state != .closed else {
            return nil
        }
        guard !initialLine.kind.isEmpty() else {
            return initialLine
        }
        guard !(initialLine.indent.level >= minimumIndent + 4 && allowsLazyContinuation()) else {
            return initialLine.removingFirstIndents(n: minimumIndent)
        }
        
        let lineWithoutIndent = initialLine.removingFirstIndents(n: minimumIndent)
        let isWellIndented = lineWithoutIndent.indent.level >= 0
        
        switch lineWithoutIndent.kind {
            
        case .text:
            return isWellIndented || (state == .normal && allowsLazyContinuation()) ? lineWithoutIndent : nil
            
        case let .list(k, _):
            if isWellIndented {
                return lineWithoutIndent
            }
            else {
                return k ~= kind ? lineWithoutIndent : nil
            }
            
        case .quote, .header, .fence, .reference:
            return isWellIndented ? lineWithoutIndent : nil
            
        default:
            return nil
        }
    }
    
    fileprivate func addPreparedLine(_ preparedLine: Line<View>) {
        switch preparedLine.kind {
            
        case .empty:
            var shallowestNonListChild: BlockNode? = items.last?.content.last
            while case let nextList as ListBlockNode = shallowestNonListChild {
                shallowestNonListChild = nextList.items.last?.content.last
            }
            
            guard self.state == .normal || (shallowestNonListChild is FenceBlockNode) else {
                self.state = .closed
                return
            }
            guard !items.isEmpty && !(items.last!.content.isEmpty) else {
                return
            }
            state = .followedByEmptyLine
            
            _ = items.last?.content.last?.add(line: preparedLine)

        case .list(let marker, let rest) where preparedLine.indent.level < 0:
            state = .normal
            minimumIndent += preparedLine.indent.level + marker.width + 1
            
            let item: ListItemBlockNode<View>
            let markerSpan = preparedLine.scanner.startIndex ..< preparedLine.scanner.data.index(preparedLine.scanner.startIndex, offsetBy: View.IndexDistance(marker.width.toIntMax()))
            if rest.kind.isEmpty() {
                item = ListItemBlockNode(markerSpan: markerSpan, content: [])
            } else {
                item = ListItemBlockNode(markerSpan: markerSpan, content: [rest.node()])
            }
            items.append(item)
            
        default:
            state = .normal
            let lastItem = items.last!
            if lastItem.content.isEmpty || !items.last!.content.last!.add(line: preparedLine) {
                lastItem.content.append(preparedLine.node())
            }
        }
    }
    
    override func add(line: Line<View>) -> Bool {
        guard let line = preparedLine(from: line) else { return false }
        addPreparedLine(line)
        return true
    }
    
    override func allowsLazyContinuation() -> Bool {
        return items.last?.content.last?.allowsLazyContinuation() ?? true
    }
}

final class FenceBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let kind: FenceKind
    var markers: (Indices, Indices?)
    let name: Indices
    var text: [Indices]
    let level: Int
    let indent: Int
    var closed: Bool
    
    init (kind: FenceKind, startMarker: Indices, name: Indices, text: [Indices], level: Int, indent: Int) {
        (self.kind, self.markers, self.name, self.text, self.level, self.indent, self.closed) = (kind, (startMarker, nil), name, text, level, indent, false)
    }
    
    override func add(line: Line<View>) -> Bool {
        
        guard line.indent.level >= 0 && !closed else {
            return false
        }
        
        let line = line.removingFirstIndents(n: indent).restoringIndentInSubview()
        
        switch line.kind {
            
        case .fence(kind, let lineFenceName, let lineFenceLevel) where line.indent.level < 4 && lineFenceName.isEmpty && lineFenceLevel >= level:
            markers.1 = line.scanner.indices
            closed = true
            
        default:
            text.append(line.scanner.indices)
        }
        return true
    }
    override func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class CodeBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    var text: [Indices]
    var trailingEmptyLines: [Indices]
    
    init(text: [Indices], trailingEmptyLines: [Indices]) {
        (self.text, self.trailingEmptyLines) = (text, trailingEmptyLines)
    }
    
    override func add(line: Line<View>) -> Bool {
        switch line.kind {
            
        case .empty:
            let line = line.removingFirstIndents(n: 4).restoringIndentInSubview()
            trailingEmptyLines.append(line.scanner.indices)
            
        case _ where line.indent.level >= 4:
            let line = line.removingFirstIndents(n: 4).restoringIndentInSubview()
            text.append(contentsOf: trailingEmptyLines)
            text.append(line.scanner.indices)
            trailingEmptyLines.removeAll()
            
        default:
            return false
        }
        return true
    }
    override func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class ThematicBreakBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let span: Indices
    init(span: Indices) {
        self.span = span
    }
    override func add(line: Line<View>) -> Bool {
        return false
    }
    override func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class ReferenceDefinitionBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let title: String
    let definition: ReferenceDefinition
    init(title: String, definition: ReferenceDefinition) {
        (self.title, self.definition) = (title, definition)
    }
    
    override func add(line: Line<View>) -> Bool {
        return false
    }
    override func allowsLazyContinuation() -> Bool {
        return false
    }
}

extension Line {
    func node() -> BlockNode<View> {
        guard indent.level < 4 else {
            let newline = self.removingFirstIndents(n: 4).restoringIndentInSubview()
            return CodeBlockNode(text: [newline.scanner.indices], trailingEmptyLines: [])
        }
        
        switch kind {
            
        case .text:
            return ParagraphBlockNode(text: [scanner.indices])
            
        case let .list(kind, rest):
            let state: ListState = rest.kind.isEmpty() ? .followedByEmptyLine : .normal
            
            let item: ListItemBlockNode<View>
            let markerSpan = scanner.startIndex ..< scanner.data.index(scanner.startIndex, offsetBy: View.IndexDistance(kind.width.toIntMax()))
            if rest.kind.isEmpty() {
                item = ListItemBlockNode(markerSpan: markerSpan, content: [])
            } else {
                item = ListItemBlockNode(markerSpan: markerSpan, content: [rest.node()])
            }
            
            let minimumIndent: Int
            if item.content.last is CodeBlockNode {
                minimumIndent = indent.level + kind.width + 1
            } else {
                minimumIndent = indent.level + kind.width + rest.indent.level + 1
            }
            return ListBlockNode(kind: kind, items: [item], state: state, minimumIndent: minimumIndent)
            
            
        case .header(let text, let level):
            let startHashes = scanner.startIndex ..< scanner.data.index(scanner.startIndex, offsetBy: View.IndexDistance(level.toIntMax()))
            let endHashes: Range<View.Index>? = {
                let tmp = text.upperBound ..< scanner.endIndex
                return tmp.isEmpty ? nil : tmp
            }()
            return HeaderBlockNode(markers: (startHashes, endHashes), text: text, level: level)
            
        case .quote(let rest):
            return QuoteBlockNode(firstMarker: scanner.startIndex, firstNode: rest.node())
            
        case let .fence(kind, name, level):
            let startMarker = scanner.startIndex ..< scanner.data.index(scanner.startIndex, offsetBy: View.IndexDistance(level.toIntMax()))
            return FenceBlockNode(kind: kind, startMarker: startMarker, name: name, text: [], level: level, indent: indent.level)
            
        case .thematicBreak:
            return ThematicBreakBlockNode(span: scanner.indices)
            
        case .empty:
            return ParagraphBlockNode(text: [])
            
        case let .reference(title, definition):
            return ReferenceDefinitionBlockNode(title: title, definition: definition)
        }
    }
}




