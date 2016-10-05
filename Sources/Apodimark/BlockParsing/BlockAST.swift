//
//  BlockAST.swift
//  Apodimark
//

enum ListState {
    case normal, followedByEmptyLine, closed
}

enum AddLineResult {
    case success
    case failure
}

class BlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Indices = Range<View.Index>
    
    func add(line: Line<View>) -> AddLineResult { fatalError() }
    func allowsLazyContinuation() -> Bool { fatalError() }
}

final class ParagraphBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    var text: [Indices]
    var closed: Bool
    init(text: [Indices]) {
        (self.text, self.closed) = (text, false)
    }
    
    override func add(line: Line<View>) -> AddLineResult {
        guard !closed else { return .failure }
        switch line.kind {
        case .text, .reference:
            text.append(line.scanner.indices)
            
        case .empty:
            closed = true
            
        default:
            guard line.indent.level >= 4 else { return .failure }
            var line = line
            line.removeFirstIndents(4)
            text.append(line.scanner.indices)
        }
        return .success
    }
    override func allowsLazyContinuation() -> Bool {
        return !closed
    }
}

final class HeaderBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let markers: (Indices, Indices?)
    let text: Indices
    let level: Int
    init(markers: (Indices, Indices?), text: Indices, level: Int) {
        (self.markers, self.text, self.level) = (markers, text, level)
    }
    override func add(line: Line<View>) -> AddLineResult {
        return .failure
    }
    override func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class QuoteBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    var markers: [View.Index]
    var content: [BlockNode<View>]
    
    var _allowsLazyContinuation: Bool
    
    var closed: Bool
    
    init(firstMarker: View.Index, firstNode: BlockNode<View>) {
        (self.markers, self.content, self.closed, self._allowsLazyContinuation) = ([firstMarker], [firstNode], false, firstNode.allowsLazyContinuation())
    }
    
    fileprivate func directlyAddLine(line: Line<View>) {
        let last = content.last! // content is never empty because initializer must provide "firstNode"
        if case .success = last.add(line: line) {
            _allowsLazyContinuation = last.allowsLazyContinuation()
        } else {
            if !line.kind.isEmpty() {
                let newNode = line.node()
                content.append(newNode)
                _allowsLazyContinuation = newNode.allowsLazyContinuation()
            }
        }
    }
    
    override func add(line: Line<View>) -> AddLineResult {
        guard !closed else { return .failure }

        guard !(line.indent.level >= 4 && _allowsLazyContinuation) else {
            directlyAddLine(line: Line(.text, line.indent, line.scanner))
            return .success
        }
        
        switch line.kind {
            
        case .empty:
            closed = true
            _allowsLazyContinuation = false
            
        case .quote(let rest):
            markers.append(line.scanner.startIndex)
            directlyAddLine(line: rest)
            
        case .text:
            guard _allowsLazyContinuation else {
                return .failure
            }
            directlyAddLine(line: line)
            
        default:
            return .failure
        }
        return .success
    }
    override func allowsLazyContinuation() -> Bool {
        return _allowsLazyContinuation
    }
}

final class ListItemBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let markerSpan: Range<View.Index>
    var content: [BlockNode<View>]

    init(markerSpan: Range<View.Index>, content: [BlockNode<View>]) {
        (self.markerSpan, self.content) = (markerSpan, content)
    }
}

