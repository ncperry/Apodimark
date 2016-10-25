//
//  ProcessEscapingBackslashes.swift
//  Apodimark
//

extension MarkdownParser {

    func processAllEscapingBackslashes(_ delimiters: [NonTextDel?], appendingTo nodes: inout [NonTextInline]) {
        for case (let idx, .escapingBackslash)? in delimiters {
            nodes.append(.init(
                kind: .escapingBackslash,
                start: view.index(before: idx),
                end: idx
            ))
        }
    }
}

