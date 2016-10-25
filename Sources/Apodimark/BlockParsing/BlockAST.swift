
enum BlockNode <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    case paragraph(ParagraphNode<View>)
    case header(HeaderNode<View>)
    case quote(QuoteNode<View>)
    case listItem(ListItemNode<View>)
    case list(ListNode<View>)
    case fence(FenceNode<View>)
    case code(CodeNode<View>)
    case thematicBreak(ThematicBreakNode<View>)
    case referenceDefinition(ReferenceDefinitionNode<View, RefDef>)
}

final class ParagraphNode <View: BidirectionalCollection> {
    var text: [Range<View.Index>]
    var closed: Bool
    init(text: [Range<View.Index>]) {
        (self.text, self.closed) = (text, false)
    }
}

final class HeaderNode <View: BidirectionalCollection> {
    let markers: (Range<View.Index>, Range<View.Index>?)
    let text: Range<View.Index>
    let level: Int32
    
    init(markers: (Range<View.Index>, Range<View.Index>?), text: Range<View.Index>, level: Int32) {
        (self.markers, self.text, self.level) = (markers, text, level)
    }
}

final class QuoteNode <View: BidirectionalCollection> {
    var markers: [View.Index]
    var closed: Bool

    init(firstMarker: View.Index) {
        (self.markers, self.closed) = ([firstMarker], false)
    }
}

final class ListItemNode <View: BidirectionalCollection> {
    let markerSpan: Range<View.Index>
    
    init(markerSpan: Range<View.Index>) {
        self.markerSpan = markerSpan
    }
}

final class ListNode <View: BidirectionalCollection> {
    let kind: ListKind
    var state: ListState
    var minimumIndent: Int
    
    init(kind: ListKind, state: ListState) {
        self.kind = kind
        self.state = state
        self.minimumIndent = 0
    }
}

final class FenceNode <View: BidirectionalCollection> {
    typealias Indices = Range<View.Index>
    
    let kind: FenceKind
    var markers: (Indices, Indices?)
    let name: Indices
    var text: [Indices]
    let level: Int32
    let indent: Int
    var closed: Bool
    
    init(kind: FenceKind, startMarker: Indices, name: Indices, text: [Indices], level: Int32, indent: Int) {
        (self.kind, self.markers, self.name, self.text, self.level, self.indent, self.closed) = (kind, (startMarker, nil), name, text, level, indent, false)
    }
}

final class CodeNode <View: BidirectionalCollection> {
    var text: [Range<View.Index>]
    var trailingEmptyLines: [Range<View.Index>]
    
    init(text: [Range<View.Index>], trailingEmptyLines: [Range<View.Index>]) {
        (self.text, self.trailingEmptyLines) = (text, trailingEmptyLines)
    }
}

final class ThematicBreakNode <View: BidirectionalCollection> {
    let span: Range<View.Index>
    
    init(span: Range<View.Index>) {
        self.span = span
    }
}

final class ReferenceDefinitionNode <View: BidirectionalCollection, RefDef: ReferenceDefinitionProtocol> {
    let title: String
    let definition: RefDef
    
    init(title: String, definition: RefDef) {
        (self.title, self.definition) = (title, definition)
    }
}

extension MarkdownParser {
    
    private func appendStrand(line: Line, previousEnd: Int) {
        
        func append(_ block: Block) {
            blockTree.buffer.append(.init(data: block, end: previousEnd))
        }
        
        guard line.indent.level < TAB_INDENT else {
            var newLine = line
            newLine.indent.level -= TAB_INDENT
            restoreIndentInLine(&newLine)
            append(.code(.init(text: [newLine.indices], trailingEmptyLines: [])))
            return
        }
        
        switch line.kind {
        case .quote(let rest):
            append(.quote(.init(firstMarker: line.indices.lowerBound)))
            appendStrand(line: rest, previousEnd: previousEnd)
        
        case .text:
            append(.paragraph(.init(text: [line.indices])))
        
        case .header(let text, let level):
            let startHashes = line.indices.lowerBound ..< view.index(line.indices.lowerBound, offsetBy: numericCast(level))
            let endHashes: Range<View.Index>? = {
                let tmp = text.upperBound ..< line.indices.upperBound
                return tmp.isEmpty ? nil : tmp
            }()
            append(.header(.init(markers: (startHashes, endHashes), text: text, level: level)))
        
        case let .list(kind, rest):
            let state: ListState = rest.kind.isEmpty() ? .followedByEmptyLine : .normal
            
            let markerSpan = line.indices.lowerBound ..< view.index(line.indices.lowerBound, offsetBy: numericCast(kind.width))
            
            let list = ListNode<View>(kind: kind, state: state)
            let item = ListItemNode<View>(markerSpan: markerSpan)
            
            append(.list(list))
            append(.listItem(item))

            list.minimumIndent = line.indent.level + kind.width + rest.indent.level + 1
            
            guard !rest.kind.isEmpty() else {
                return
            }
            
            let nextNodeIdx = blockTree.buffer.endIndex
            appendStrand(line: rest, previousEnd: previousEnd)

            if case .code = blockTree.buffer[nextNodeIdx].data {
                list.minimumIndent = line.indent.level + kind.width + 1
            }
            
        case let .fence(kind, name, level):
            let startMarker = line.indices.lowerBound ..< view.index(line.indices.lowerBound, offsetBy: numericCast(level))
            append(.fence(.init(kind: kind, startMarker: startMarker, name: name, text: [], level: level, indent: line.indent.level)))

        case .thematicBreak:
            append(.thematicBreak(.init(span: line.indices)))
            
        case .empty:
            append(.paragraph(.init(text: [])))
            
        case let .reference(title, definition):
            append(.referenceDefinition(.init(title: title, definition: definition)))
        }
    }

    func appendStrand(from line: Line, level: DepthLevel) {
        let prevCount = blockTree.buffer.count
        appendStrand(line: line, previousEnd: prevCount-1)
        let curCount = blockTree.buffer.count
        blockTree.repairStructure(addedStrandLength: prevCount.distance(to: curCount), level: level)
    }
}


