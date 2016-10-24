//
//  ProcessText.swift
//  Apodimark
//

struct TextInlineNodeIterator <View: BidirectionalCollection> : IteratorProtocol {
    
    typealias Delimiter = (idx: View.Index, kind: TextDelimiterKind)
    
    let view: View
    let delimiters: [Delimiter?]

    var startViewIndex: View.Index
    var i: Int
    
    init(view: View, delimiters: [Delimiter?]) {
        self.view = view
        self.delimiters = delimiters
        self.i = delimiters.startIndex
        
        self.startViewIndex = view.startIndex // invalid, but does not matter
    }
    
    mutating func next() -> TextInlineNode<View>? {
        
        while i < delimiters.endIndex {
            defer { i += 1 }
            guard case let del? = delimiters[i] else { continue }

            switch del.kind {
            case .start:
                startViewIndex = del.idx
                
            case .end:
                defer { startViewIndex = del.idx }
                return TextInlineNode(kind: .text, start: startViewIndex, end: del.idx)
                
            case .softbreak:
                defer { startViewIndex = del.idx }
                return TextInlineNode(kind: .softbreak, start: startViewIndex, end: del.idx)
                
            case .hardbreak:
                defer { startViewIndex = del.idx }
                return TextInlineNode(kind: .hardbreak, start: startViewIndex, end: del.idx)
            }
        }
        return nil
    }
}