final class ListBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let kind: ListKind
    var items: [ListItemBlockNode<View>]
    
    var _allowsLazyContinuations: Bool
    
    fileprivate var state: ListState
    fileprivate var minimumIndent: Int
    
    init(kind: ListKind, items: [ListItemBlockNode<View>], state: ListState, minimumIndent: Int) {
        self.kind = kind
        self.items = items
        self.state = state
        self.minimumIndent = minimumIndent
        self._allowsLazyContinuations = items.last?.content.last?.allowsLazyContinuation() ?? true
    }
    
    fileprivate func preparedLine(from initialLine: Line<View>) -> Line<View>? {
        guard state != .closed else {
            return nil
        }
        var line = initialLine
        guard !initialLine.kind.isEmpty() else {
            return line
        }
        guard !(initialLine.indent.level >= minimumIndent + 4 && allowsLazyContinuation()) else {
            line.removeFirstIndents(minimumIndent)
            return line
        }
        
        line.removeFirstIndents(minimumIndent)
        let isWellIndented = line.indent.level >= 0
        
        switch line.kind {
            
        case .text:
            return isWellIndented || (state == .normal && allowsLazyContinuation()) ? line : nil
            
        case let .list(k, _):
            if isWellIndented {
                return line
            }
            else {
                return k ~= kind ? line : nil
            }
            
        case .quote, .header, .fence, .reference:
            return isWellIndented ? line : nil
            
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
                _allowsLazyContinuations = false
                return
            }

            guard let lastItem = items.last, let lastItemContent = lastItem.content.last else {
                return
            }
            state = .followedByEmptyLine
            
            _ = lastItemContent.add(line: preparedLine)
            _allowsLazyContinuations = lastItemContent.allowsLazyContinuation()
            
        case .list(let marker, let rest) where preparedLine.indent.level < 0:
            state = .normal
            minimumIndent += preparedLine.indent.level + marker.width + 1
            
            let (item, newAllowsLazyContinuations): (ListItemBlockNode<View>, Bool) = {
                let sc = preparedLine.scanner
                let markerSpan = sc.startIndex ..< sc.data.index(sc.startIndex, offsetBy: View.IndexDistance(marker.width.toIntMax()))
                
                guard !rest.kind.isEmpty() else {
                    return (ListItemBlockNode(markerSpan: markerSpan, content: []), true)
                }
                let node = rest.node()
                return (ListItemBlockNode(markerSpan: markerSpan, content: [node]), node.allowsLazyContinuation())
            }()
            _allowsLazyContinuations = newAllowsLazyContinuations
            items.append(item)
            
        default:
            state = .normal
            let lastItem = items.last!
    
            if case .failure = lastItem.content.last?.add(line: preparedLine) ?? .failure {
                let node = preparedLine.node()
                lastItem.content.append(node)
                _allowsLazyContinuations = node.allowsLazyContinuation()
            }
        }
    }
    
    override func add(line: Line<View>) -> AddLineResult {
        guard let line = preparedLine(from: line) else {
            return .failure
        }
        addPreparedLine(line)
        return .success
    }
    
    override func allowsLazyContinuation() -> Bool {
        return _allowsLazyContinuations
        //return items.last?.content.last?.allowsLazyContinuation() ?? true
    }
}

final class FenceBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.SubSequence: BidirectionalCollection,
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
    
    override func add(line: Line<View>) -> AddLineResult {
        
        guard line.indent.level >= 0 && !closed else {
            return .failure
        }
        var line = line
        line.removeFirstIndents(indent)
        line.restoreIndentInScanner()
        
        switch line.kind {
            
        case .fence(kind, let lineFenceName, let lineFenceLevel) where line.indent.level < 4 && lineFenceName.isEmpty && lineFenceLevel >= level:
            markers.1 = line.scanner.indices
            closed = true
            
        default:
            text.append(line.scanner.indices)
        }
        return .success
    }
    override func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class CodeBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    var text: [Indices]
    var trailingEmptyLines: [Indices]
    
    init(text: [Indices], trailingEmptyLines: [Indices]) {
        (self.text, self.trailingEmptyLines) = (text, trailingEmptyLines)
    }
    
    override func add(line: Line<View>) -> AddLineResult {
        switch line.kind {
            
        case .empty:
            var line = line
            line.removeFirstIndents(4)
            line.restoreIndentInScanner()
            trailingEmptyLines.append(line.scanner.indices)
            
        case _ where line.indent.level >= 4:
            var line = line
            line.removeFirstIndents(4)
            line.restoreIndentInScanner()

            text.append(contentsOf: trailingEmptyLines)
            text.append(line.scanner.indices)
            trailingEmptyLines.removeAll()
            
        default:
            return .failure
        }
        return .success
    }
    override func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class ThematicBreakBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let span: Indices
    init(span: Indices) {
        self.span = span
    }
    override func add(line: Line<View>) -> AddLineResult {
        return .failure
    }
    override func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class ReferenceDefinitionBlockNode <View: BidirectionalCollection>: BlockNode<View> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let title: String
    let definition: ReferenceDefinition
    init(title: String, definition: ReferenceDefinition) {
        (self.title, self.definition) = (title, definition)
    }
    
    override func add(line: Line<View>) -> AddLineResult {
        return .failure
    }
    override func allowsLazyContinuation() -> Bool {
        return false
    }
}

extension Line {
    func node() -> BlockNode<View> {
        guard indent.level < 4 else {
            var newLine = self
            newLine.removeFirstIndents(4)
            newLine.restoreIndentInScanner()
            return CodeBlockNode(text: [newLine.scanner.indices], trailingEmptyLines: [])
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




