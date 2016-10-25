//
//  ProcessEscapingBackslashes.swift
//  Apodimark
//

extension MarkdownParser {

    func processAllEscapingBackslashes(_ delimiters: [NonTextDelimiter?], appendingTo nodes: inout [NonTextInlineNode<View>]) {
        for case (let idx, .escapingBackslash)? in delimiters {
            nodes.append(.init(
                kind: .escapingBackslash,
                start: view.index(before: idx),
                end: idx
            ))
        }
    }
}

