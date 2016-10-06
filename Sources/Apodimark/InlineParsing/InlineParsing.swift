//
//  InlineParsing.swift
//  Apodimark
//

extension MarkdownParser {
        
    func parseInlines(text: [Range<View.Index>]) -> LinkedList<InlineNode<View>> {

        guard !text.isEmpty else { return [] }

        var dels = delimiters(in: text)
        
        var nodes = processAllMonospacedText(&dels[dels.indices])
        nodes += processAllReferences(&dels[dels.indices])
        nodes += processAllEmphases(&dels[dels.indices])

        nodes.sort()
        
        let textNodes = processText(dels)

        return makeAST(nonText: nodes, text: textNodes)
    }
}
