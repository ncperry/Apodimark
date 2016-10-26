//
//  ProcessEscapingBackslashes.swift
//  Apodimark
//

extension MarkdownParser {

    
    /// Append the escaping backslashes contained in `delimiters` to `nodes`
    func processAllEscapingBackslashes(_ delimiters: [Delimiter?], appendingTo nodes: inout [NonTextInline]) {
        for case (let idx, .escapingBackslash)? in delimiters {
            nodes.append(.init(
                kind: .escapingBackslash,
                start: view.index(before: idx),
                end: idx
            ))
        }
    }
}

