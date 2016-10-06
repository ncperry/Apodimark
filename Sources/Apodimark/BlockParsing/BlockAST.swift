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

// This is an enum because using a protocol is not possible and using a class is too slow.
enum BlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    case paragraph(ParagraphBlockNode<View>)
    case header(HeaderBlockNode<View>)
    case quote(QuoteBlockNode<View>)
    case list(ListBlockNode<View>)
    case fence(FenceBlockNode<View>)
    case code(CodeBlockNode<View>)
    case thematicBreak(ThematicBreakBlockNode<View>)
    case referenceDefinition(ReferenceDefinitionBlockNode<View>)

    func add(line: Line<View>) -> AddLineResult {
        switch self {
        case .paragraph(let x):
            return x.add(line: line)
        case .header(let x):
            return x.add(line: line)
        case .quote(let x):
            return x.add(line: line)
        case .list(let x):
            return x.add(line: line)
        case .fence(let x):
            return x.add(line: line)
        case .code(let x):
            return x.add(line: line)
        case .thematicBreak(let x):
            return x.add(line: line)
        case .referenceDefinition(let x):
            return x.add(line: line)
        }
    }
    func allowsLazyContinuation() -> Bool {
        switch self {
        case .paragraph(let x):
            return x.allowsLazyContinuation()
        case .header(let x):
            return x.allowsLazyContinuation()
        case .quote(let x):
            return x.allowsLazyContinuation()
        case .list(let x):
            return x.allowsLazyContinuation()
        case .fence(let x):
            return x.allowsLazyContinuation()
        case .code(let x):
            return x.allowsLazyContinuation()
        case .thematicBreak(let x):
            return x.allowsLazyContinuation()
        case .referenceDefinition(let x):
            return x.allowsLazyContinuation()
        }
    }
}

final class ParagraphBlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Indices = Range<View.Index>
    
    var text: [Indices]
    var closed: Bool
    init(text: [Indices]) {
        (self.text, self.closed) = (text, false)
    }
    
    func add(line: Line<View>) -> AddLineResult {
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
    func allowsLazyContinuation() -> Bool {
        return !closed
    }
}

final class HeaderBlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Indices = Range<View.Index>
    
    let markers: (Indices, Indices?)
    let text: Indices
    let level: View.IndexDistance
    init(markers: (Indices, Indices?), text: Indices, level: View.IndexDistance) {
        (self.markers, self.text, self.level) = (markers, text, level)
    }
    func add(line: Line<View>) -> AddLineResult {
        return .failure
    }
    func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class QuoteBlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Indices = Range<View.Index>

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
    
    func add(line: Line<View>) -> AddLineResult {
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
    func allowsLazyContinuation() -> Bool {
        return _allowsLazyContinuation
    }
}

final class ListItemBlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let markerSpan: Range<View.Index>
    var content: [BlockNode<View>]

    init(markerSpan: Range<View.Index>, content: [BlockNode<View>]) {
        (self.markerSpan, self.content) = (markerSpan, content)
    }
}

final class ListBlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Indices = Range<View.Index>
    
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
            while case .list(let nextList)? = shallowestNonListChild {
                shallowestNonListChild = nextList.items.last?.content.last
            }
            
            if self.state != .normal {
                guard case .fence? = shallowestNonListChild else {
                    self.state = .closed
                    _allowsLazyContinuations = false
                    return
                }
            }
            /*
            guard self.state == .normal || (shallowestNonListChild is FenceBlockNode) else {
                self.state = .closed
                _allowsLazyContinuations = false
                return
            }*/

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
    
    func add(line: Line<View>) -> AddLineResult {
        guard let line = preparedLine(from: line) else {
            return .failure
        }
        addPreparedLine(line)
        return .success
    }
    
    func allowsLazyContinuation() -> Bool {
        return _allowsLazyContinuations
        //return items.last?.content.last?.allowsLazyContinuation() ?? true
    }
}

final class FenceBlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Indices = Range<View.Index>
    
    let kind: FenceKind
    var markers: (Indices, Indices?)
    let name: Indices
    var text: [Indices]
    let level: View.IndexDistance
    let indent: Int
    var closed: Bool
    
    init (kind: FenceKind, startMarker: Indices, name: Indices, text: [Indices], level: View.IndexDistance, indent: Int) {
        (self.kind, self.markers, self.name, self.text, self.level, self.indent, self.closed) = (kind, (startMarker, nil), name, text, level, indent, false)
    }
    
    func add(line: Line<View>) -> AddLineResult {
        
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
    func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class CodeBlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Indices = Range<View.Index>
    
    var text: [Indices]
    var trailingEmptyLines: [Indices]
    
    init(text: [Indices], trailingEmptyLines: [Indices]) {
        (self.text, self.trailingEmptyLines) = (text, trailingEmptyLines)
    }
    
    func add(line: Line<View>) -> AddLineResult {
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
    func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class ThematicBreakBlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Indices = Range<View.Index>
    
    let span: Indices
    init(span: Indices) {
        self.span = span
    }
    func add(line: Line<View>) -> AddLineResult {
        return .failure
    }
    func allowsLazyContinuation() -> Bool {
        return false
    }
}

final class ReferenceDefinitionBlockNode <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    typealias Indices = Range<View.Index>
    
    let title: String
    let definition: ReferenceDefinition
    init(title: String, definition: ReferenceDefinition) {
        (self.title, self.definition) = (title, definition)
    }
    
    func add(line: Line<View>) -> AddLineResult {
        return .failure
    }
    func allowsLazyContinuation() -> Bool {
        return false
    }
}

extension Line {
    func node() -> BlockNode<View> {
        guard indent.level < 4 else {
            var newLine = self
            newLine.removeFirstIndents(4)
            newLine.restoreIndentInScanner()
            return .code(.init(text: [newLine.scanner.indices], trailingEmptyLines: []))
        }
        
        switch kind {
            
        case .text:
            return .paragraph(.init(text: [scanner.indices]))
            
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
            if case .code? = item.content.last {
                minimumIndent = indent.level + kind.width + 1
            } else {
                minimumIndent = indent.level + kind.width + rest.indent.level + 1
            }
            return .list(.init(kind: kind, items: [item], state: state, minimumIndent: minimumIndent))
            
            
        case .header(let text, let level):
            let startHashes = scanner.startIndex ..< scanner.data.index(scanner.startIndex, offsetBy: level)
            let endHashes: Range<View.Index>? = {
                let tmp = text.upperBound ..< scanner.endIndex
                return tmp.isEmpty ? nil : tmp
            }()
            return .header(.init(markers: (startHashes, endHashes), text: text, level: level))
            
        case .quote(let rest):
            return .quote(.init(firstMarker: scanner.startIndex, firstNode: rest.node()))
            
        case let .fence(kind, name, level):
            let startMarker = scanner.startIndex ..< scanner.data.index(scanner.startIndex, offsetBy: level)
            return .fence(.init(kind: kind, startMarker: startMarker, name: name, text: [], level: level, indent: indent.level))
            
        case .thematicBreak:
            return .thematicBreak(.init(span: scanner.indices))
            
        case .empty:
            return .paragraph(.init(text: []))
            
        case let .reference(title, definition):
            return .referenceDefinition(.init(title: title, definition: definition))
        }
    }
}




