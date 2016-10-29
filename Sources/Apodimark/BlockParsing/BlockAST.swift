
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
    let title: Range<View.Index>
    let definition: Range<View.Index>
    
    init(title: Range<View.Index>, definition: Range<View.Index>) {
        (self.title, self.definition) = (title, definition)
    }
}

