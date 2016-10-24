//
//  ProcessEscapingBackslashes.swift
//  Apodimark
//


extension MarkdownParser {

    func processAllEscapingBackslashes(_ delimiters: [NonTextDelimiter?], appendingTo nodes: inout [NonTextInlineNode<View>]) {
        for case let del? in delimiters {
            if case .ignored = del.kind {
                nodes.append(.init(
                    kind: .escapingBackslash,
                    start: view.index(before: del.idx),
                    end: del.idx
                ))
            }
        }
    }
}

