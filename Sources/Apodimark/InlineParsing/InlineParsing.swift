//
//  InlineParsing.swift
//  Apodimark
//

extension MarkdownParser {

    typealias DelimiterSlice = ArraySlice<Delimiter?>
    
    func parseInlines(text: [Range<View.Index>]) -> LinkedList<InlineNode<View>> {

        guard !text.isEmpty else { return [] }

        let scanners = text.map { Scanner(data: view, startIndex: $0.lowerBound, endIndex: $0.upperBound) }

        var dels = delimiters(in: scanners)
        var nodes: [InlineNode<View>] = []

        nodes += processAllMonospacedText(delimiters: &dels[dels.indices])
        nodes += processAllReferences(delimiters: &dels[dels.indices])
        nodes += processAllEmphases(delimiters: &dels[dels.indices])
        nodes += processText(delimiters: &dels[dels.indices])

        nodes.sort { $0.start < $1.start }

        return makeAST(with: nodes)
    }
}
